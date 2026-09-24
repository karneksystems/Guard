# Backend deployment

One small host, or a slot beside Karnek's existing Laravel apps. PHP 8.4,
Postgres, Redis. Nothing exotic.

## Environment

Besides the usual Laravel keys (`APP_KEY`, `APP_URL`, `DB_*`, `REDIS_*`):

| Variable | What |
|---|---|
| `QUEUE_CONNECTION=redis` | Horizon needs Redis; the database driver is for tests only |
| `GUARD_CALENDAR_VENDOR` | `tradingeconomics` or `fake` (never `fake` in production) |
| `TRADINGECONOMICS_API_KEY` | from the vendor |
| `GUARD_PUSH_SENDER=live` | `log` writes pushes to the log instead of sending |
| `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, `APNS_BUNDLE_ID` | the .p8 contents or a path; `APNS_SANDBOX=true` for TestFlight builds |
| `FCM_SERVICE_ACCOUNT` | path to the Firebase service-account JSON |
| `GUARD_RECEIPT_VERIFIER` | `reject` until the store verifiers exist; never `fake` in production |
| `GUARD_PACKS_DIR` | where the packs live on the host; `packs:publish` copies them from the repo |

## Processes

- `php artisan horizon` under a supervisor (systemd or Supervisor). Two
  supervisors are configured in `config/horizon.php`: `ladder`, which only
  works the `ladder` queue and polls every second because T-1 and open must
  leave within two seconds of `fire_at`, and `default` for everything else.
- The scheduler: `* * * * * php artisan schedule:run` in cron. It runs
  `calendar:sync` every fifteen minutes and the two-hour tight sweep every
  minute, and `ladder:reconcile` at 00:30 UTC.
- `php artisan octane:start` or plain PHP-FPM behind nginx. The API is small
  and read-heavy; FPM is fine to start.

## First deploy

```
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan packs:publish
php artisan calendar:sync
php artisan horizon:terminate   # on every deploy, so workers pick up new code
```

## Health

`GET /` returns JSON with the app name and the time; put the uptime check
there. Horizon's dashboard at `/horizon` is gated by `HorizonServiceProvider`;
restrict it to your account before the host is public. Watch two numbers: the
`ladder` queue's wait time (must stay under a second) and the number of rungs
in state `failed` (should be zero; a non-zero count means a provider rejected
tokens, which `DeviceRouter` prunes).

## Rollback

Migrations are additive so far. Roll back the code and `horizon:terminate`.
