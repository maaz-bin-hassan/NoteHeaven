/**
 * Minimal DeepSeek (OpenAI-compatible) chat client.
 *
 * This module is the ONLY place the DeepSeek API key is used. It runs on the
 * server, so the secret never ships inside the mobile app.
 */

/** Categorized upstream failure so the route layer can map it to a status. */
export class UpstreamError extends Error {
  constructor(kind, message, status) {
    super(message);
    this.name = 'UpstreamError';
    // 'auth' | 'rate_limit' | 'server' | 'timeout' | 'network' | 'empty' | 'bad_response'
    this.kind = kind;
    this.status = status;
  }
}

export function createDeepSeekClient(config) {
  const { apiKey, baseUrl, model, timeoutMs } = config;

  async function chat({ userMessage, systemMessage }) {
    const messages = [];
    if (systemMessage) messages.push({ role: 'system', content: systemMessage });
    messages.push({ role: 'user', content: userMessage });

    let res;
    try {
      res = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({ model, messages, stream: false }),
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (err) {
      if (err?.name === 'TimeoutError' || err?.name === 'AbortError') {
        throw new UpstreamError('timeout', 'AI upstream request timed out.');
      }
      throw new UpstreamError('network', 'Could not reach the AI upstream.');
    }

    // A 401/403 here means OUR key is bad — a server config problem. Never let
    // it surface to the client as their own auth error.
    if (res.status === 401 || res.status === 403) {
      throw new UpstreamError('auth', 'AI upstream rejected the server credentials.', res.status);
    }
    if (res.status === 429) {
      throw new UpstreamError('rate_limit', 'AI upstream is rate limiting requests.', 429);
    }
    if (!res.ok) {
      throw new UpstreamError('server', `AI upstream error (${res.status}).`, res.status);
    }

    let data;
    try {
      data = await res.json();
    } catch {
      throw new UpstreamError('bad_response', 'AI upstream returned an unreadable response.');
    }

    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== 'string' || content.trim() === '') {
      throw new UpstreamError('empty', 'AI upstream returned an empty response.');
    }
    return content.trim();
  }

  return { chat };
}
