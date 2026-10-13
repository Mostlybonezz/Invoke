# Install Invoke on your iPhone

Invoke requires **iOS 17 or later**. Its GitHub release contains a device IPA for LiveContainer or a compatible sideloading tool. It is not an App Store or TestFlight release, and tapping an IPA in Safari does not install it as a standalone iPhone app.

## Download and import the IPA

1. Open [Invoke's latest release](https://github.com/Mostlybonezz/Invoke/releases/latest) in Safari on your iPhone.
2. Download **Invoke.ipa** under Assets and save it to Files.
3. Open your configured LiveContainer, tap **+**, and select that IPA.
4. Select Invoke in LiveContainer to launch it. Start with the normal full-screen launch mode.

The [LiveContainer project](https://github.com/LiveContainer/LiveContainer) documents IPA import using its plus button. LiveContainer normally signs guest apps using the certificate configured for the host; Invoke does not require an Apple certificate to be stored in this GitHub repository. The release's local ad-hoc signature is not an Apple distribution signature.

If LiveContainer is not installed and configured yet, follow its [official installation guide](https://livecontainer.github.io/docs/installation). Complete its certificate import and JIT-less diagnostic. Invoke itself contains no JIT-dependent execution engine. Its SwiftUI and Metal effects still require a compatible iOS device and runtime.

## Add the Invoke source

The release also includes an AltStore-format source with the compiled IPA's real version, size, minimum iOS version, and download link. Add this URL in **LiveContainer → Sources → +**:

```text
https://github.com/Mostlybonezz/Invoke/releases/latest/download/source.json
```

Then expand Invoke's source and install Invoke. If your LiveContainer version has no Sources tab, use the IPA import steps above. The source is available after the first successful published release; ordinary source-code commits do not publish a new IPA.

The official [LiveContainer 3.7.0 release notes](https://github.com/LiveContainer/LiveContainer/releases/tag/3.7.0) document basic AltStore source support and the `livecontainer://sources?url=<URL>` URL scheme. The same source can be added to compatible AltStore Classic or SideStore clients. Installing Invoke through those clients creates a separately signed app and follows their account, device, and refresh requirements.

## Updates and your writing

Export an Invoke backup before replacing a build or changing LiveContainer data containers. Keep the existing app data container when updating; a new or deleted container has separate data. Do not remove LiveContainer or Invoke's container to resolve a minor display issue before exporting your writing.

In Invoke, use **Settings → Appearance** to choose a theme or turn effects off. For photo, import, export, or launch issues specific to LiveContainer, consult its [app settings guide](https://livecontainer.github.io/docs/guides/app-settings) and [FAQ](https://livecontainer.github.io/docs/faq). Its file-picker compatibility settings may be relevant to backup import and document export. Invoke's release build does not establish successful operation inside every LiveContainer version; on-device validation remains necessary.

## Release and source maintenance

GitHub Actions compiles the native iPhone target and packages `Payload/Invoke.app` as `Invoke.ipa`. Published releases provide the IPA, checksum/build metadata, and `source.json`. The source URL above follows the repository's latest published release.

`Tools/generate_feed.py` derives app metadata from the **compiled IPA**, validates the device platform and release version, and measures the download size. It does not manufacture a feed for an unbuilt app. Its format follows the official [AltStore source specification](https://faq.altstore.io/developers/make-a-source).

```sh
python3 Tools/generate_feed.py \
  --ipa build/release/Invoke.ipa \
  --repository Mostlybonezz/Invoke \
  --tag v1.0.0 \
  --output build/release/source.json
```

The app currently declares no special entitlements or usage-description permissions. If future versions add any, pass the final entitlements plist with `--entitlements` and review the generated `appPermissions` before publication. Version and bundle ID must match the compiled app. The source is compatible with AltStore Classic-style IPA distribution; it does not claim Apple notarization for AltStore PAL.
