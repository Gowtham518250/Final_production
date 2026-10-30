# Android release, OEM background-service and low-memory validation

This is a physical-device test plan, not a claim that the checks have passed. CI can compile signed release artifacts, but it cannot prove OEM background survival or performance on 2–3 GB phones.

## 1. Signed release build

The `Release Build (Android AAB + Web)` workflow runs on pushes to this review branch. The `workflow_dispatch` trigger becomes available after the workflow file is on the default branch. It builds a signed AAB and an installable signed APK. The Android Gradle release configuration enables R8 minification and resource shrinking.

Required Android Actions secrets:

- `GOOGLE_SERVICES_JSON_BASE64`: base64-encoded Firebase `google-services.json` for package `com.retailmind.app`
- `ANDROID_KEYSTORE_BASE64`: base64-encoded Play upload keystore
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The web job additionally requires `FIREBASE_WEB_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_WEB_APP_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, and `FIREBASE_SENDER_ID`.

Keep keystores, passwords, and Firebase configuration out of Git. Download `retail-mind-release-android` from a successful workflow run. Install its APK on physical test devices; use its AAB for Play Internal testing or bundletool-based distribution.

## 2. Physical-device matrix

Use real hardware, not only emulators. Record exact model, RAM, Android build, OEM skin, app version, and battery settings.

| Role | Recommended device class | Main risk covered |
|---|---|---|
| Low-memory baseline | 2 GB RAM, Android 10/11 | engine footprint, OOM, jank |
| Low-memory OEM | 3 GB RAM, Xiaomi/Redmi HyperOS or MIUI | background restrictions |
| OEM background test | 3–4 GB RAM, Oppo/Realme ColorOS or Vivo Funtouch | auto-start and battery management |
| Samsung comparison | 4 GB RAM, One UI | background service lifecycle |
| Reference | 6 GB+ Android 14+ / near-stock Android | distinguish app regressions from OEM behavior |

At least one Xiaomi, Oppo, Vivo, Realme, or Samsung phone should complete the extended screen-off soak.

## 3. Permission and background-service checks

1. Install the signed APK and launch it once.
2. Enable Retail Mind in Android **Notification access** settings. Return to the app and confirm it reports notification access as granted.
3. Verify notification-posting permission on Android 13+.
4. Record battery-optimization state. Test first with the default OS setting, then with the OEM's user-controlled **Unrestricted / Don't optimize / Auto-start allowed** setting where available. Do not assume an exemption is granted.
5. Keep the screen off for at least 8 hours while generating controlled test payment notifications/SMS at known intervals. Record each detected event, spoken announcement, duplicate, and missed event.
6. Reboot the phone, unlock it, and test detection before manually opening Retail Mind.
7. Separately test OS process death / OEM cleanup and then reopen the app. Do not treat `adb shell am force-stop` as an ordinary OS-kill test: force-stop is a stronger user action and suppresses normal package restart behavior until the app is launched again.

The app manifest declares the background service, `RECEIVE_BOOT_COMPLETED`, and `WAKE_LOCK`. The reboot test must still confirm that the merged plugin receiver and Dart background-service configuration actually restart monitoring; manifest declarations alone do not prove this. The manifest does not currently declare `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, so record the actual Android/OEM battery state rather than assuming an exemption exists.

Useful PowerShell commands (one authorized USB debugging device connected):

```powershell
$pkg = "com.retailmind.app"

# Device, Android build and memory class
adb shell getprop ro.product.manufacturer
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell getprop ro.config.low_ram

# Notification access, notification posting, battery allowlist
adb shell settings get secure enabled_notification_listeners
adb shell cmd appops get $pkg POST_NOTIFICATION
adb shell dumpsys deviceidle whitelist | findstr /i $pkg

# Service and process state
adb shell dumpsys activity services $pkg
adb shell ps -A | findstr /i $pkg

# Point-in-time memory
adb shell dumpsys meminfo $pkg

# Reset frame counters before a UI scenario, then capture after it
adb shell dumpsys gfxinfo $pkg reset
# ...perform the scenario on the phone...
adb shell dumpsys gfxinfo $pkg framestats
```

## 4. Eight-hour soak and memory captures

Run `scripts/android_low_memory_soak.ps1` from PowerShell with the USB-connected phone. It saves timestamped `dumpsys meminfo`, service state, process list, and a CSV summary.

Capture separate runs for:

- Background detection service idle, screen off
- Dashboard open with a seeded test dataset of several thousand sales
- Inventory open while scrolling through image-heavy products
- Voice-billing session with repeated short and multi-item commands
- 20 repeated transitions between Dashboard, Inventory, Sales, and Voice Billing

At each stage record total PSS, per-process PSS where shown, process count, service foreground state, frame statistics, crashes/ANRs, missed announcements, and duplicate announcements. Compare the same device before and after each workload; one snapshot is not enough to establish a memory pass.

## 5. Pass/fail record

For each device, attach:

- Release artifact name and SHA-256
- Device model / RAM / Android build / OEM skin
- Notification access and POST_NOTIFICATIONS status
- Battery optimization and OEM auto-start mode
- Background service state at start, 1 hour, 4 hours, and 8 hours
- Reboot recovery and process-kill recovery result
- Idle-service PSS and UI-open PSS
- Dashboard, inventory-image, and voice-billing frame stats
- Crash/ANR count, missed payment alerts, and duplicate announcements

A device passes only when permissions are actually enabled, the service remains/restarts as expected, no controlled test payment is missed or announced twice, and the phone completes the workloads without an app crash or ANR. Keep raw dumps for release-to-release comparison.
