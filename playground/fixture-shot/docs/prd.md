# PRD — Snip, a tiny link shortener

## Problem

Our team pastes long URLs into chat all day. We want short links we can create in a second and
see how often each one is used.

## Users

Anyone on the team, from a browser. No accounts in the first version.

## Requirements

1. On the home page, a person pastes a long URL and gets a short link back (`/<code>`), shown
   with a copy button.
2. The short code is 6 characters, letters and digits, and never collides with an existing one.
3. A URL that is not `http://` or `https://` is refused with a clear message.
4. Visiting `/<code>` redirects (302) to the long URL and counts one visit.
5. An unknown code shows a friendly 404 page.
6. The home page lists the 20 most recent links with their visit counts, newest first.
7. A person can delete a link from that list.
8. `GET /health` answers `{ "ok": true }` for the monitoring probe.

## Non-goals

- Accounts, custom codes, link expiry, analytics beyond the visit count.

## Constraints

- Runs as one small Node service; data in a local SQLite file is fine.
- The page is server-rendered or a single static page calling the API — no front-end build
  step is required.
