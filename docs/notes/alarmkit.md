# AlarmKit spike (M0.5)

Done 16 Oct 2026. The throwaway code lives only on branch `spike/alarmkit`
(`Meridian/Features/Alarms/AlarmSpike.swift`, shown in Alarms › Alarms); it was never
merged. Goal: prove an AlarmKit alarm rings through lock, Silent and Focus before we
build M7 on it, and settle the open questions in CLAUDE.md. Outcome: see Results and
Decisions for M7 at the end.

## What the API looks like (checked 16 Oct 2026)

Source of truth: the iOS 27.0 SDK's `AlarmKit.swiftinterface` (Xcode 27), plus Apple's
docs for the Info.plist key. Xcode's bundled AlarmKit guide (IDEIntelligenceChat
`SwiftUI-AlarmKit-Integration.md`) is stale: it says "iOS 18" and uses `stopButton`.

- `AlarmManager.shared`: `authorizationState`, `requestAuthorization()`,
  `schedule(id:configuration:)`, `cancel/stop/pause/resume/countdown(id:)`, `alarms`,
  `alarmUpdates` (async stream of the full list), `authorizationUpdates`.
  `AlarmError.maximumLimitReached` exists; the limit itself is not documented.
- Schedules: `.fixed(Date)` (an absolute instant) or
  `.relative(time: hour/minute, repeats: .never | .weekly([...]))` (wall clock).
- `AlarmPresentation.Alert(title:secondaryButton:secondaryButtonBehavior:)` is iOS 26.1+.
  The `stopButton:` initialiser is deprecated from 26.1 ("will no longer be used"); the
  system draws Stop. Our minimum is 26.0, so the spike uses `#available(iOS 26.1, *)`.
- iOS 27 adds only an optional `appEntityIdentifier:` to `AlarmConfiguration`
  (`init`, `.alarm`, `.timer`). Nothing removed.
- `AlarmAttributes` needs a metadata type (`SpikeMetadata`, empty) and a `tintColor`.
- A widget extension is required only for countdown presentations (timers).
  Without one, Apple warns, the system "may unexpectedly dismiss alarms and fail to
  alert". Plain alarms (this spike) don't need it; M5 timers will.
- `NSAlarmKitUsageDescription` is required. If missing or empty, AlarmKit
  cannot schedule alarms at all.
- Reported on the iOS 27 beta (Apple Developer Forums thread 844479, FB23754550, open
  as of 2 Sep 2026): the `.alerting` update is not delivered while the app is
  suspended, and a countdown timer alerted with no sound. The same app worked on 26.
  Unconfirmed; tests 6 and 9 below check the first claim.

## Setup (Xcode clicks)

Xcode 27 has no `INFOPLIST_KEY_*` build setting for `NSAlarmKitUsageDescription`, and
its Info tab no longer shows a "Custom iOS Target Properties" section. The key lives in
`Config/Meridian-Info.plist`, which Xcode merges with its generated Info.plist.

1. Meridian target › **Build Settings** › **All** › search `Info.plist File` › set
   the value to `Config/Meridian-Info.plist` (on the target row, so Debug and Release
   both get it).
2. Plug in the iPhone, pick it as the run destination, ⌘R.

## Tests to run on the iPhone

Before you start, write down: iPhone model, iOS version (Settings › General › About),
and whether an Apple Watch is paired. For each test: tap **Schedule alarm in 2 min**,
do the setup, wait for the time on screen. Record Pass/Fail and anything odd (delay
in seconds, sound, what the Lock Screen showed).

