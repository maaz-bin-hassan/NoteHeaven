# NoteHeaven AI proxy

A small, production-ready backend that holds the **DeepSeek API key** so the
NoteHeaven mobile app never has to. The Flutter app calls this proxy; the proxy
authenticates the request and forwards it to DeepSeek using the secret that
lives only on the server.

```
Flutter app  ──(x-app-key)──▶  this proxy  ──(Bearer DEEPSEEK_API_KEY)──▶  DeepSeek
```

## Why

Bundling the DeepSeek key in the app means anyone can extract it from the
APK/IPA and spend your credits. Moving it behind a proxy you control means:

- the secret is never shipped to devices,
- you can rate-limit, cap input size, and revoke client access,
- you can rotate the key without releasing a new app build.

## Endpoints

| Method | Path           | Auth          | Purpose                          |
| ------ | -------------- | ------------- | -------------------------------- |
| `GET`  | `/healthz`     | none          | Liveness/readiness probe         |
| `POST` | `/v1/ai/chat`  | `x-app-key`   | Proxy a chat completion          |

### `POST /v1/ai/chat`

Request:

```json
{ "userMessage": "Summarize this note...", "systemMessage": "You are a concise assistant." }
```

`systemMessage` is optional. Response:

```json
{ "content": "..." }
```

Errors are returned as `{ "error": { "code": "...", "message": "..." } }` with an
appropriate HTTP status (`400` invalid input, `401` bad app key, `413` too large,
`429` rate limited, `502/504` upstream problems).

## Configuration

All configuration comes from environment variables — see [`.env.example`](.env.example).
Required: `DEEPSEEK_API_KEY`, and `APP_API_KEYS` (required in production).

## Run locally

```bash
cd server
cp .env.example .env          # then fill in DEEPSEEK_API_KEY and APP_API_KEYS
npm install
npm run dev                   # http://localhost:8080
```

Smoke test:

```bash
curl -s localhost:8080/healthz
curl -s localhost:8080/v1/ai/chat \
  -H 'content-type: application/json' \
  -H 'x-app-key: <one of APP_API_KEYS>' \
  -d '{"userMessage":"Say hello in one word."}'
```

Run the tests (no network needed — the upstream is faked):

```bash
npm test
```

## Deploy

The service is a stateless HTTP server on `PORT` (default `8080`) — it runs on
any container or Node host. Set the env vars from `.env.example` in your host's
dashboard; **do not** commit `.env`.

**Docker** (works on Fly.io, Cloud Run, Render, Railway, a VPS, …):

```bash
docker build -t noteheaven-ai-proxy ./server
docker run -p 8080:8080 --env-file ./server/.env noteheaven-ai-proxy
```

**Render / Railway:** point the service at the `server/` directory, build with
`npm install`, start with `npm start`, and add the env vars in the dashboard.

The app trusts one proxy hop by default (`TRUST_PROXY=1`) so rate limiting sees
the real client IP behind the platform load balancer.

## Connect the Flutter app

In the app's root `.env` set:

```
AI_PROXY_URL=https://your-proxy.example.com   # http://10.0.2.2:8080 for the Android emulator
AI_APP_KEY=<one of APP_API_KEYS>
```

The app sends `AI_APP_KEY` as the `x-app-key` header. See the repo root README
for the emulator/simulator host addresses.

## Security notes

- The DeepSeek key lives only here. Never put it in the app.
- `x-app-key` is a **shipped** client secret — it stops casual abuse but can be
  extracted from the app. For stronger protection add real per-user auth and/or
  device attestation (Play Integrity / App Attest) and verify it here.
- Rotate client access by editing `APP_API_KEYS` (comma-separated allows
  staged rotation) and redeploying.
- Tune `RATE_LIMIT_MAX`, `MAX_INPUT_CHARS`, and `BODY_LIMIT` to your traffic.
