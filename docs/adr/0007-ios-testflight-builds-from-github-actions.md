# 0007 iOS builds for TestFlight from GitHub Actions, without a Mac

Status: accepted (2026-11-19)

## Context

White Sum phase 1 must reach the owner and external testers on iPhone through TestFlight, with an App Store release as
a later option. Fixed by the owner: bundle id `nl.steefbeest.whitesum`, app name "White Sum", a personal (individual)
Apple Developer account, and no step may need a Mac: export, build, signing and upload all run on GitHub Actions. The
repository is public, so macOS runner minutes are free, but anything in the repository and in the workflow logs is
public too. CI today runs on Ubuntu and installs Godot 4.7.2 (Linux editor plus the full export templates, which
include the iOS template) through the kit action `addons/white_kit/ci/setup-godot`.

Five questions have to be answered: how to sign without a Mac, how to upload, when to build, how to number versions,
and how to get Godot and its iOS template onto the runners.

## Decision

1. **Two jobs, one workflow** (`.github/workflows/ios.yml`, owned by the game, not from the kit template):
   - `export` on `ubuntu-24.04`: the existing kit action `setup-godot` (unchanged), import, kit and game tests, then the
     Godot iOS export with `application/export_project_only = true`. Godot on a non-macOS host writes the Xcode project
     and stops before building ("Leaving Xcode project without building the package"). The project is passed on as a
     short-lived artifact.
   - `build` on `macos-26`: no Godot at all. `xcodebuild archive` and `xcodebuild -exportArchive` with manual signing,
     checks on the IPA, upload.
2. **Signing: manual signing with a distribution certificate and an App Store provisioning profile, stored as base64
   secrets.** The owner creates the private key and CSR with `openssl` on Linux, gets the Apple Distribution
   certificate and the App Store Connect provisioning profile from the developer website, and packs key and
   certificate into a `.p12`. The `build` job imports the `.p12` into a temporary keychain, installs the profile, and
   deletes both at the end (also on failure). Profile UUID and name are read from the profile itself, so they need no
   secret.
3. **Upload: `xcrun altool --upload-app` with an App Store Connect API key** (team key, role App Manager; `.p8` as a
   base64 secret, key id and issuer id as secrets). Fallback if a later Xcode drops `--upload-app`: the same
   `-exportArchive` call with `destination = upload` in the export options and the `-authenticationKey*` arguments.
4. **Trigger: manual `workflow_dispatch` (input `upload`, default true) and a pushed tag `v<config/version>`.** Never on
   ordinary pushes. Only `develop`, `main` and `v*` tags may build; the secrets live in a GitHub environment
   `testflight` whose deployment rule allows only those refs.
5. **Versions: `CFBundleShortVersionString` = `application/config/version` from `project.godot` (now `0.1.0`);
   `CFBundleVersion` = `github.run_number` of `ios.yml`.** The `export` job writes both, and the team id from the
   repository variable `APPLE_TEAM_ID`, into the runner's copy of `export_presets.cfg` before exporting; the committed
   preset keeps empty values. A tag build fails when the tag is not `v` + `config/version`.
6. **Godot on the runners: the kit action as it is.** The Linux editor and the export templates archive it installs
   already contain the iOS template; the macOS job does not run Godot. **No White Kit change is needed.** Only if the
   verification in design 16.9 step 1 shows that Godot 4.7.2 refuses the iOS export on Linux, the fallback is a kit
   change (macOS support in `setup-godot`: macOS editor download, SHA-512, template path under
   `~/Library/Application Support/Godot`), which must be requested and released in `dm-utils/white-kit`, never edited
   in `addons/white_kit` here.

## Alternatives considered

Signing:

- **fastlane match**: keeps certificates encrypted in a separate private git repository or bucket and syncs them on
  each run. Strong for teams with many apps and machines; for one person and one app it adds a second repository, a
  passphrase, a Ruby toolchain and a tool that may revoke or create certificates. Rejected.
- **fastlane cert and sigh with the API key on every run**: creates or downloads certificate and profile on the fly.
  A new certificate per run hits the account's small limit of distribution certificates, and a downloaded private key
  is not possible (Apple never returns it), so it would still need a stored key. Rejected.
- **Xcode automatic signing with `-allowProvisioningUpdates` and the API key (cloud-managed certificates)**: no files
  to store, but every fresh runner registers a new development certificate for the archive step, it needs an Admin
  key, and failures are hard to reproduce. Rejected.
- **Let Godot run `xcodebuild` itself** (export on macOS without `export_project_only`): needs the macOS editor on the
  runner (a kit change) and hides the signing settings inside the exporter. Rejected; explicit `xcodebuild` calls keep
  every signing setting visible in the workflow.

Upload:

- **fastlane pilot**: can also assign builds to external groups and submit them for beta review, but brings Ruby and
  fastlane for one upload command. Rejected for now; worth revisiting when builds go to external testers often.
- **iTMSTransporter directly**: same service as `altool`, longer command line, no gain. Rejected.

Trigger:

- **Every push to `develop`**: every upload uses a build number and lands in TestFlight; testers would get several
  builds a day, and a failed signing secret would turn every push red. Rejected.
- **Tag only**: makes a quick test build for the owner awkward. Rejected as the only trigger; tags remain for builds
  that may later go to the App Store.

Versions:

- **Build number from a counter file in the repository**: needs a commit per build. Rejected.
- **Build number from the commit count**: not strictly increasing across branches and history rewrites. Rejected.
- **A second hand-maintained version in the preset**: two places for one number. Rejected.

Runners:

- **Everything on one macOS job with the macOS Godot editor**: simpler graph, but a kit change before the first build.
  Kept only as the fallback of decision 6.

## Consequences

- No Mac and no Xcode installation on the owner's side; all Apple-side steps are on the web (developer website, App
  Store Connect) plus `openssl` on Linux.
- The certificate and the profile expire after one year. The workflow warns 30 days ahead; renewal repeats the
  owner's certificate and profile steps and updates three secrets.
- Re-running a job whose upload already succeeded fails with a duplicate build number; start a new run instead.
- Externally visible: the Team ID ends up in the public workflow logs and in every signed app; it is an identifier, not
  a credential. Secrets are only available to the `build` job through the `testflight` environment and never printed.
- New builds reach the internal group automatically; the external group gets a build when the owner adds it in App
  Store Connect (fastlane pilot could automate this later).
- The iOS workflow duplicates the test steps of `ci.yml`. If other White games want iOS builds, the workflow is a
  candidate for a kit template (a kit card, not part of this change).
