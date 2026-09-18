# Black-Amethyst

An automated, rebranded rebuild of [AngelAuraMC/Amethyst-Android](https://github.com/AngelAuraMC/Amethyst-Android)
(a PojavLauncher-based Minecraft: Java launcher for Android) tuned for **offline
testing on an air-gapped device**.

This repo holds **no launcher source** — only a pipeline. CI fetches the latest
upstream release, applies a tiny patch, builds an APK, and publishes it here as
a Release. You never build anything by hand.

## What's different from upstream

| | Upstream Amethyst | Black-Amethyst |
|---|---|---|
| Add offline account | Blocked until you have an online (Microsoft) account | **Works right away, no internet, no prior account** |
| App name | Amethyst | **Black-Amethyst** |
| Package | `org.angelauramc.amethyst` | `io.github.jackofnonetrades.blackamethyst` |
| Signing | AngelAuraMC release key | Self-signed debug key (sideload) |
| Java runtime | downloaded in-app / bundled | **JRE 8 bundled** (works offline) |

### The one functional change

Upstream gates the **Local** (offline) account button behind
`hasNoOnlineProfileDialog()`, which refuses to open the offline-login screen
unless you *already* have an online Microsoft profile — a chicken-and-egg lock
on a device with no internet. Black-Amethyst removes that gate (one line in
`SelectAuthFragment.java`) so you can create an offline account immediately.

## How the automation works

`.github/workflows/black-amethyst.yml`:

1. **Every 6 hours** (and on-demand) checks the newest upstream **Release**.
2. If that version was already built here, the run ends green — nothing to do.
3. Otherwise it checks out that upstream tag, bundles an offline Android JRE 8
   (repacked from AngelAuraMC's stable `download_jre8` release), applies the
   patches, builds a release APK, and publishes it as `ba-<version>`.

Every patch is applied by **pattern matching and then verified**. If upstream
refactors so a pattern no longer matches — or the upstream tag isn't
version-shaped, or the APK comes out missing/unsigned — the run **fails loudly**
instead of shipping a silently-wrong build.

## Trigger a build by hand

- **UI:** Actions → *Black-Amethyst release sync* → **Run workflow**
  (tick *force* to rebuild the current version even if already published).
- **CLI:** `gh workflow run black-amethyst.yml -R JackOfNoneTrades/Black-Amethyst`
  (add `-f force=true` to force a rebuild).

Grab the APK from the newest [Release](../../releases) and sideload it.

## The knobs (only if you ever care)

Both live at the top of the workflow's `env:` block:

- `BA_PACKAGE` — the Android application id. Changing it after you've installed
  once means the next build installs as a *separate* app (Android keys installs
  by package). Pick it before your first install.
- `BA_APP_NAME` — the display name.

## Layout

```
.github/workflows/black-amethyst.yml   the pipeline
scripts/patch.py                       rebrand + offline-account patcher (verified)
scripts/repack_jre.sh                  repacks Android JRE 8 into Pojav's layout
scripts/regen_icons.sh                 rebuilds the icon overlay from icon/master/
icon/master/                           hand-edited icon sources (PNG)
icon/res/                              generated per-density overlay (copied onto upstream res/)
```

To change the app icon: edit the PNGs in `icon/master/`, run `scripts/regen_icons.sh`,
commit. The CI lays `icon/res/` over upstream's resources before each build.

## Notes

- Not affiliated with or endorsed by AngelAuraMC. Upstream is LGPL-3.0; this
  repo only automates a build of it for personal testing.
- Debug-signed builds are for sideloading, not the Play Store.
