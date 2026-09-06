---
name: run-mobile-responsive-check
description: Audit and verify mobile responsiveness of EloShop pages (storefront or seller panel /painel). Use when asked to check, test, verify, or screenshot mobile/responsive layout, find horizontal overflow, or confirm a CSS/layout fix works on a narrow viewport.
---

Drives real page loads under a genuine narrow viewport (via Chrome DevTools Protocol) and reports horizontal overflow, with a screenshot per page. All paths below are relative to the repo root.

## Prerequisites

Chrome + chromedriver, resolved automatically by Selenium Manager the first time a system test runs (no manual install needed on this machine — confirmed already cached under `~/.cache/selenium`). Postgres running:

```bash
docker compose up -d
```

## Setup

```bash
RAILS_ENV=test bin/rails db:prepare
```

## Run (agent path)

The driver is `.claude/skills/run-mobile-responsive-check/driver_test.rb`, a Minitest system test parameterized by env vars. Point `MOBILE_PATHS` at a comma-separated list of routes to audit:

```bash
mkdir -p tmp/screenshots
MOBILE_PATHS="/,/produtos,/painel,/painel/products,/painel/orders" \
  bin/rails test .claude/skills/run-mobile-responsive-check/driver_test.rb
```

Note the seller panel routes are English (`/painel/products`, `/painel/orders`) even though the app's domain language is Portuguese — check `bin/rails routes | grep seller_` before guessing a path, see Gotchas.

For any path under `/painel`, the driver signs in as the `:seller` fixture automatically before visiting it — no extra setup needed.

Optional env vars:

| var | default | purpose |
|---|---|---|
| `MOBILE_PATHS` | `/` | comma-separated literal paths to visit |
| `MOBILE_WIDTH` | `390` | viewport width in px (390 = iPhone 12/13/14 class) |
| `MOBILE_HEIGHT` | `844` | viewport height in px |

Output: one `OK <path> (scrollWidth=N)` line per page that didn't leak past the viewport, and a screenshot for **every** page (pass or fail) at `tmp/screenshots/mobile-audit-<slug>.png`. **Always look at the screenshots** — see Gotchas below for why the pass/fail assertion alone isn't proof of a good mobile layout.

If a page leaks, the test fails with the exact overflow width and the screenshot path.

## Run (human path)

Same command as above — there's no separate manual path, since the point is a real headless-adjacent browser run, not a dev-server visual check. If you want to eyeball it live instead: `bin/dev`, then open Chrome DevTools device toolbar (Cmd+Shift+M) at 390×844 and navigate manually.

## Test

The existing dedicated regression test for the seller panel:

```bash
bin/rails test test/system/seller_portal_mobile_test.rb
```

Runs in ~3s, 2 tests, stable across repeated runs (verified 3/3).

---

## Gotchas

- **A wrong/nonexistent path silently reports "OK".** Rails' "Routing Error" page (and any generic error page) has no application CSS and, by accident, fits any viewport width — so `scrollWidth <= 390` on a 404/routing-error page reads as a pass. Confirmed directly: guessing `/painel/produtos` (Portuguese, matching the domain language used everywhere else in this app) instead of the real route `/painel/products` (English — check `bin/rails routes | grep seller_products`) returned `scrollWidth=390` and printed `OK` before this was caught. The driver now checks for "Routing Error" / "We're sorry, but something went wrong" text and fails loudly instead of reporting a false pass — but if you fork this driver, keep that check, and generally: **verify the route exists (`bin/rails routes`) before trusting a green result.**
- **scrollWidth catches page-level leaks, not clipped content.** `document.documentElement.scrollWidth > viewport width` means something pushed the *whole page* wider than the screen. It does **not** catch a table or list clipped inside an `overflow-hidden` container that never leaked past the page boundary — that's a silent "content unreachable" bug, not a "page too wide" bug. The driver can't distinguish "nothing to see here" from "content is cut off but the box itself didn't overflow." This is why every page gets a screenshot regardless of pass/fail — the screenshot is the only reliable way to catch the second kind of bug.
- **A generic "flag every `overflow-hidden` element whose scrollWidth exceeds its clientWidth" check was tried and abandoned** (see git history / earlier version of this driver). It reliably found the real bug this skill was built to catch (`seller_portal/products/index.html.erb` before it got card-list-on-mobile / table-on-desktop treatment), but it also flagged legitimate `overflow-hidden` usage constantly: `.sr-only` labels (1px-wide by design, for screen readers), carousel slides (each slide is intentionally clipped to hide the others), and decorative cards with absolutely-positioned shapes that overflow their box on purpose (`app/views/seller_portal/dashboard/index.html.erb`, the catalog/orders shortcut cards with `<span class="absolute -bottom-12 -right-8 size-44 rounded-full ...">`). An allowlist of selectors patches the first two but not the third, and keeps needing new entries as the design evolves. **If you need this kind of check for a specific page, write a dedicated test that asserts the interactive element you care about is clickable** (see `test/system/seller_portal_mobile_test.rb`'s use of `click_link`) rather than trying to generalize it.
- **Test fixtures are too sparse to reproduce table-overflow bugs.** The original bug (5-6 columns not fitting 390px) only manifested with real seed/production data. With the `:seller` fixture's ~5 products, the table narrows enough on its own that even the *broken* markup (no `sm:hidden` card list, no `overflow-x-auto` wrapper) measures `scrollWidth == 390` — confirmed by deliberately reintroducing the old bug and rerunning the driver, twice, with different attempts to force width (long product names, forced `min-width` via injected `<style>`). Neither reliably reproduced the leak with fixture-sized data; only genuinely wide content (many columns, not long text in one cell — table cells wrap text instead of stretching) does it. **Audit against seeded/production-like data when possible, not just the Minitest fixtures.**
- **A passing `click_link` does not prove mobile-friendliness.** Selenium scrolls to an element before clicking it, including one hidden inside a container an actual thumb could never reach. Confirmed while debugging this driver: a test using `click_link` still passed against the reintroduced overflow bug. Trust the screenshot, not "the test could click it."
- **`resize_to` (Capybara's `page.driver.browser.manage.window.resize_to`) does not emulate a real narrow viewport.** Chrome enforces a minimum window width (~500px on this machine) — `resize_to(390, 844)` silently clamps and `window.innerWidth` still reports ~500. Only `execute_cdp("Emulation.setDeviceMetricsOverride", ...)` produces a genuine narrow viewport; the driver uses that. Always pair it with `execute_cdp("Emulation.clearDeviceMetricsOverride")` in teardown — the override otherwise leaks into the next system test that reuses the same Chrome session.

## Troubleshooting

- **`NoMethodError: undefined method 'categories'` (or any fixture helper) inside an ad-hoc debug test**: fixture accessor methods (`categories(:one)`, `users(:seller)`, etc.) only exist because `test/test_helper.rb` sets `fixtures :all` on `ActiveSupport::TestCase`, and `ApplicationSystemTestCase` inherits that — but a standalone script created outside `test/system/` (or run outside the Rails test runner) won't have it. Look up the record directly (`Category.first`) instead, or put the test under `test/system/`.
- **`ArgumentError: 'published' is not a valid status`**: `Product#status` is an enum; the actual values are `draft`, `active`, `sold_out`, `discontinued` (check with `bin/rails runner 'puts Product.statuses.keys'` if unsure, don't guess from domain vocabulary).
