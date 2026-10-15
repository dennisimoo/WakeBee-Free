# Contributing to WakeBee Free

This is an independent AGPL-3.0-only fork of [Aditya Jaiswal's WakeBee](https://github.com/jswladitya/WakeBee). Report fork issues [here](https://github.com/dennisimoo/WakeBee-Free/issues), not to the original developer.

Read [development and security details](docs/DEVELOPMENT.md). Keep changes focused and preserve authenticated XPC, battery/thermal limits, durable recovery, and fail-safe removal. Tests must use fake sleep settings and must not alter the host's actual sleep policy.

Run on macOS:

```sh
swift test --disable-sandbox
python3 -m unittest discover -s script -p 'test_*.py'
bash -n script/build_and_run.sh script/code_requirement.sh script/manage-helper.sh
./script/build_and_run.sh --build-only
```

Describe what was actually checked. Clearly distinguish policy simulation, compilation, signature validation, and physical Mac testing. Include Mac model, macOS version, and power source for lid-close reports. Do not commit passwords, certificates, or generated bundles. Disclose AI assistance in contributions. All contributions retain the [AGPL-3.0-only license](LICENSE) and original copyright notices.
