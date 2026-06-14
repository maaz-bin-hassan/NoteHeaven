import express from 'express';

import { UpstreamError } from '../deepseek.js';

const UPSTREAM_STATUS = {
  auth: 502,
  server: 502,
  bad_response: 502,
  empty: 502,
  network: 504,
  timeout: 504,
  rate_limit: 429,
};

function clientMessage(kind) {
  switch (kind) {
    case 'rate_limit':
      return 'The AI service is busy. Please try again shortly.';
    case 'timeout':
    case 'network':
      return 'The AI service is temporarily unreachable. Please try again.';
    default:
      return 'The AI service is currently unavailable.';
  }
}

/**
 * POST /v1/ai/chat
 *   Request : { userMessage: string, systemMessage?: string }
 *   Response: { content: string }
 *
 * Mirrors the contract the Flutter app already used when it called DeepSeek
 * directly, so only the transport layer changes on the client.
 */
export function createAiRouter({ deepseek, maxInputChars }) {
  const router = express.Router();

  router.post('/chat', async (req, res, next) => {
    const body = req.body ?? {};
    const { userMessage, systemMessage } = body;

    if (typeof userMessage !== 'string' || userMessage.trim() === '') {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: '`userMessage` is required and must be a non-empty string.',
        },
      });
    }
    if (systemMessage !== undefined && typeof systemMessage !== 'string') {
      return res.status(400).json({
        error: {
          code: 'invalid_request',
          message: '`systemMessage` must be a string when provided.',
        },
      });
    }

    const totalLen = userMessage.length + (systemMessage?.length ?? 0);
    if (totalLen > maxInputChars) {
      return res.status(413).json({
        error: {
          code: 'payload_too_large',
          message: `Input exceeds the ${maxInputChars}-character limit.`,
        },
      });
    }

    try {
      const content = await deepseek.chat({
        userMessage,
        systemMessage: systemMessage?.trim() ? systemMessage : undefined,
      });
      return res.json({ content });
    } catch (err) {
      if (err instanceof UpstreamError) {
        // Log the real cause server-side; return a safe, generic message.
        console.warn(`[ai] upstream ${err.kind}: ${err.message}`);
        const status = UPSTREAM_STATUS[err.kind] ?? 502;
        return res
          .status(status)
          .json({ error: { code: `upstream_${err.kind}`, message: clientMessage(err.kind) } });
      }
      return next(err);
    }
  });

  return router;
}
