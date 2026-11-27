# Auth routes + 404 debugging

Routes on the **same** Worker as C2:

- `POST /api/register`
- `POST /api/login`
- `GET  /api/me`
- `POST /api/logout`

## 404 checklist

1. **Deployed latest code?**  
   `cd worker && npx wrangler deploy`

2. **Migration applied?**  
   `npx wrangler d1 migrations apply anon-c2 --remote`  
   Must include `0002_auth.sql` (users + sessions tables).

3. **Correct host?**  
   Test the Worker URL itself, not the old bittermusic host:

   ```bash
   curl -i -X POST "https://YOUR_SUBDOMAIN.workers.dev/api/login" \
     -H "Content-Type: application/json" \
     -d '{"email":"a@b.com","password":"password1"}'
   ```

   - `401 invalid email or password` → route works (user missing or wrong password)  
   - `404` → wrong URL or old deploy without auth routes  
   - HTML panel page → you hit `/` not `/api/login`

4. **APK dart-defines** must match that Worker:

   ```bash
   --dart-define=C2_URL=https://YOUR_SUBDOMAIN.workers.dev \
   --dart-define=API_BASE=https://YOUR_SUBDOMAIN.workers.dev
   ```

5. **wrangler.toml `database_id`** must be a real UUID from `wrangler d1 list`, not `REPLACE_AFTER_D1_CREATE`.
