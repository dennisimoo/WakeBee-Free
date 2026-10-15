<p align="center"><img src="Resources/WakeBee.png" width="96" alt="Original WakeBee bee icon"></p>

# WakeBee Free

A free, independent fork of [WakeBee by Aditya Jaiswal](https://github.com/jswladitya/WakeBee). Keep your Mac awake during timed or unlimited sessions, including optional closed-lid sessions. **No activation key, purchase, subscription, or paid Apple Developer account is required.** AGPL-3.0-only; original copyright and attribution are preserved.

**Experimental:** this fork changes privileged helper installation and authentication. macOS CI builds and policy tests do not establish physical lid-close reliability on your Mac. Test a short session and verify normal sleep returns before relying on unattended work.

## Download

Check [Releases](https://github.com/dennisimoo/WakeBee-Free/releases) for an experimental universal Mac download, or the latest successful [Actions run](https://github.com/dennisimoo/WakeBee-Free/actions) for its `WakeBee-Free-macOS` artifact. Requires macOS 14 or newer, Intel or Apple silicon.

1. Unzip and move `WakeBee.app` to Applications. Finder displays it as **WakeBee Free**.
2. Open it. These builds are **ad-hoc signed, not Apple-notarized**. macOS may require you to approve the app in **System Settings → Privacy & Security → Open Anyway**. No Apple payment is required to run your own build.
3. Choose a timer, an end time, or **Until I stop it**, then start a session. There is no license screen or activation request.

There is no automatic updater. The fork never contacts Polar or the original project's update feed. Download future versions from this repository.

## Closed-lid mode without a paid signing identity

1. Keep the lid open, connect your charger, and choose **Set up…** beside Closed-lid mode.
2. Approve the administrator-password prompt. This installs a small root-owned recovery helper and its LaunchDaemon. It does **not** add a passwordless `sudoers` rule.
3. Start a session and wait for **Ready to close the lid** before closing it.

The app and helper authenticate each other with exact CodeDirectory hash requirements. The helper also checks the installing user's UID. Ad-hoc signatures identify the exact approved build, rather than an Apple developer team. Updating/rebuilding the app changes that identity and requires admin approval to update the installed helper.

The helper retains upstream's limits and restoration behavior:

- Charger required by default; optional battery operation with a cutoff and battery-time limit.
- Four continuous hours maximum for closed-lid protection, plus thermal and power-reading checks.
- Renewals every 10 seconds; leases expire after 30 seconds without app contact.
- Normal completion, quitting, disconnects, and safety limits restore the prior sleep setting.
- A durable journal survives helper crashes. Failed restoration is retried, and uninstall/update refuses to discard the recovery mechanism if restoration fails.
- Sessions never automatically resume after relaunch or system sleep.

Use a hard, ventilated surface. Test on your actual Mac and macOS version. Other tools that change the same system-wide sleep setting can interfere; remove an existing official WakeBee/AwakeMac closed-lid helper before setting up this fork.

To remove the helper, end your session and choose **Settings → Closed Lid → Advanced → Remove closed-lid setup…**. This also requires administrator approval. Remove it before deleting the app.

## Build from source

Requires **Xcode with the macOS 26.1 SDK or newer**, Swift 6, and Python 3. The app still targets macOS 14; newer interface controls have availability checks.

```sh
git clone https://github.com/dennisimoo/WakeBee-Free.git
cd WakeBee-Free
./script/build_and_run.sh --build-only
open dist/WakeBee.app
```

The default signature is ad-hoc and supports closed-lid setup. No `.signing-identity`, certificates, notarization credentials, or activation key are needed. To build both CPU architectures:

```sh
WAKEBEE_UNIVERSAL=1 WAKEBEE_BUILD_CONFIGURATION=release \
  ./script/build_and_run.sh --build-only
```

See [development and security details](docs/DEVELOPMENT.md) and [contribution instructions](CONTRIBUTING.md).

## Credits and license

Original WakeBee, artwork, and implementation: **Copyright © 2026 Aditya Jaiswal**. This independent fork removes paid activation, replaces Apple-team helper registration with admin-approved installation and exact-build authentication, and removes the original update integration. It is not an official WakeBee release or endorsed by its author. Fork changes were AI-assisted and made in October 2026.

Licensed under [GNU Affero General Public License v3.0 only](LICENSE). If you distribute modified binaries, provide the corresponding source under this license, including build and installation scripts. The original developer's paid app remains available at [wakebee.app](https://wakebee.app).
