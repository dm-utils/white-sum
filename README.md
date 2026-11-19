# White Sum

A daily puzzle game in the White series. Tiles numbered 1 to 5 sit on a board under gravity. Swap two neighbouring
tiles or slide one sideways; a row or column of touching tiles that adds up to exactly 10 vanishes. Clear the board in
as few moves as possible.

Status: phase 1 built (rules, solver, generator, tools, a pool of 40 practice sets in three levels, the screen and the
web version). Selecting a tile shows the sums of its row and column. No daily puzzle yet.

- Play version: https://play.white-sum.steefbeest.nl
- Design: `docs/design.md`, decisions in `docs/adr/`, terms in `docs/glossary.md`, rules for code and data in
  `docs/conventions.md`.

## Development

Godot 4.7.2. The shared base White Kit is a git submodule at `addons/white_kit`; clone with submodules:

```bash
git clone --recurse-submodules https://github.com/dm-utils/white-sum.git
# or, after a plain clone:
git submodule update --init
```

Run the tests headless:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/run_tests.tscn
```

Debug screenshots (needs `xvfb`; scenarios in `tools/shots.txt`):

```bash
addons/white_kit/tools/shots.sh run . tools/shots.txt build/shots
```

Measure the generator and build puzzles (see `docs/conventions.md`):

```bash
godot --headless --path . -s res://tools/measure.gd -- --seeds=50 --level=1 --skip-m1
godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=5 --start=0 --out=build/practice_0.json
godot --headless --path . -s res://tools/verify_puzzles.gd -- --file=data/practice.json
```

## iOS

TestFlight builds come from `.github/workflows/ios.yml` (Actions, "iOS", Run workflow, on `develop` or `main`, or a pushed
tag `v<version>`). Godot exports the Xcode project on Linux; a macOS job archives, signs, checks and uploads it. Run with
`signing` off for an unsigned compile check that needs no secrets. Details: `docs/design.md` section 16 and
`docs/adr/0007-ios-testflight-builds-from-github-actions.md`.

Repository variable: `APPLE_TEAM_ID`. Secrets in the environment `testflight`: `IOS_DIST_CERT_P12_BASE64`,
`IOS_DIST_CERT_PASSWORD`, `IOS_PROFILE_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`.

Regenerate the app icons after a change to `icon.svg`:

```bash
godot --headless --path . -s res://tools/ios_icons.gd
```

All rights reserved.
