import crypto from 'node:crypto';

function sha256(value) {
  return crypto.createHash('sha256').update(value, 'utf8').digest();
}

/**
 * Express middleware requiring a valid `x-app-key` header.
 *
 * The app key is a low-sensitivity shared secret embedded in the mobile client.
 * It is NOT real user authentication — anything shipped in an app can be
 * extracted — but it stops the proxy from being an open relay for your DeepSeek
 * account. Rotate it server-side by changing APP_API_KEYS.
 *
 * When no keys are configured the guard allows all traffic (development only;
 * config.js refuses to start in production without keys).
 */
export function requireAppKey(appApiKeys) {
  const validHashes = appApiKeys.map(sha256);

  return function appKeyGuard(req, res, next) {
    if (validHashes.length === 0) return next();

    const provided = req.get('x-app-key') ?? '';
    if (provided) {
      // Hash both sides to fixed length, then compare in constant time.
      const providedHash = sha256(provided);
      for (const valid of validHashes) {
        if (crypto.timingSafeEqual(providedHash, valid)) return next();
      }
    }

    return res
      .status(401)
      .json({ error: { code: 'unauthorized', message: 'Missing or invalid app key.' } });
  };
}
