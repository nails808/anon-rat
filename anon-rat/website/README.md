# ANON marketing site (Vite · React · TypeScript)

Underground / closed-circle aesthetic product site for the ANON Android console.

## Scripts

```bash
npm install
npm run dev      # local
npm run build    # production → dist/
npm run preview  # serve dist
```

## Pages

| Route | Purpose |
|-------|---------|
| `/` | Landing, modules with generated art, download CTA |
| `/install` | Full APK install guide, Play Protect off, permission justifications |
| `/privacy` | Privacy policy |
| `/terms` | Terms of use |

## APK link

Edit `src/pages/Home.tsx` — constant `APK_URL`.

## Deploy

Upload `dist/` to any static host (Cloudflare Pages, nginx, S3).

```bash
npx wrangler pages deploy dist --project-name anon-site
```
