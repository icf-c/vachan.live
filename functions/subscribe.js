/**
 * The coming-soon form: one email address into a KV namespace.
 *
 * A Pages Function, so it runs on the site's own origin and needs no CORS.
 * Bindings come from infra/pages.tf:
 *   SUBSCRIBERS        KV namespace, key = the lower-cased address
 *   TURNSTILE_SECRET   secret half of the Turnstile widget
 *
 * What is stored: the address, the time, and the Accept-Language header so
 * the shipping mail can be in the right language. No IP, no user agent.
 */

const TEST_SECRET = '1x0000000000000000000000000000000AA'; // Cloudflare's always-passes key, for `just serve`

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

function looksLikeEmail(value) {
  return typeof value === 'string' && value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);
}

async function verifyTurnstile(token, ip, secret) {
  if (!token) return false;
  const body = new URLSearchParams({ secret, response: token });
  if (ip) body.set('remoteip', ip);
  const r = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const out = await r.json().catch(() => ({}));
  return out.success === true;
}

async function readBody(request) {
  const type = request.headers.get('Content-Type') || '';
  if (type.includes('application/json')) return request.json();
  const form = await request.formData();
  return Object.fromEntries(form.entries());
}

export async function onRequestPost({ request, env }) {
  let data;
  try {
    data = await readBody(request);
  } catch {
    return json({ ok: false, error: 'Could not read the form.' }, 400);
  }

  // The honeypot: a real browser leaves it empty; a bot fills every field.
  if (data.website) return json({ ok: true });

  const email = String(data.email || '').trim().toLowerCase();
  if (!looksLikeEmail(email)) return json({ ok: false, error: 'That does not look like an email address.' }, 400);

  const secret = env.TURNSTILE_SECRET || TEST_SECRET;
  const ip = request.headers.get('CF-Connecting-IP');
  if (!(await verifyTurnstile(data['cf-turnstile-response'], ip, secret))) {
    return json({ ok: false, error: 'The security check did not pass. Try once more.' }, 403);
  }

  const key = `email:${email}`;
  const already = (await env.SUBSCRIBERS.get(key)) !== null;
  if (!already) {
    await env.SUBSCRIBERS.put(
      key,
      JSON.stringify({ email, at: new Date().toISOString(), lang: (request.headers.get('Accept-Language') || '').split(',')[0].slice(0, 16) }),
    );
  }
  return json({ ok: true, already });
}

export function onRequestGet() {
  return new Response('Method Not Allowed', { status: 405 });
}
