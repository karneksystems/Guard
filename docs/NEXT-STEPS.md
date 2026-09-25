# What only you can do next

Everything the build needs that a session without your accounts can't supply.
In the order that unblocks the most. Each one is short.

## This week

1. **Pick the name.** Curfew is clean on both stores and the domains checked on
   23 Sep; the rest of the shortlist clashed. The codename `guard` runs through
   the code and the user-facing text says nothing, so the rename is bundle ids,
   store listings and one constant. Trademark check on the chosen name before
   the bundle ids are set.

2. **Bundle ids.** Once the name is fixed, register four App IDs under it (app,
   `.monitor`, `.shieldconfig`, `.shieldaction`) with Family Controls, or reuse
   the four registered under `com.stanchion.wideberth` on 23 Sep. Set
   `PRODUCT_BUNDLE_IDENTIFIER` in `app/ios` and `app/macos`, `applicationId` in
   `app/android/app/build.gradle.kts`, and the msix `identity_name` in
   `app/pubspec.yaml`.

3. **Firebase project.** Create it, add the Android and iOS apps, drop
   `google-services.json` into `app/android/app/` and
   `GoogleService-Info.plist` into `app/ios/Runner/`, download the service
   account JSON for the backend (`FCM_SERVICE_ACCOUNT`). Then say so and the
   `FirebaseRegistrar` replaces `FakeRegistrar` in `main.dart`.

4. **APNs key.** In the Apple developer account, Keys, make an APNs key
   (.p8). Put the key, key id and team id in the backend `.env`
   (`APNS_PRIVATE_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID`). Set
   `GUARD_PUSH_SENDER=live` once both push providers are configured.

5. **TestFlight, fifteen minutes in a browser.** Follow `docs/TESTFLIGHT.md`:
   an App ID, an app record, an API key and four GitHub secrets. After that
   every iPhone build is one click in Actions. No Mac needed.

## Before the first external tester

6. **Calendar vendor.** Get the two quotes in `docs/CALENDAR-VENDORS.md`
   (Trading Economics, FXMacroData), pick one, put its key in `.env` and set
   `GUARD_CALENDAR_VENDOR`. The Trading Economics adapter is written; the
   FXMacroData one follows once their response format is known.

7. **Read the five packs' sources.** Open each `sourceUrl` in `packs/`, check
   the minutes and the event set against the page, then set `lastVerified`,
   `verifiedBy`, `sourceFetchedAt` and `needsReverify: false`. Until then the
   app shows "unverified" and uses the larger window. FTMO publishes its own
   restricted-event list; paste the URL into `eventListUrl` and the fetcher
   can be built. The import and matching are done
   (`php artisan firm-list:import ftmo rows.json`); only the page parser is
   per firm.

8. **Legal.** Read `docs/legal/PRIVACY.md` and `docs/legal/TERMS.md`, set the
   contact address, and get them hosted at URLs the store listings can point to.

## Before the stores

9. **Apple's entitlement reply.** Nothing to do but wait; distribution builds
   with Family Controls are refused until it lands. Android and Windows do not
   depend on it.

10. **Code-signing certificate for Windows.** An OV or EV cert, or Microsoft
    Store identity. Until then `msix-package` produces an unsigned artifact.

11. **Store accounts and billing.** Play Console, App Store Connect (Paid Apps
    agreement is already pending from the Karnek work), Partner Center. Create
    the one Pro SKU in each (monthly and yearly). Then the three store verifiers
    behind `backend/app/Billing/ReceiptVerifier.php` and the store SDKs behind
    `app/lib/billing/billing.dart` can be written against real products.

12. **Ad network decision** for the free tier, or no ads at launch. The privacy
    policy has a placeholder paragraph for it.

13. **The three referenced files** the brief points at and that never arrived:
    CLAUDE-HANDOFF, DESIGN-CONCEPTS-Grok.md, PROP-FIRM-RULES.md. The build went
    ahead on the brief alone; if the design comps differ from what's built, the
    screens are small and cheap to reshape.

## Devices

Android phone and tablet (a Samsung and a Pixel at least, a Xiaomi if you can
borrow one), an iPhone on iOS 16 or later, a Windows PC with MT5. The exit
criteria in `docs/MILESTONES.md` are written against real devices; CI proves
the code compiles, not that a Samsung wakes up.
