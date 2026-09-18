# CLAUDE.md

Guidance for Claude Code (desktop, web or mobile) working in this repo.

## What this is

Overtime — Kostas's personal overtime log. Replaces a Google Form + Google Sheet. Records overtime, absences and bonuses; computes monthly OT pay and the monthly pay split; and publishes a **boss view** (read-only, no login) that exists only while he switches it on.

Static site, no build step, no package.json, no dependencies. Two pages:

- `index.html` — the app (sign-in required). Vanilla JS/CSS/HTML talking to Supabase REST/Auth over `fetch`.
- `boss.html` — the public report. Calls one RPC with the anon key and renders dates + hours, printable.

Verify changes by opening the files in a browser (e.g. `python -m http.server` in the repo root, then `http://localhost:8000/`). Localhost talks to the real database — there is no separate test backend.

## Deployment

GitHub Pages from `main`, repo root → `https://costgal.github.io/overtime/`. Pushing to `main` deploys (takes ~1 min). All asset URLs must stay **relative** (`manifest.json`, not `/manifest.json`) because the site lives under `/overtime/`.

## Backend

Supabase project `dgnxbcoxdpdloplkcmzs` — the same personal project as Ledger's sandbox, so **the login is the same account as Ledger**. Free plan is at its 2-project limit, which is why this app shares it. All tables are prefixed `ot_` so they never collide with Ledger's (`entry_types`, `logs`, `reflections`, `allowed_emails`). Don't touch Ledger's tables.

Schema lives in `supabase/schema.sql` (reference copy; it was applied as the migration `overtime_app_schema`). Schema changes: apply via the Supabase MCP (`apply_migration`) and update `supabase/schema.sql` in the same commit.

- `ot_entries` — `date`, `kind` (`overtime` | `absence` | `bonus`), `minutes`, `amount` (bonus only), `note`. A check constraint enforces: bonus ⇒ amount set; otherwise minutes > 0.
- `ot_pay_periods` — `effective_from`, `bank`, `cash_base`, `ot_rate` (€/h). A period applies from its date until the next one.
- `ot_share` — one row per user: `enabled`, `token`, `title`, `date_from`, `date_to`.
- `ot_public_report(p_token)` — `security definer` RPC, the **only** thing `anon` can reach. Returns `{title, from, to, entries:[{date, minutes}]}` for `kind='overtime'` within the range, or `null` if sharing is off / token wrong.

RLS on every `ot_*` table: `user_id = auth.uid()`. The publishable key in the HTML is meant to be public.

## Privacy invariants — do not break

This repo is **public** (required for free GitHub Pages). So:

1. **No personal data in the repo.** No entries, salary figures, rates, tokens, or exports. Pay terms live only in `ot_pay_periods`. Never commit CSV exports or SQL dumps with data.
2. **The boss view never shows money.** `ot_public_report` must only ever return dates and overtime minutes — no pay, bank/cash split, bonuses, absences or notes. If you add a field to the boss view, it goes through that RPC and must pass this rule.
3. **Sharing is opt-in.** `ot_share.enabled` defaults to false; the RPC returns `null` when off. "New link" rotates the token so old links die.

## Pay maths (index.html → `monthCalc`)

- OT pay per entry = `minutes / 60 × ot_rate` of the period covering **that entry's date**.
- Bank and cash base come from the period covering the **1st of the month**.
- Cash owed for a month = `cash_base + OT pay + bonuses`. Total = `bank + cash owed`.
- Absences are tracked and shown, but don't change pay (matches the old sheet).
- Workable days = Mon–Fri minus Greek public holidays (fixed dates + Orthodox-Easter-based Clean Monday, Good Friday, Easter Monday, Holy Spirit Monday — computed, no table).

These reproduce the old Google Sheet's Dashboard exactly for Mar–Sep 2026. February differs by design (the sheet had hand-typed 11h/€66; the app computes from the 12h actually logged).

## Architecture (index.html)

Mirrors Ledger's conventions:

- `el(tag, props, ...kids)` is the only DOM helper; views are built with it directly.
- Global state `S` (`view`, `month`, `entries`, `periods`, `share`, `edit`). All data is loaded once at boot (`loadAll`) — it's a few hundred rows a year — and every calculation runs in memory. Mutate `S`, call `render()`.
- `api()` wraps `/rest/v1`, retries once on 401 after refreshing the token. Session in `localStorage` under `overtime_session`.
- Views: `renderLog` (default: add form + this month), `renderMonths` (month stats, entries, year table, quarters), `renderShare` (boss-view switch, range, link), `renderSettings` (pay periods, CSV export, sign out). Tapping any entry row opens `entryForm(entry)` for edit/delete.
- Refetches on `visibilitychange` so entries from another device appear when the PWA is reopened.

## Design invariants

Same visual language as Ledger: black background, `#D97757` the only accent, `#E5484D` only for destructive actions/errors, Futura stack, iOS-first, 44pt+ tap targets, safe-area insets on all edges. Reuse the `:root` variables. `boss.html` is intentionally light (a document for someone else, printable).

## Icons

Generated by `tools/make_icons.py` (Pillow). Edit the script and re-run rather than editing PNGs. `icon-180.png` is what iOS uses for Add to Home Screen.
