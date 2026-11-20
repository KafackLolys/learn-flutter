// Local-only development bridge for Novu. Do not expose this server publicly.
// Node.js >= 20.6 supports --env-file.
import { createServer } from 'node:http';

const env = process.env;
const host = '0.0.0.0'; // Listen on all interfaces for mobile device access.
const port = Number(env.PORT || 3000);
const allowedOrigin = env.FLUTTER_WEB_ORIGIN || 'http://localhost:8080';
const novuUrl = (env.NOVU_API_BASE_URL || '').replace(/\/+$/, '');
const novuEnvironment = env.NOVU_ENVIRONMENT || 'unspecified';
const novuKey = env.NOVU_SECRET_KEY || '';
const subscriberId = env.NOVU_SUBSCRIBER_ID || 'flutter-test-001';
const workflowId = env.NOVU_WORKFLOW_ID || 'com-test-flutter';
// Optional when Novu has one active FCM integration. This must be the FCM
// integration's identifier, never the public Application Identifier from API Keys.
const integrationIdentifier = env.NOVU_FCM_INTEGRATION_IDENTIFIER || '';
const triggerKey = env.TEST_TRIGGER_KEY || '';
const link = env.WEB_PUSH_LINK || '';

if (!novuUrl.startsWith('https://') || novuUrl.includes('YOUR_NOVU_API_HOST') || !novuKey || novuKey.startsWith('REPLACE_WITH_') || !triggerKey || triggerKey.startsWith('REPLACE_WITH_') || !Number.isInteger(port) || port < 1 || port > 65535) {
  console.error('Configure NOVU_API_BASE_URL (HTTPS), NOVU_SECRET_KEY, TEST_TRIGGER_KEY et PORT dans backend/.env');
  process.exit(1);
}
if (link && !link.startsWith('https://')) {
  console.error('WEB_PUSH_LINK doit être une URL HTTPS absolue.');
  process.exit(1);
}

const headers = { 'Content-Type': 'application/json', Authorization: 'ApiKey ' + novuKey };
const send = (res, status, json) => {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(json));
};
const readJson = async (req) => {
  const chunks = [];
  let bytes = 0;
  for await (const chunk of req) {
    bytes += chunk.length;
    if (bytes > 16384) throw new Error('PAYLOAD_TOO_LARGE');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
};
async function novu(path, method = 'GET', body) {
  const response = await fetch(novuUrl + path, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(12000),
  });
  const raw = await response.text();
  if (!response.ok) {
    // Do not log Novu response bodies: they can contain private account data.
    console.error('Novu API error:', response.status, method, path);
    if (response.status === 401 || response.status === 403) {
      throw new Error('NOVU_AUTH_FAILED_' + response.status +
        ': vérifier NOVU_SECRET_KEY, environnement Novu et NOVU_API_BASE_URL');
    }
    if (response.status === 400 || response.status === 422) {
      throw new Error('NOVU_VALIDATION_' + response.status + ' (' + method + ' ' +
        path.split('?')[0].replace(encodeURIComponent(subscriberId), ':subscriberId') +
        '): vérifier que NOVU_SECRET_KEY, le subscriber et l’intégration FCM appartiennent au même environnement Novu (' +
        novuEnvironment + '), que l’intégration FCM est active et que le backend a été redémarré après toute modification de .env' +
        (integrationIdentifier ? ', puis contrôler NOVU_FCM_INTEGRATION_IDENTIFIER' : ''));
    }
    throw new Error('NOVU_HTTP_' + response.status);
  }
  return raw ? JSON.parse(raw) : {};
}

