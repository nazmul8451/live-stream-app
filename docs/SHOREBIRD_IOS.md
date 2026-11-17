# AREIS iOS updates with Shorebird

This project uses the existing **Culture Cards** Shorebird app, ID `c1a409df-a90e-44eb-a146-6662820a25fd`. The ID matches the project's previous Shorebird configuration in commit `7cfb505` and was verified against the signed-in account. `shorebird.yaml` is bundled as an asset and enables automatic background updates.

## First TestFlight release

Build on macOS with Xcode, the project's Apple signing certificates/provisioning profiles, and access to the Culture Cards Shorebird app. A macOS Codemagic runner can perform this build too. Use the project's production `.env` asset and tracked lock files.

Install the Shorebird CLI following the [installation guide](https://docs.shorebird.dev/getting-started/), then run from the project root.

```sh
shorebird login
shorebird doctor
shorebird release ios --flutter-version=3.44.9 --build-name=1.0.3 --build-number=12 --export-method=app-store
```

Flutter `3.44.9` matches this app's existing Shorebird Android releases and the installed Shorebird SDK checked during setup. The release command pins that baseline explicitly. Subsequent patches automatically use the baseline's Flutter revision.

For manual signing, pass the existing signing export options to the release command with `--export-options-plist=PATH_TO_EXPORT_OPTIONS`. Use the Apple team and profiles belonging to bundle ID `com.culturecards.app`.

Upload the generated `build/ios/ipa/*.ipa` to App Store Connect using Transporter or the existing CI publishing step. TestFlight users need to install this Shorebird-built release before they can receive patches. A build made with `flutter build ipa` uses the standard Flutter engine, so the build step for this release must run `shorebird release ios`.

For an existing Codemagic workflow, run the release command above in its macOS build step. Provide a Shorebird API key through the secret `SHOREBIRD_TOKEN` environment variable instead of interactive `shorebird login`. Continue using that workflow's Apple signing and App Store Connect publishing configuration. Commit `shorebird.yaml` and its `pubspec.yaml` asset entry so the runner includes them.

If App Store Connect already contains build `12`, increase `pubspec.yaml`'s build number and use that same number in the release command. Record the actual published release version for future patches.

## Publish a small Dart update

On the macOS build machine, use the exact release version installed by the intended users. For the baseline above, run the following after making and testing the Dart changes.

```sh
shorebird patch ios --release-version=1.0.3+12 --track=staging
shorebird preview --platforms=ios --release-version=1.0.3+12 --track=staging
```

Preview the staging patch on a physical iPhone or iPad and verify the changed workflow. When ready, promote its patch number.

```sh
shorebird patches list --release-version=1.0.3+12 --platform=ios
shorebird patches promote --release-version=1.0.3+12 --platform=ios --patch-number=PATCH_NUMBER
```

The app checks for patches in the background on launch. After the download finishes, a subsequent app restart loads the patch. Keep the release's target, flavor and Dart define flags consistent when patching. Retain the release's native files, lock files and bundled assets when preparing a Dart-only patch.

Shorebird patches support Dart changes such as UI and business logic fixes. Native Swift/Objective-C/Kotlin changes, native plugin changes, entitlements, permissions and bundled asset changes need a new store release. This project bundles `.env`, so changing its contents also changes a bundled asset and requires a new release. Use the same `.env` contents when patching an existing release.

## Setup verification

The Windows development machine can verify account access and project configuration. iOS release builds and patches require macOS with Xcode. At setup time, the existing app had Android releases through `1.0.0+9` and no registered iOS baseline. The first iOS release and physical-device patch verification are still required.

The project's built-in Shorebird updater handles automatic updates through `shorebird.yaml`. A separate Dart updater package is needed only if custom update controls are added later.

References — [release builds](https://docs.shorebird.dev/code-push/release/), [patches](https://docs.shorebird.dev/code-push/patch/), [Codemagic](https://docs.shorebird.dev/code-push/ci/codemagic/).
