# Developing WakeBee Free

This independent fork keeps WakeBee's SwiftUI interface, session policies, battery controls, closed-lid lease manager, durable recovery journal, and watchdog. Activation code and the Polar client are removed. Sparkle and the official app's update feed are removed; updates are manual.

## Build and checks

Use a Mac with Xcode 26.1 SDK or newer, Swift 6, and Python 3:

```sh
./script/build_and_run.sh --build-only
swift test --disable-sandbox
python3 -m unittest discover -s script -p 'test_*.py'
bash -n script/build_and_run.sh script/code_requirement.sh script/manage-helper.sh
```

The bundle targets macOS 14+. `WAKEBEE_UNIVERSAL=1` builds arm64 and x86_64; `WAKEBEE_BUILD_CONFIGURATION=release` chooses release optimization. `WAKEBEE_DESTINATION` overrides the output bundle. `WAKEBEE_SIGN_IDENTITY` is optional; the default `-` signs ad-hoc. The app and helper enable hardened runtime and kill-on-invalid-signature, with no debugging entitlements. Builds are not notarized.

The macOS Actions workflow runs the Swift and Python suites, checks real universal ad-hoc signatures, and packages a universal app. The tests do not change the host's sleep policy. Linux can run only the Python checks; the signature test requires macOS.

## Privilege and authentication boundaries

The identifiers are independent of the original app:

- App: `io.github.dennisimoo.WakeBeeFree`
- Mach service and LaunchDaemon: `io.github.dennisimoo.WakeBeeFree.helper`
- Installed helper/config: `/Library/PrivilegedHelperTools/io.github.dennisimoo.WakeBeeFree/`
- LaunchDaemon: `/Library/LaunchDaemons/io.github.dennisimoo.WakeBeeFree.helper.plist`
- Recovery journal: `/private/var/db/io.github.dennisimoo.WakeBeeFree.helper/recovery.json`

`code_requirement.sh` extracts the CodeDirectory hash of every architecture. The bundle script signs the helper first and seals its hash requirement inside the app. XPC clients reject helper code that does not satisfy that requirement.

Setup invokes `manage-helper.sh` through macOS's administrator-authorization dialog. Paths are shell-quoted, and the complete command is an AppleScript argument rather than interpolated AppleScript source. The app first stages a root-owned copy, rejects symlinks, and verifies it against the executing app’s exact hash before running its installer script. The installer verifies that copy again, computes the app's exact hash requirement, installs a root-owned helper and configuration, and bootstraps launchd. No persistent sudo grant is installed.

The helper accepts only the configured non-root UID and exact approved app hashes using `NSXPCConnection.setCodeSigningRequirement`. There is no identifier-only or unsigned-client fallback. Root-owned configuration pins the approved build; rebuilding or updating the app needs renewed approval. The service exposes only existing bounded health, renew, and release operations, never arbitrary commands.

Unlike certificate-based signing, hash pinning does not identify a publisher across versions. Administrator approval is the trust decision for each installation/update. A valid ad-hoc signature is an integrity check, not Apple review or notarization.

## Recovery and removal

The unchanged `ClosedLidLease` owns policies and restoration. Before setting `pmset disablesleep`, it durably records the prior value. Leases expire after 30 seconds; the watchdog checks once per second and retries failed restoration. A disconnect releases its client's lease. Battery/thermal/power limits and the four-hour continuous limit still apply.

The installer stops an old service, then invokes the **root-owned installed helper** with `--recover-only`. On restoration failure it restarts the old watchdog and leaves the journal and installed files intact. Only successful recovery permits replacement/removal. The journal is never deleted by the installer. Other official WakeBee/AwakeMac helpers and journals block setup/renewal to avoid competing recovery owners.

Do not remove authentication, the journal, lease expiration, or power limits to make setup pass. Do not test against a user's active session. Hardware acceptance still requires: timer completion, battery cutoff, unplugging, app quit/force-quit, helper restart, removal, and checking normal sleep returns. CI cannot establish actual closed-lid behavior across Mac models.

## References

- [Upstream WakeBee](https://github.com/jswladitya/WakeBee)
- [Sleepless's free ad-hoc approach](https://github.com/Aboudjem/Sleepless#how-it-works) inspired the no-paid-certificate requirement; this fork retains WakeBee's independent watchdog rather than adding a sudoers grant.
- [Apple code signing requirement language, including cdhash](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html)
- [Apple NSXPCConnection code requirements](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:))
