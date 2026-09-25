# iPhone builds through TestFlight, no Mac needed

GitHub's Mac machines build, sign and upload the app. Your side is a one-off
setup of about fifteen minutes, all in a browser. Never paste the API key into
a chat; it goes straight into GitHub's secrets.

## One-off setup

1. **Register the App ID.** developer.apple.com, Certificates, Identifiers and
   Profiles, Identifiers, the plus button, App IDs, App. Description `Guard`,
   Bundle ID explicit `com.stanchion.guard`. Tick Push Notifications and Time
   Sensitive Notifications. Register. The bundle id is never shown to users,
   so it doesn't wait on the product name.

2. **Create the app record.** appstoreconnect.apple.com, Apps, the plus button,
   New App. Platform iOS. Name anything unique for now (it can change until
   release). Language English (UK). Bundle ID `com.stanchion.guard`. SKU
   `guard-ios`. Full access.

3. **Make an API key.** App Store Connect, Users and Access, Integrations, App
   Store Connect API, Team Keys, the plus button. Name `GitHub`, access
   Admin (automatic signing needs it to manage certificates). Generate, then
   Download API Key: Apple only lets you download it once. Note the Key ID
   next to it and the Issuer ID at the top of the page.

4. **Find the Team ID.** developer.apple.com, Account, Membership details.

5. **Add four secrets to GitHub.** github.com/karneksystems/guard, Settings,
   Secrets and variables, Actions, New repository secret, four times:

   | Name | Value |
   |---|---|
   | `ASC_KEY_ID` | the Key ID |
   | `ASC_ISSUER_ID` | the Issuer ID |
   | `ASC_KEY_P8` | open the downloaded `.p8` in Notepad, paste all of it including the BEGIN and END lines |
   | `APPLE_TEAM_ID` | the Team ID |

6. **Add yourself as a tester.** App Store Connect, the app, TestFlight,
   Internal Testing, the plus button, a group called `Me`, add your account.
   Install the TestFlight app on the iPhone.

## Each build

Actions, `testflight`, Run workflow. About twenty minutes to build and upload,
then Apple takes ten to thirty minutes to process it before TestFlight
offers it on the phone.

## What the first build does and doesn't do

It has onboarding, every screen, the tracker, the digest, and the alerts as
Time Sensitive notifications. Settings has "Start a 2-minute test window" at
the bottom: the one-minute alert lands a minute later, the open alert a
minute after that, with the phone locked or the app closed. That is the part
worth checking first.

It runs on the sample calendar (windows on 1 and 2 October) because the
server isn't deployed yet, and it has no gate: TestFlight refuses the Screen
Time entitlement until Apple approves the distribution request filed on
23 September. When Apple says yes, run the workflow with "Include the Screen
Time gate" ticked; `app/ios/scripts/screen_time.rb` adds the three extensions
on the build machine.
