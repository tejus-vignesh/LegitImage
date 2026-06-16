# LegitImage backend proxy

The iOS app does not hold any vendor API keys. Instead it talks to this
small backend, which forwards image checks to SynthID (Vertex AI) and
Sightengine and returns a normalized response.

```
iPhone app  ─►  this worker  ─►  Vertex AI (SynthID)
                              └► Sightengine
```

## Why a proxy

Anything you ship in an `.ipa` can be extracted. A proxy keeps the
vendor keys on a server you control. You can also add rate limiting,
audit logs, and an app token without touching the app.

## Routes the app expects

| Method | Path           | Body (multipart)               | Returns                                     |
|--------|----------------|--------------------------------|---------------------------------------------|
| POST   | `/synthid`     | `image`, `source`              | `{ verdict, confidence?, explanation? }`    |
| POST   | `/sightengine` | `image`, `source`              | `{ verdict, confidence?, explanation? }`    |

`verdict` is one of `ai_generated`, `real`, `uncertain`.
`source` is `fileUpload` or `screenshot`.

If you set `APP_TOKEN`, the app must send `Authorization: Bearer <token>`.

## Deploy to Cloudflare Workers (recommended)

Free tier is fine for typical hobby usage (100k requests/day).

1. Install Wrangler once:
   ```bash
   npm i -g wrangler
   wrangler login
   ```

2. From this folder:
   ```bash
   wrangler deploy
   ```
   Wrangler picks up `wrangler.toml` and prints a URL like
   `https://legitimage-proxy.<your-subdomain>.workers.dev`.

3. Set the secrets:
   ```bash
   wrangler secret put APP_TOKEN          # optional, but recommended
   wrangler secret put SIGHTENGINE_USER
   wrangler secret put SIGHTENGINE_SECRET
   wrangler secret put GCP_PROJECT_ID
   wrangler secret put GCP_LOCATION       # e.g. us-central1
   wrangler secret put GCP_ACCESS_TOKEN
   ```

4. Paste the worker URL into `APIConfig.Backend.baseURL` in the iOS
   app, and the same token into `APIConfig.Backend.appToken`.

## Local dev

```bash
wrangler dev
```
Runs the worker on `http://localhost:8787`. Point the iOS app at it
(simulator can reach `http://localhost:8787` directly; a real device
needs your Mac's LAN IP).

## A note on `GCP_ACCESS_TOKEN`

Vertex AI uses short-lived OAuth tokens (typically 1 hour). For
production, mint them on a tiny scheduled job from a service account
JSON and write the latest token back into the secret with
`wrangler secret put`. For prototyping, an hour-long token from
`gcloud auth print-access-token` is enough.

## Self-hosting without Cloudflare

The worker uses only standard `fetch` / `FormData` / `Response` and
runs unchanged on:
- Deno Deploy
- Vercel Edge Functions (with minor wrapping)
- Any Node 18+ server using `@web-std/fetch` polyfills

The Vercel / Node port is left as an exercise.
