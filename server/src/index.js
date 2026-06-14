import 'dotenv/config';
import process from 'node:process';

import { loadConfig } from './config.js';
import { createDeepSeekClient } from './deepseek.js';
import { createApp } from './app.js';

const config = loadConfig();
const deepseek = createDeepSeekClient(config.deepseek);
const app = createApp({ config, deepseek });

const server = app.listen(config.port, () => {
  console.log(`[noteheaven-ai-proxy] listening on :${config.port} (${config.nodeEnv})`);
  if (config.appApiKeys.length === 0) {
    console.warn(
      '[noteheaven-ai-proxy] WARNING: APP_API_KEYS is empty — the proxy is OPEN to anyone. Set it before exposing this server.',
    );
  }
});

function shutdown(signal) {
  console.log(`[noteheaven-ai-proxy] ${signal} received, shutting down...`);
  server.close(() => process.exit(0));
  // Don't hang forever if a connection refuses to close.
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
