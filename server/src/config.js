import process from 'node:process';

function parseList(value) {
  if (!value) return [];
  return value
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

function parsePositiveInt(value, fallback) {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

/**
 * Reads and validates configuration from the environment.
 *
 * Fails fast (throws) when a required value is missing or unsafe, so a
 * misconfigured server never starts silently.
 */
export function loadConfig(env = process.env) {
  const nodeEnv = env.NODE_ENV ?? 'development';
  const isProd = nodeEnv === 'production';

  const apiKey = (env.DEEPSEEK_API_KEY ?? '').trim();
  if (!apiKey) {
    throw new Error(
      'DEEPSEEK_API_KEY is required. Set it in the server environment — never in the mobile app.',
    );
  }

  const appApiKeys = parseList(env.APP_API_KEYS);
  if (isProd && appApiKeys.length === 0) {
    throw new Error(
      'APP_API_KEYS is required in production. Without it the proxy is an open relay that bills your DeepSeek account for anyone who finds the URL.',
    );
  }

  // CORS is irrelevant for native mobile clients (they send no Origin), so it
  // defaults to disabled. Enable it only if a web client also calls the proxy.
  const corsRaw = (env.CORS_ORIGINS ?? '').trim();
  let corsOrigins = null;
  if (corsRaw === '*') corsOrigins = '*';
  else if (corsRaw) corsOrigins = parseList(corsRaw);

  return {
    nodeEnv,
    isProd,
    port: parsePositiveInt(env.PORT, 8080),
    // Trust N proxy hops so rate limiting sees the real client IP behind a load
    // balancer (Render / Railway / Fly / Cloud Run all put one proxy in front).
    trustProxy: parsePositiveInt(env.TRUST_PROXY, 1),
    deepseek: {
      apiKey,
      baseUrl: (env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com').replace(/\/+$/, ''),
      model: (env.DEEPSEEK_MODEL ?? 'deepseek-chat').trim() || 'deepseek-chat',
      timeoutMs: parsePositiveInt(env.UPSTREAM_TIMEOUT_MS, 30000),
    },
    appApiKeys,
    cors: { origins: corsOrigins },
    rateLimit: {
      windowMs: parsePositiveInt(env.RATE_LIMIT_WINDOW_MS, 60000),
      max: parsePositiveInt(env.RATE_LIMIT_MAX, 30),
    },
    maxInputChars: parsePositiveInt(env.MAX_INPUT_CHARS, 8000),
    bodyLimit: (env.BODY_LIMIT ?? '32kb').trim() || '32kb',
  };
}
