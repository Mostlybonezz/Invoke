# iOS 27 and LiveContainer verification

## Build and runtime scope

Invoke remains a native, portrait iPhone app with an iOS 17 minimum. The release workflow requires stable Xcode 27.0, both iOS 27.0 SDKs, and an exact iOS 27.0 simulator. The minimum is not an upper supported OS limit. The IPA contains an arm64 device executable, its Metal library, resources, and a local ad-hoc signature; LiveContainer applies the signing configuration of its host. Invoke adds no JIT engine, remote push dependency, guest app extension, cloud account, or special entitlement.

The intended user environment is **iOS 27 with LiveContainer 3.8.10**, as reported by the owner. The exact LiveContainer commit, signing configuration and device have not been verified here. The official [LiveContainer 3.8.0 release](https://github.com/LiveContainer/LiveContainer/releases/tag/3.8.0) introduced iOS 27 beta compatibility fixes; later 3.8.10 builds are identified by their nightly commit as well as their version. On 26 October 2026, the official [release page](https://github.com/LiveContainer/LiveContainer/releases) lists stable 3.8.0 and a 17 October nightly at `9108ae6`.

Build-specific host reports do not establish a universal incompatibility. For example, [the iPhone 18 launch issue](https://github.com/LiveContainer/LiveContainer/issues/1621) on 3.8.10 `e55609b` was resolved after a maintainer requested `4dbe0f9`; reporters confirmed guest apps and bundled SideStore worked. [The separate host startup report](https://github.com/LiveContainer/LiveContainer/issues/1630) concerned LiveContainer's selection screen, while the reporter could launch guests through shortcuts; it closed for lack of further diagnostic logs. [The bundled SideStore report](https://github.com/LiveContainer/LiveContainer/issues/1651) tracks the companion's version and pairing/refresh fixes. These are troubleshooting references, not results from testing Invoke.

Simulator and package checks cannot establish successful guest launch, file picking, notification delivery, or GPU performance inside the owner's LiveContainer 3.8.10 build. Record actual device results below; do not mark these complete from CI.

## Preserve the existing container during the upgrade

1. In Invoke, export a complete backup to Files before updating. The backup contains private writing and images; choose its destination deliberately.
2. Download the new IPA from the Invoke release and import it into the same configured LiveContainer installation. Keep the existing Invoke data container and bundle identifier, `app.invoke.personal`.
3. Launch Invoke, review the upgrade introduction, and confirm familiar stories, beliefs, scene scripts, relics, photographs, and settings are present. The app's migration checkpoint and previous storage generation are separate from the portable export.
4. Export a new backup after verifying the upgrade. If recovery is needed, use Invoke's documented recovery/import flow; reverting the executable alone does not reverse a schema migration.

LiveContainer has separate app bundles and data containers. Its [container settings](https://livecontainer.github.io/docs/guides/app-settings) can attach an existing unused container. Do not delete a container or run unused-data cleanup as an update step. See [Data Management](https://livecontainer.github.io/docs/guides/data-management) for the host's recovery and cleanup behavior.

## Local reminders and privacy

Invoke uses Apple's UserNotifications framework only after a contextual permission request. Denial or scheduling failure leaves Today and in-app reminders usable. Apple's [permission guidance](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) explains that authorization can change and should be checked before scheduling.

Reminders use a private installation namespace saved outside portable backups. Reconciliation removes only that installation's identifiers, never all notifications belonging to the host. Completion, skip, pause, archive, deferral, snooze and undo rebuild the pending plan. Snoozing changes notification timing, not the hard deadline. Private previews are the default, sound is opt-in, and quiet hours move delivery to the next allowed wall time. Equal quiet-hour start/end disables quiet hours. The existing scheduler's DST policy selects the next valid instant in a gap and the first offset in a repeated hour.

The bounded queue contains the earliest 48 reminders within 30 calendar days, plus optional daily digests within that limit. When other guests already have pending notifications in the same host, Invoke subtracts those from its 48-request budget and explains any reduced capacity. It never removes their identifiers. Reopening Invoke refreshes the horizon. iOS, Focus and host settings control actual delivery; no closed-app background worker or unlimited future scheduling is promised. Apple's [identifier-based cancellation API](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removependingnotificationrequests(withidentifiers:)) is used for obsolete pending reminders.

If notification authorization or file import/export fails only inside LiveContainer, its official [guest-app guide](https://livecontainer.github.io/docs/faq/using-guest-apps) documents **Fix Local Notifications** and **Fix File Picker** in the guest's settings. The [app settings guide](https://livecontainer.github.io/docs/guides/app-settings) also describes **Spoof SDK Version**, which makes system-library behavior match the guest's SDK. These are host settings for the owner to choose; Invoke does not modify them. LiveContainer's [documented limitations](https://github.com/LiveContainer/LiveContainer#limitations) include no remote push and no guest extensions, so Invoke does not depend on either.

## Device acceptance record

Status: **not yet performed on physical hardware from this Windows workspace**.

Record device model, exact iOS version, LiveContainer version/build, signing mode, and relevant guest settings with the following checks:

- Import and full-screen launch on iOS 27; reopen without data loss.
- Upgrade a representative 1.1 container; verify legacy counts, relationships, appearance and migration recovery copy.
- Create an Invocation and recurring practice; complete, undo and relaunch; confirm Today and Chronicle agree.
- Import/export an Invoke backup through Files; inspect a relic photograph and a long scene script.
- Permit reminders contextually, schedule a short test reminder, leave Invoke, and observe actual delivery. Deny permission and confirm the app remains usable. Verify completing/archiving removes the pending reminder.
- Test quiet hours, private previews, sound off, and separate Invoke data containers without cancellation of another guest's requests.
- Inspect native Liquid Glass, scene zoom, large text, Reduce Motion, keyboard and shader effects; measure device responsiveness rather than inferring it from screenshots.

The final release report must distinguish completed native CI checks from this on-device record.