| # | Setup before it rings | Expect | Result | Notes |
|---|---|---|---|---|
| 1 | First tap on a fresh install | System prompt shows the usage text; Allow | Pass (16 Oct) | Prompt showed the NSAlarmKitUsageDescription text |
| 2 | App open, phone unlocked | Full alarm UI with sound and a Stop control | Pass (16 Oct) | Reported as working; no detail recorded |
| 3 | App in background, phone locked | Rings on the Lock Screen | Pass (16 Oct) | Reported as working; no detail recorded |
| 4 | Locked, **Silent** on (Ring/Silent switch or Action button) | Still rings with sound | Pass (16 Oct) | Reported as working; no detail recorded |
| 5 | Locked, **Focus** on (Do Not Disturb, then repeat with Sleep) | Still rings | Pass (16 Oct) | Reported as working; no detail recorded |
| 6 | App force-quit (swipe it away in the app switcher) | Still rings | Pass (16 Oct) | Reported as working; no detail recorded |
| 7 | Tap Stop when it rings, then open the app | Status shows "Gone (stopped or cancelled)" | Pass (16 Oct) | Reported as working; conditions not recorded. Test 9 suggests the app may have been in the foreground |
| 8 | Schedule, then tap **Cancel alarm** | Never rings | Pass (16 Oct) | Reported as working; no detail recorded |
| 9 | App suspended (home, not force-quit) when it rings; reopen after Stop | Note what status the app shows and whether it ever showed `alerting` | Fail (16 Oct) | Status showed neither "Gone" nor "alerting" after reopening: the alarmUpdates stream did not deliver the change. Matches the iOS 27 report (FB23754550) |
| 10 | Schedule, then Settings › General › Date & Time › turn off Set Automatically › Time Zone = New York | Rings at the same instant as planned: the countdown doesn't change and the "Rings at" clock time shifts | Pass (16 Oct) | Reported as working; no detail recorded |
| 11 | Low alarm volume (iOS 27: Settings › Sounds › alarm volume, if present) | Note how loud it is | Observed (16 Oct) | Rang quietly: follows the iOS 27 system alarm volume. Nothing for the app to set |
| 12 | Apple Watch paired (if you have one) | Alert also shows on the Watch | N/A | No Apple Watch |
| 13 | Settings › Apps › Meridian › turn Alarms off, then tap Schedule | Red error line in the app, nothing scheduled | Pass (16 Oct) | Reported as working; no detail recorded |

Afterwards: turn Set Automatically back on (test 10) and turn Alarms back on (test 13).

## Questions this spike must answer (copy answers here)

- Does an alarm ring through lock + Silent + Focus on our iOS version? (tests 3 to 6)
- Does `.fixed(Date)` keep its instant across a device time zone change? (test 10)
  CLAUDE.md's "Keep <zone> time" plan schedules a non-local alarm as fixed dates
  and re-registers after each fire and on launch, so this must be Yes.
- Is `alarmUpdates` reliable when the app wasn't running? (tests 6, 7 and 9) If not, M7 must
  reconcile from `AlarmManager.shared.alarms` on launch instead of trusting the stream.
- Not covered here, needed before M7: does `.relative` follow the device's zone after a
  zone change (expected: yes, that's why non-local alarms use `.fixed`), and what is
  the real `maximumLimitReached` count? A second spike button can test both.

## Results

- Device / iOS: iPhone 16, iOS 27
- Date tested: 16 Oct 2026
- Verdict: AlarmKit works for M7. Tests 1 to 8, 10 and 13 passed: rings through lock,
  Silent, Focus and app force-quit, and a `.fixed` alarm survives a device time zone
  change. Test 12 not applicable (no Watch).

## Decisions for M7

- **Don't trust `alarmUpdates` for state.** Test 9: after the alarm rang and was
  stopped while the app was suspended, the stream never told the app ("Gone" and
  `alerting` were both never shown). M7 re-reads `AlarmManager.shared.alarms` on
  launch and whenever the app comes to the foreground (`scenePhase == .active`) and
  reconciles against what we stored; the stream is only a live hint while the app is
  open. This is also when "Keep <zone> time" alarms get re-registered.
- **Volume is the user's.** iOS 27 has an independent alarm volume, and AlarmKit
  alarms follow it (test 11 rang quietly). No in-app volume control; the alarm edit
  sheet can mention it in one line if testers miss alarms.
- **Still open before M7:** whether `.relative` alarms follow a device time zone change,
  and the real `maximumLimitReached` count. A second spike button can answer both.

## M7 iPhone checks (17 Oct 2026)

Release build on the iPhone 16 (iOS 27.0.1), after the UTC pill hang fix (`71915a7`).
The owner reported everything that could be tested on the day as working:

- Local and zoned ("Keep <zone> time") alarms rang locked, on Silent, in Focus and after
  force-quit. Snooze counted down and rang again; a one-off alarm turned off after
  ringing; the DST badge opened Upcoming clock changes.
- Job reminders arrived at their lead time (5 min and at run time); Pause job stopped
  them; the notifications-off note and its link to iOS Settings worked.
- Timers, Stopwatch and Sessions (M5, M6): rang locked / Silent / force-quit, pause /
  +1 min / resume rang once at the new time, a session kept advancing after force-quit,
  every Live Activity button updated the app, the meeting line opened the Planner.

Still to check (they need a later date or a Debug build):

- **Keep UTC vs Keep zone across a DST change.** Europe changes on 25 Oct 2026: on
  26 Oct, a daily 09:00 "Keep London time" alarm should still ring at 09:00 London
  (an hour later in IST), and a "Keep UTC time" alarm at the same UTC time as before.
- **Background refresh.** After 2–3 days without opening the app, zoned alarms and job
  reminders still fire.
- **Settings › Debug · AlarmKit** (Debug build only): the real `maximumLimitReached`
  count, and whether a `.relative` alarm follows a device zone change.
