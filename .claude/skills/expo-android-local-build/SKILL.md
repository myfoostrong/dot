---
description: >
  Build an Expo (dev-client / bare-workflow) React Native app into an installable
  Android APK locally with Gradle — including setting up the Android SDK/NDK from
  scratch — and install it to a device/emulator/VM over adb. Use when the user
  wants a local Android build of an Expo app (no EAS cloud), an APK for an
  Android-x86/emulator VM, or `expo run:android`/`assembleRelease` help.
---

## Local Expo → Android APK build

For an Expo **dev-client** app (native modules, `newArchEnabled`, no Expo Go),
you need a real Gradle build. Two artifacts:

- **Debug** (`assembleDebug`) loads JS from a Metro dev server — needs Metro
  running and reachable. Good for iterating.
- **Release** (`assembleRelease`) **bundles the JS** → a standalone APK that
  launches on its own. Use this to install onto a VM/device for a smoke test.
  It signs with the bundled debug keystore by default (see below).

### 1. Toolchain check

Need: Node, a package manager (bun/npm/pnpm/yarn), **JDK 17**, and the Android
SDK. On asdf setups, `which java` is a shim — the real `JAVA_HOME` is
`~/.asdf/installs/java/<version>` (Gradle needs the real path, not the shim).
Docker is *not* required for a local build (that's for `eas build --local`).

### 2. Install the Android SDK/NDK if absent

`ANDROID_HOME` may point at a non-existent dir. Bootstrap with cmdline-tools:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
mkdir -p "$ANDROID_HOME/cmdline-tools"
curl -fsSLo /tmp/clt.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q /tmp/clt.zip -d "$ANDROID_HOME/cmdline-tools/tmp"
mv "$ANDROID_HOME/cmdline-tools/tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
export JAVA_HOME=$HOME/.asdf/installs/java/openjdk-17.0.2   # your real JDK17
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" \
           "ndk;27.1.12297006" "cmake;3.22.1"
```

**Get the exact versions from the project, don't guess:**

- NDK: `grep ndkVersion node_modules/**/react-native/gradle.properties`
  (RN 0.86 → `27.1.12297006`).
- compileSdk/buildTools: Expo SDK sets these (Expo 57 → SDK/build-tools **36**).
- Gradle itself comes from the project wrapper — don't install it.

Gradle's RN plugin may also auto-install extra build-tools (e.g. 35) on first
run; that's expected.

### 3. Prebuild (generate the native project)

```bash
cd apps/mobile
set -a; . ./.env; set +a          # load EXPO_PUBLIC_* — app.config.ts may throw without them
npx expo prebuild -p android --no-install
```

`--no-install` avoids clobbering a monorepo/bun workspace's `node_modules`.
Note the debug keystore appears at `android/app/debug.keystore` and the
`release` buildType is wired to sign with it — so `assembleRelease` produces an
installable (debug-signed) APK with no extra keystore setup.

### 4. Build (target only the ABI you need — much faster)

`gradle.properties` builds all ABIs (`armeabi-v7a,arm64-v8a,x86,x86_64`).
For an **Android-x86_64 VM**, build x86_64 only:

```bash
cd android
export ANDROID_HOME=$HOME/Android/Sdk JAVA_HOME=$HOME/.asdf/installs/java/openjdk-17.0.2
export PATH="$ANDROID_HOME/platform-tools:$PATH"
set -a; . ../.env; set +a
./gradlew :app:assembleRelease -PreactNativeArchitectures=x86_64 --no-daemon
```

First run downloads dependencies + compiles native modules — several minutes;
run it backgrounded and tail the log. Output:
`android/app/build/outputs/apk/release/app-release.apk`.

### 5. Install

```bash
adb connect <ip>:5555        # for a networked VM/emulator
adb install -r app-release.apk
adb shell monkey -p <applicationId> -c android.intent.category.LAUNCHER 1   # launch
```

For an Android-x86 Proxmox VM, getting adb reachable has its own pitfalls
(NIC named `wifi_eth`, inbound TCP filtered, WSL NAT return-path) — see the
`android-x86-proxmox` skill.

### Gotchas

- `app.config.ts` guards on env — a missing `EXPO_PUBLIC_*` throws at config
  eval (prebuild *and* bundling). Load `.env` for both steps. Placeholder
  origins are fine for a compile/smoke-test build.
- Match the APK ABI to the target: an x86_64 VM needs x86_64 `.so`s; an
  arm-only APK won't run (Android-x86 arm translation is unreliable).
- Use the real `JAVA_HOME` (not the asdf shim) or `sdkmanager`/Gradle fail with
  "JAVA_HOME is set to an invalid directory".
