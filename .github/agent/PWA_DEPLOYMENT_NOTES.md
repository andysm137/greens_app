# PWA Deployment Setup - Session Notes

**Date:** September 11, 2026  
**Session Goal:** Build Flutter greens_app as a PWA and deploy to SilkstoneGreensApp GitHub Pages

---

## What Was Done Today

### 1. ✅ Analyzed Existing Deployment Flow
- **Source Repo:** `andysm137/greens_app` (Flutter app)
- **Target Repo:** `andysm137/SilkstoneGreensApp` (GitHub Pages hosting)
- **Workflow File:** `.github/workflows/static.yml` in greens_app
- **Deployment Method:** Cross-repo deployment using `PAGES_REPO_TOKEN`

### 2. ✅ Fixed .gitignore
**File:** `.gitignore`  
**Commit:** `16a33a3aa3a74b85128be50f086c8846a8266116`

**Changes Made:**
- Uncommented `/build/` on line 33 (was `# /build/` → now `/build/`)
- Added explicit `build/` pattern for web build output
- Added `web/flutter_service_worker.js` to excludes

**Why:** Build artifacts were being committed to git (3+ days old), preventing fresh builds from deploying

### 3. ✅ Created Deployment Branch
**Branch:** `setup-pwa-deploy` created in SilkstoneGreensApp  
(Not yet used - kept for reference)

---

## Identified Issues

### Issue 1: Stale Build Files ⚠️
- **Status:** FIXED (see .gitignore update above)
- **Problem:** `build/web/main.dart.js` last updated Sept 7, but Flutter code changed Sept 10-11
- **Root Cause:** `/build/` was commented out in `.gitignore`, so old builds persisted in git
- **Solution:** Uncommented `/build/` in .gitignore

### Issue 2: Deployment Failing Silently ❌
- **Status:** NEEDS INVESTIGATION
- **Problem:** Files in greens_app build/web ARE being generated, but NOT deploying to SilkstoneGreensApp
- **Latest Workflow Run:** Sept 11, 11:12 UTC - Failed with exit code 1
- **Error:** Logs show "Process completed with exit code 1" but don't show which step failed
- **Likely Cause:** `PAGES_REPO_TOKEN` permissions issue or token expired

---

## GitHub Actions Workflow Details

**File:** `.github/workflows/static.yml` in greens_app

```yaml
Trigger: Push to main branch or manual workflow_dispatch

Steps:
1. Checkout greens_app
2. Setup Flutter (stable channel)
3. Clean previous build (flutter clean, rm -rf build)
4. Install dependencies (flutter pub get)
5. Build web release (flutter build web --release --base-href "/SilkstoneGreensApp/")
6. Inspect generated release (verify build)
7. Support Flutter client-side routes (cp index.html 404.html)
8. Publish to Pages repository → FAILING HERE?
   - Uses: peaceiris/actions-gh-pages@v4
   - Token: ${{ secrets.PAGES_REPO_TOKEN }}
   - Target: andysm137/SilkstoneGreensApp (main branch)
   - Source: ./build/web
```

---

## PWA Configuration Status

✅ **Already Configured in greens_app:**
- `web/manifest.json` - PWA metadata (app name, icons, display mode)
- `web/index.html` - Links manifest and flutter_bootstrap.js
- Service worker - Flutter web includes this automatically
- Icons - Multiple sizes (192px, 512px, maskable variants)
- Display mode - Standalone (app-like experience)

---

## Next Steps for Agent

### Priority 1: Fix Deployment (CRITICAL)
1. Check `PAGES_REPO_TOKEN` in greens_app Settings → Secrets and variables → Actions
   - Should be a Classic Personal Access Token
   - Should have `repo` and `workflow` scopes
   - Token you added earlier may need verification

2. Go to greens_app → Actions → "Deploy Flutter Web" workflow
   - Find a recent failed run
   - Click on "Publish to Pages repository" step
   - Read the full error message to identify the issue

3. If token is invalid:
   - Generate new Classic PAT: Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Scopes needed: `repo`, `workflow`
   - Update `PAGES_REPO_TOKEN` secret in greens_app

### Priority 2: Trigger Fresh Build
1. Once token is verified, manually run workflow:
   - greens_app repo → Actions tab
   - Select "Deploy Flutter Web"
   - Click "Run workflow" → select main branch → Run

2. Monitor the run:
   - Watch for any error messages
   - Check if files appear in SilkstoneGreensApp

### Priority 3: Verify Deployment
1. Check SilkstoneGreensApp repo for updated files in main branch
2. Visit GitHub Pages URL: `https://andysm137.github.io/SilkstoneGreensApp/`
3. Test PWA installation features (if browser supports)

---

## Useful Commands (for local testing)

```bash
# Clean and rebuild locally
flutter clean
flutter pub get
flutter build web --release --base-href "/SilkstoneGreensApp/"

# Built files will be in: build/web/
# Main app file: build/web/main.dart.js
# Config: build/web/manifest.json
```

---

## Files Modified This Session

| File | Change | Reason |
|------|--------|--------|
| `.gitignore` | Uncommented `/build/` | Stop tracking build artifacts |
| `.github/workflows/static.yml` | No change needed | Already configured correctly |

---

## Token Setup Reference

**Token Name:** `PAGES_REPO_TOKEN`  
**Location:** greens_app → Settings → Secrets and variables → Actions  
**Type:** Classic Personal Access Token  
**Required Scopes:**
- `repo` (full control of repositories)
- `workflow` (update GitHub Actions workflows)

**Why Needed:** Allows greens_app workflow to push built files to SilkstoneGreensApp repo

---

## Testing Checklist

- [ ] `.gitignore` change is committed
- [ ] `PAGES_REPO_TOKEN` verified and has correct permissions
- [ ] Workflow manually triggered and completed successfully
- [ ] Build files appear in SilkstoneGreensApp main branch
- [ ] GitHub Pages URL shows the PWA app
- [ ] PWA can be installed (test on mobile or desktop with "Install app" option)

---

## Questions for Next Session

1. Did the `PAGES_REPO_TOKEN` have the correct scopes?
2. What was the exact error in the "Publish to Pages repository" step?
3. Are files now updating in SilkstoneGreensApp after fresh builds?
4. Can you access the PWA at the GitHub Pages URL?

---

**Notes Created by:** GitHub Copilot  
**Session:** PWA Deployment Setup  
**Next Action:** Verify PAGES_REPO_TOKEN and trigger workflow
