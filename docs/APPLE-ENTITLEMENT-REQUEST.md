# Family Controls entitlement request

Status, 23 Sep 2026: four App IDs exist with Family Controls (Development) ticked,
com.stanchion.wideberth plus .monitor, .shieldconfig and .shieldaction. The
distribution entitlement has not been requested yet.

What Apple's portal does now, as seen on the day: the per-app "Family Controls
(Distribution)" request links to a single page with one "Get Entitlement" button.
Pressing it accepts Apple's Family Controls terms for the whole team, Stanchion
Systems Ltd. There is no form and nowhere to paste a description. The terms in
summary: the app's primary purpose must be parental supervision or letting
individuals manage their own device use (ours is the second); it may not be used to
manage another adult's device; usage data may not be shared, used for advertising,
or passed to data brokers. Because acceptance is team-level, renaming the app and
its bundle IDs later does not require doing this again.

The account holder presses the button. Development builds work without it; App
Store distribution doesn't.

The text below was written for the old per-app form. Keep it: it's the honest
description of the use, and it's what to send if Apple ever asks for one during
review.

## Text for the form (kept for App Review)

App name: Wideberth (working title)

Bundle ID: com.stanchion.wideberth
Extensions: com.stanchion.wideberth.monitor (DeviceActivityMonitor),
com.stanchion.wideberth.shieldconfig (ShieldConfiguration),
com.stanchion.wideberth.shieldaction (ShieldAction)

Authorization type: individual. The user manages their own device. No family or child
accounts, no parental features.

Why the app needs Family Controls:

Wideberth is a self-control tool for adults who trade through proprietary trading
firms. Those firms forbid trading in the minutes around scheduled economic releases,
and a single trade inside that window ends the trader's account. The app lets the
user choose their own trading apps in FamilyActivityPicker and shields those apps on
their own device during the restricted windows they've configured. When the window
ends the shield lifts automatically. The user can lift it themselves at any time from
the shield card.

This is a digital wellbeing use in the sense Apple describes for individual
authorization: the user sets limits on their own use of specific apps at specific
times, to protect themselves from an impulsive action with a real financial cost. It
is the same pattern as focus and app-limit tools, with a schedule driven by an
economic calendar instead of a fixed timetable.

What the app does not do:

- It never learns which apps the user selected. Tokens stay opaque and never leave the
  device.
- It never reads, modifies or interacts with any other app's data.
- It has no trading functionality and never connects to any trading account.
- It does not use Family Controls for any monitoring, reporting or third-party
  purpose. DeviceActivity is used only to apply and remove shields on the user's own
  schedule.

How each extension is used:

- DeviceActivityMonitor: applies the shield at the start of a scheduled window and
  removes it at the end, so protection works even when the app isn't running.
- ShieldConfiguration: draws the shield card with the name of the event, the time the
  window ends, and two buttons, "Stay out" and "View for 60 seconds".
- ShieldAction: handles the two buttons. "Stay out" closes the shield. "View for 60
  seconds" lifts it briefly and re-applies it.

Privacy: the app collects no personal data through these APIs. Nothing derived from
Family Controls, ManagedSettings or DeviceActivity is transmitted anywhere.
