import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';

import { requireAppKey } from './middleware/auth.js';
import { createAiRouter } from './routes/ai.js';

/**
 * Builds the Express application. Dependencies are injected so the app can be
 * exercised in tests with a fake DeepSeek client and no network access.
 */
export function createApp({ config, deepseek }) {
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxy);

  app.use(helmet());

  if (config.cors.origins) {
    app.use(
      cors({
        origin: config.cors.origins,
        methods: ['POST'],
        allowedHeaders: ['Content-Type', 'x-app-key'],
      }),
    );
  }

  if (config.nodeEnv !== 'test') {
    app.use(morgan(config.isProd ? 'combined' : 'dev'));
  }

  app.use(express.json({ limit: config.bodyLimit }));

  // Liveness/readiness probe — no auth, no upstream call.
  app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));

  const limiter = rateLimit({
    windowMs: config.rateLimit.windowMs,
    max: config.rateLimit.max,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: { code: 'rate_limited', message: 'Too many requests. Please slow down.' } },
  });

  app.use(
    '/v1/ai',
    limiter,
    requireAppKey(config.appApiKeys),
    createAiRouter({ deepseek, maxInputChars: config.maxInputChars }),
  );

  app.use((_req, res) => {
    res.status(404).json({ error: { code: 'not_found', message: 'Not found.' } });
  });

  // Centralized error handler. Keep the 4-arg signature so Express treats it as
  // an error handler.
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err?.type === 'entity.too.large') {
      return res
        .status(413)
        .json({ error: { code: 'payload_too_large', message: 'Request body too large.' } });
    }
    if (err?.type === 'entity.parse.failed') {
      return res
        .status(400)
        .json({ error: { code: 'invalid_json', message: 'Request body is not valid JSON.' } });
    }
    console.error('[error]', err);
    return res
      .status(500)
      .json({ error: { code: 'internal_error', message: 'Internal server error.' } });
  });

  return app;
}
