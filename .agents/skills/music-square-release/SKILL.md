---
name: music-square-release
description: >-
  Standard operating procedure for creating, testing, version bumping, building,
  and publishing release bundles (.aab) for Music Square and updating remote version.json.
  Use whenever releasing or preparing a new version/update for Music Square.
---

# Music Square Release Procedure

Follow these exact steps when creating and publishing any new release for Music Square.

---

## 1. Automated Test Verification

Before any version bump or release build, run the headless Godot test suite:

```powershell
& "C:\Users\dumio\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\dumio\Documents\music-square" --script "C:\Users\dumio\.gemini\antigravity\brain\7474d2e9-8729-4cbf-8610-63fbaa062afd\scratch\test_story_mode.gd"
```

Verify that all assertions pass and the process exits with `code 0`.

---

## 2. Version Bumping Across All 4 Files

When bumping version (e.g. `X.Y.Z` and `versionCode: N`):

1. **`export_presets.cfg`**:
   ```ini
   version/code=N
   version/name="X.Y.Z"
   ```
2. **`main.gd`**:
   ```gdscript
   const CURRENT_VERSION_NAME: String = "X.Y.Z"
   const CURRENT_VERSION_CODE: int = N
   ```
3. **`main.tscn`**:
   Update the menu version label:
   ```tscn
   text = "vX.Y.Z"
   ```
4. **`update_manager.gd`**:
   ```gdscript
   ## Current Release: X.Y.Z (versionCode: N)
   const CURRENT_VERSION_NAME: String = "X.Y.Z"
   const CURRENT_VERSION_CODE: int = N
   ```

---

## 3. Git Commit & Release Tagging in `music-square`

1. Stage only game release files (do NOT commit untracked or local addon changes like `addons/godot_ai`):
   ```powershell
   git -C "C:\Users\dumio\Documents\music-square" add export_presets.cfg gamesettings.gd main.gd main.tscn project.godot update_manager.gd
   ```
2. Create release commit:
   ```powershell
   git -C "C:\Users\dumio\Documents\music-square" commit -m "release: bump version to X.Y.Z (versionCode N)"
   ```
3. Tag the release:
   ```powershell
   git -C "C:\Users\dumio\Documents\music-square" tag -a vX.Y.Z -m "Release vX.Y.Z (versionCode N)"
   ```
4. Push commit and tag to remote:
   ```powershell
   git -C "C:\Users\dumio\Documents\music-square" push origin main --follow-tags
   ```

---

## 4. Build Signed Android App Bundle (.aab)

### A. Prevent Duplicate Resource Collision
Godot headless editor runs may auto-inject `android/build/res/values/strings.xml` while `android/build/src/main/res/values/strings.xml` already exists. Ensure no duplicate exists before building:
```powershell
Remove-Item "C:\Users\dumio\Documents\music-square\android\build\res\values\strings.xml" -Force -ErrorAction SilentlyContinue
```

### B. Run Gradle Bundle Build
Build the signed `.aab` directly using the project's release keystore (`music_square_release.keystore`):

```powershell
Set-Location "C:\Users\dumio\Documents\music-square\android\build"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot"
$env:ANDROID_HOME = "C:\Users\dumio\AppData\Local\Android\Sdk"
.\gradlew.bat bundleStandardRelease `
  "-Prelease_keystore_file=C:/Users/dumio/Documents/music-square/music_square_release.keystore" `
  "-Prelease_keystore_password=MusicSquare2026Release!" `
  "-Prelease_keystore_alias=musicsquare" `
  "-Pexport_package_name=com.psygames.musicsquare" `
  "-Pexport_version_code=N" `
  "-Pexport_version_name=X.Y.Z" `
  "-Pexport_version_min_sdk=24" `
  "-Pexport_version_target_sdk=36" `
  "-Pperform_zipalign=true" `
  "-Pperform_signing=true" `
  "-Pcompress_native_libraries=false"
```

### C. Copy and Verify Output
Copy the generated bundle to `build/MusicSquare.aab`:
```powershell
Set-Location "C:\Users\dumio\Documents\music-square"
if (-not (Test-Path "build")) { New-Item -ItemType Directory -Path "build" }
Copy-Item "android/build/build/outputs/bundle/standardRelease/build-standard-release.aab" "build/MusicSquare.aab" -Force
Get-Item "build/MusicSquare.aab" | Format-List FullName, Length, LastWriteTime
```

---

## 5. Update Remote `version.json` in `Psyman20.github.io`

Update the remote in-game update notification metadata so active players receive the update prompt:

1. **File Path**: `C:\Users\dumio\Documents\Psyman20.github.io\version.json`
2. **Update Fields**:
   - `latest_version`: `"X.Y.Z"`
   - `version_code`: `N`
   - `title`: `"UPDATE AVAILABLE"`
   - `message`: Summary of new update
   - `release_notes`: Bullet points of new features and fixes
3. **Commit & Push**:
   ```powershell
   git -C "C:\Users\dumio\Documents\Psyman20.github.io" add version.json
   git -C "C:\Users\dumio\Documents\Psyman20.github.io" commit -m "update version.json for Music Square vX.Y.Z (versionCode N)"
   git -C "C:\Users\dumio\Documents\Psyman20.github.io" push origin main
   ```
