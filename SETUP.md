# One-time setup

The app and database are already done (all 84 rows from the Google Sheet are imported, pay periods included). What's left is putting this folder on GitHub and turning on Pages.

**Easiest:** open this folder (`C:\dev\overtime`) in Claude Code desktop and say:

> Follow SETUP.md steps 1–3.

## 1. Git + GitHub repo

```powershell
cd C:\dev\overtime
git init -b main
git add -A
git commit -m "Overtime app: log, months, boss view, pay periods"
```

If the GitHub CLI is installed and logged in (`gh auth status`):

```powershell
gh repo create costgal/overtime --public --source . --push
```

Otherwise create an empty **public** repo named `overtime` at https://github.com/new (no README, no .gitignore), then:

```powershell
git remote add origin https://github.com/costgal/overtime.git
git push -u origin main
```

Public is required for free GitHub Pages. That's safe here: the repo holds code only — entries, pay terms and the share token live in Supabase behind RLS.

## 2. Turn on GitHub Pages

```powershell
gh api -X POST repos/costgal/overtime/pages -f "source[branch]=main" -f "source[path]=/"
```

Or: repo → Settings → Pages → Source: *Deploy from a branch* → `main` / `/ (root)` → Save.

After ~1 minute the app is at **https://costgal.github.io/overtime/**.

## 3. Password-reset redirect (Supabase, 30 seconds)

Supabase dashboard → project **ledger** → Authentication → URL Configuration → Redirect URLs → add
`https://costgal.github.io/overtime/`
(Only needed for "Forgot password?" to land back in this app.)

## 4. iPhone

Safari → https://costgal.github.io/overtime/ → sign in with your **Ledger** email and password → Share → **Add to Home Screen**.

## 5. Coding from other devices

Once the repo is on GitHub:

- **Browser:** https://claude.ai/code → connect GitHub (first time) → pick `costgal/overtime`.
- **Phone:** Claude iOS app → Code → same repo.

Those sessions read `CLAUDE.md`, work on a branch, and you merge to `main` to deploy. The Supabase connector is account-level, so remote sessions can change the database too.

## 6. Retire the Google Form

Google Form → Responses → turn off **Accepting responses**. Keep the Sheet as a read-only archive.
