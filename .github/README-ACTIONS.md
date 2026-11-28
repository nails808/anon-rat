# GitHub Actions — signed APK build

Workflow: `.github/workflows/build-apk.yml`

Builds an **obfuscated, release-signed** APK. Fails if signing secrets are missing.

## Required repository secrets

| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | Base64 of `anon-release.jks` |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | Usually `anon` |

## Optional

| Secret | Description |
|--------|-------------|
| `C2_URL` / `API_BASE` | Worker URL baked into the APK |
| `DEVICE_SECRET` | Must match Worker secret |

## Run

Actions → **Build APK** → Run workflow. Artifact: `anon-apk`.
