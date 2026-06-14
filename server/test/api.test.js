import test from 'node:test';
import assert from 'node:assert/strict';

import { createApp } from '../src/app.js';

function makeConfig(overrides = {}) {
  return {
    nodeEnv: 'test',
    isProd: false,
    port: 0,
    trustProxy: 1,
    appApiKeys: ['test-key'],
    cors: { origins: null },
    rateLimit: { windowMs: 60_000, max: 1000 },
    maxInputChars: 8000,
    bodyLimit: '32kb',
    deepseek: {},
    ...overrides,
  };
}

const fakeDeepseek = {
  async chat({ userMessage }) {
    return `echo: ${userMessage}`;
  },
};

async function withServer(config, deepseek, fn) {
  const app = createApp({ config, deepseek });
  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const { port } = server.address();
  try {
    await fn(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('GET /healthz returns ok without auth', async () => {
  await withServer(makeConfig(), fakeDeepseek, async (base) => {
    const res = await fetch(`${base}/healthz`);
    assert.equal(res.status, 200);
    assert.equal((await res.json()).status, 'ok');
  });
});

test('POST /v1/ai/chat requires a valid app key', async () => {
  await withServer(makeConfig(), fakeDeepseek, async (base) => {
    const res = await fetch(`${base}/v1/ai/chat`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ userMessage: 'hi' }),
    });
    assert.equal(res.status, 401);
  });
});

test('POST /v1/ai/chat rejects an empty userMessage', async () => {
  await withServer(makeConfig(), fakeDeepseek, async (base) => {
    const res = await fetch(`${base}/v1/ai/chat`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-app-key': 'test-key' },
      body: JSON.stringify({ userMessage: '   ' }),
    });
    assert.equal(res.status, 400);
  });
});

test('POST /v1/ai/chat returns content on success', async () => {
  await withServer(makeConfig(), fakeDeepseek, async (base) => {
    const res = await fetch(`${base}/v1/ai/chat`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-app-key': 'test-key' },
      body: JSON.stringify({ userMessage: 'hello', systemMessage: 'be brief' }),
    });
    assert.equal(res.status, 200);
    assert.equal((await res.json()).content, 'echo: hello');
  });
});

test('unknown route returns 404', async () => {
  await withServer(makeConfig(), fakeDeepseek, async (base) => {
    const res = await fetch(`${base}/nope`);
    assert.equal(res.status, 404);
  });
});

test('rejects input over the character limit', async () => {
  await withServer(makeConfig({ maxInputChars: 10 }), fakeDeepseek, async (base) => {
    const res = await fetch(`${base}/v1/ai/chat`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-app-key': 'test-key' },
      body: JSON.stringify({ userMessage: 'this is definitely longer than ten chars' }),
    });
    assert.equal(res.status, 413);
  });
});
