# GitHub Actions — compile APK

Workflow: `.github/workflows/build-apk.yml`

## Repo secrets (Settings → Secrets and variables → Actions)

| Secret | Purpose |
|--------|---------|
| `C2_URL` | e.g. `https://anon-c2.your.workers.dev` |
| `DEVICE_SECRET` | Same value as Worker secret `DEVICE_SECRET` |

## Run

1. Push this repo to GitHub.  
2. Add the two secrets.  
3. **Actions → Build APK → Run workflow** (or push to `main`).  
4. Download artifact **anon-app-release-apk**.

## Tag release

```bash
git tag v3.0.0
git push origin v3.0.0
```

Tagged builds also attach the APK to the GitHub Release.