const server = createServer(async (req, res) => {
  const origin = req.headers.origin;
  if (origin && origin !== allowedOrigin) return send(res, 403, { error: 'ORIGIN_NOT_ALLOWED' });
  if (origin === allowedOrigin) {
    res.setHeader('Access-Control-Allow-Origin', allowedOrigin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  }
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }
  if (req.url === '/health' && req.method === 'GET') {
    return send(res, 200, { status: 'ok', novuApiHost: new URL(novuUrl).host, configuredNovuEnvironment: novuEnvironment });
  }
  if (req.url === '/push/check-novu' && req.method === 'POST') {
    if (req.headers.authorization !== 'Bearer ' + triggerKey) {
      return send(res, 401, { error: 'UNAUTHORIZED' });
    }
    try {
      await novu('/v1/subscribers?limit=1');
      return send(res, 200, { connected: true });
    } catch (error) {
      console.error('Novu connection check:', error.message);
      return send(res, 502, { connected: false, error: error.message });
    }
  }
  if (req.method !== 'POST') return send(res, 405, { error: 'METHOD_NOT_ALLOWED' });
  try {
    const body = await readJson(req);
    if (req.url === '/push/register') {
      // No user authentication exists in the demo app: accept only one test identity
      // and never expose this service beyond loopback.
      if (body.subscriberId !== subscriberId || body.providerId !== 'fcm' ||
          typeof body.token !== 'string' || body.token.length < 20 || body.token.length > 4096) {
        return send(res, 400, { error: 'INVALID_DEVICE_REGISTRATION' });
      }
      // Creating an existing subscriber can return 400 on some Novu versions.
      // Retrieve first; create only when Novu confirms the subscriber is absent.
      try {
        await novu('/v1/subscribers/' + encodeURIComponent(subscriberId));
      } catch (error) {
        if (error.message !== 'NOVU_HTTP_404') throw error;
        try {
          await novu('/v1/subscribers', 'POST', { subscriberId });
        } catch (createError) {
          if (createError.message !== 'NOVU_HTTP_409') throw createError;
        }
      }
      await novu('/v1/subscribers/' + encodeURIComponent(subscriberId) + '/credentials', 'PUT', {
        providerId: 'fcm',
        ...(integrationIdentifier ? { integrationIdentifier } : {}),
        credentials: { deviceTokens: [body.token] },
      });
      return send(res, 200, { registered: true, subscriberId });
    }
    if (req.url === '/push/product-deleted') {
      // Local demo only: this bridge has no user authentication and is bound to loopback.
      const productName = typeof body.productName === 'string' ? body.productName.trim() : '';
      if (!productName || productName.length > 120) {
        return send(res, 400, { error: 'INVALID_PRODUCT_NAME' });
      }
      const event = {
        name: workflowId,
        to: [subscriberId],
        payload: {
          title: 'Produit supprimé',
          body: '« ' + productName + ' » a été supprimé.',
        },
      };
      const result = await novu('/v1/events/trigger', 'POST', event);
      return send(res, 200, { triggered: true, subscriberId, result });
    }
    if (req.url === '/push/trigger') {
      // Admin-only manual test: never put TEST_TRIGGER_KEY inside Flutter.
      if (req.headers.authorization !== 'Bearer ' + triggerKey) {
        return send(res, 401, { error: 'UNAUTHORIZED' });
      }
      const payload = {
        title: typeof body.title === 'string' ? body.title.slice(0, 120) : 'Test Flutter',
        body: typeof body.body === 'string' ? body.body.slice(0, 500) : 'Notification envoyée depuis Novu.',
      };
      const event = {
        name: workflowId,
        to: [subscriberId],
        payload,
        ...(link ? { overrides: { providers: { fcm: { webPush: { fcmOptions: { link } } } } } } : {}),
      };
      const result = await novu('/v1/events/trigger', 'POST', event);
      return send(res, 200, { triggered: true, result });
    }
    return send(res, 404, { error: 'NOT_FOUND' });
  } catch (error) {
    if (error.message === 'PAYLOAD_TOO_LARGE') return send(res, 413, { error: 'PAYLOAD_TOO_LARGE' });
    if (error instanceof SyntaxError) return send(res, 400, { error: 'INVALID_JSON' });
    console.error('Request failed:', error.message);
    return send(res, 502, { error: 'NOVU_REQUEST_FAILED', detail: error.message });
  }
});
server.listen(port, host, () => {
  const maskedKey = (value) => '••••••••' + value.slice(-4);
  console.log('Novu local bridge listening at http://' + host + ':' + port);
  console.log('NOVU_ENVIRONMENT:', novuEnvironment);
  console.log('NOVU_API_BASE_URL:', novuUrl);
  console.log('NOVU_SECRET_KEY: importée (masquée)', maskedKey(novuKey));
  console.log('TEST_TRIGGER_KEY: importée (masquée)', maskedKey(triggerKey));
  console.log('NOVU_SECRET_KEY et TEST_TRIGGER_KEY distinctes:', novuKey !== triggerKey);
  console.log('NOVU_FCM_INTEGRATION_IDENTIFIER:', integrationIdentifier ? 'configuré' : 'vide (sélection par défaut)');
  console.log('Only use for local testing; use real user authentication before production.');
});
