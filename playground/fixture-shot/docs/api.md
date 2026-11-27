# API — Snip

All bodies are JSON. Errors are `{ "error": { "code": string, "message": string } }`.

| Method | Path | Body | Answer |
|---|---|---|---|
| POST | `/api/links` | `{ "url": string }` | 201 `{ "code": string, "url": string, "shortUrl": string, "visits": 0, "createdAt": string }` · 400 `invalid_url` |
| GET | `/api/links` | — | 200 `{ "links": Link[] }` — the 20 newest |
| DELETE | `/api/links/:code` | — | 204 · 404 `not_found` |
| GET | `/:code` | — | 302 to the long URL · 404 page |
| GET | `/health` | — | 200 `{ "ok": true }` |

`Link` is `{ code, url, shortUrl, visits, createdAt }`; `createdAt` is ISO 8601.
`shortUrl` uses the `BASE_URL` environment variable (default `http://127.0.0.1:3000`).
The service listens on `PORT` (default 3000).
