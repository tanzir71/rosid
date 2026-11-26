# Repository, publishing and releases

Repository: `https://github.com/tanzir71/rosid`. Owner account: `tanzir71`. Default branch: `main`.

## Access

Before M0, check what you can do:

```text
git -C <repo> fetch origin
gh auth status
gh api repos/tanzir71/rosid --jq .permissions
```

- If `git push` works, you can deliver. If `gh` is signed in with admin rights, you can also change visibility, Pages and releases.
- If `git push` fails for lack of sign-in: keep working and committing locally. At the end of each milestone try the push again. Record "GitHub sign-in on this machine" under "Not done, needs a person" in STATUS. Never ask for a token, never search the machine for one, never put one in a file or a remote URL.
- If `gh` is missing, install GitHub CLI with the system package manager (`winget install --id GitHub.cli` on Windows). Installing it does not sign it in.

## Git identity

Use the identity already configured on the machine. If none is configured, set a repository-local one:

```text
git config user.name "Rosid build agent"
git config user.email "tanzir71@users.noreply.github.com"
```

and note it in STATUS.

## Working on `main`

- Commit straight to `main`. No branches, no pull requests.
- Before pushing: `git pull --rebase origin main` (the owner may have pushed). If the rebase conflicts in files you did not touch, stop that push, record it in STATUS, and keep the owner's version.
- Never force-push. Never delete or move a tag. Never rewrite history.
- Leave the branch `codex/v2` and the tag `v1.0.0` as they are.
- Check for rules that block direct pushes: `gh api repos/tanzir71/rosid/rulesets` and `gh api repos/tanzir71/rosid/branches/main/protection`. If a rule requires pull requests on `main`, and your `gh` has admin rights, change that rule so `main` accepts direct pushes from the owner's account, and say so in the commit message of your next push and in STATUS. Leave the `v*` tag protection in place.

## Line endings

The working tree on the owner's machine shows files modified by line endings only. In M0, add `.gitattributes`:

```text
* text=auto
*.ps1 text eol=crlf
*.bat text eol=crlf
*.sh text eol=lf
*.png binary
*.jpg binary
*.onnx binary
*.traineddata binary
*.bin binary
*.ttf binary
*.woff2 binary
*.jks binary
```

Then `git add --renormalize .` and commit as `M0: normalise line endings`. Check with `git diff --stat HEAD~1` that only line endings changed.

## Making the repository public (M0)

The owner asked for the repository to be public. Do it in M0, after these checks pass:

1. Secret scan of all history on all branches and tags. Install `gitleaks` if possible and run `gitleaks git --log-opts="--all" --redact`. Also search for key files: `git log --all --name-only --format= | sort -u | grep -Ei '\.(jks|keystore|p12|pem|key)$|key\.properties|\.env$|credentials'`.
2. If anything is found: do not make the repository public. Do not rewrite history to remove it. Record exactly what was found (path and commit, not the secret itself) under "Not done, needs a person" and continue all other work.
3. Confirm no personal data in fixtures: look at the pictures in `assets/fixtures/` and the text in `test/fixtures/receipts/`. If one shows a real person's details, replace it with a synthetic one before going public.
4. Then:

```text
gh repo edit tanzir71/rosid --visibility public --accept-visibility-change-consequences
gh repo edit tanzir71/rosid --description "Offline Bangla and English paper scanner for Android: scan, read, translate to an English draft, export." --homepage "https://tanzir71.github.io/rosid/"
gh repo edit tanzir71/rosid --enable-issues --enable-wiki=false
```

5. Record the time and result in STATUS.

There is no licence file. Public is not the same as open source: without a licence, others may read but not reuse the code. Do not add a licence. Record the open choice in STATUS (already listed).

## No GitHub Actions (M0)

- Delete `.github/workflows/checks.yml`, `ios-lock.yml`, `pages.yml` and `release.yml`. Delete `.github/dependabot.yml` if present (it opens pull requests).
- Never add a workflow, composite action or reusable workflow.
- Do not rely on any GitHub-hosted check. All checks are in `tool/verify`.
- Once Pages is confirmed to deploy without Actions (below), turn Actions off for the repository: `gh api -X PUT repos/tanzir71/rosid/actions/permissions -F enabled=false`. If Pages stops deploying after this, turn it back on (`-F enabled=true`), keep zero workflow files, and record it.

## GitHub Pages without Actions (M0, then M9)

Pages serves the landing page from the `docs/` folder on `main`. With a `.nojekyll` file at the root of the published folder, GitHub deploys the files as they are, without running a Jekyll build through Actions.

1. Move everything in the existing `docs/` (`ARCHITECTURE.md`, `IOS_SELF_SIGNING.md`, `MANUAL_QA.md`, `RELEASING.md`, `WEBSITE_RESEARCH.md`, `audits/`) to `notes/` with `git mv`. Update links to them in `README.md`, `tool/` scripts and elsewhere (`grep -rn "docs/" --include=*.md --include=*.ps1 --include=*.sh --include=*.py .`).
2. Create `docs/.nojekyll` (empty) and a placeholder `docs/index.html` that says, in Bangla and English, that version 2 is being built and links to the version 1 release. Same design tokens, no external requests.
3. Switch Pages from the workflow build to the branch:

```text
gh api -X PUT repos/tanzir71/rosid/pages -f build_type=legacy -f "source[branch]=main" -f "source[path]=/docs"
```

If Pages was never enabled, use `-X POST` with the same fields.
4. Push, wait a minute, then check: `gh api repos/tanzir71/rosid/pages/builds/latest --jq .status` is `built`, and `curl -sI https://tanzir71.github.io/rosid/` returns 200. Record both in `evidence/M0/`.
5. `site/` and `tool/prepare_site.py` stay until M9, then are removed (the new page lives in `docs/`).

## Signing key

Version 1 was signed with a key the owner has. Releases must keep the same key if at all possible, so version 2 installs over version 1.

1. If `android/key.properties` exists on this machine and the keystore it points to exists, use them. Do not open, print or copy the passwords anywhere.
2. Otherwise look in `tool/setup_release_signing.ps1` for where version 1 expected the keystore, and check that location.
3. If no keystore is found: create a new one outside the repository, in `%USERPROFILE%\.rosid\` (Windows) or `~/.rosid/` (other systems), with a long random password. Write `android/key.properties` pointing to it (the file is ignored by git; check with `git check-ignore android/key.properties`). Record under "Not done, needs a person": "Version 2 is signed with a new key. Version 1 users must uninstall before installing. Back up the folder .rosid in the home folder; losing it means future updates cannot install over this one." Say the same in the release notes and on the landing page install steps.
4. Never commit the keystore, its password or `key.properties`. `tool/verify -Release` fails if any of them is tracked.

## Building a release (M9)

```text
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --obfuscate --split-debug-info=build/symbols --tree-shake-icons
```

- Version in `pubspec.yaml`: `2.0.0+20000`. Check with `aapt2 dump badging` that every APK's version code is higher than 1, and that the arm64 code is higher than the 32-bit one.
- Rename outputs to `rosid-arm64-v8a.apk` and `rosid-armeabi-v7a.apk`.
- Run the Release gates in `03-verification.md` on these exact files.
- Write `SHA256SUMS.txt` with the SHA-256 of each APK, and record the signing certificate SHA-256 from `apksigner verify --print-certs`.
- Keep `build/symbols` out of git. Zip it as `symbols-2.0.0.zip` and attach it to the release, so crashes can be decoded later.

## Publishing a release (M9)

Releases on this repository are immutable once published, so publish only after checking the draft.

```text
gh release create v2.0.0 --draft --title "Rosid 2.0.0" --notes-file evidence/M9/release-notes.md rosid-arm64-v8a.apk rosid-armeabi-v7a.apk SHA256SUMS.txt symbols-2.0.0.zip
gh release download v2.0.0 --dir build/check --clobber
```

Compare the downloaded checksums with `SHA256SUMS.txt`. If they match, publish:

```text
gh release edit v2.0.0 --draft=false --latest
```

Release notes (both languages) must include: what is new, that the app has no internet permission, Android 8 or newer, which file to pick ("most phones from the last eight years need the arm64 file"), checksums, signing certificate fingerprint, the signing-key note if a new key was used, and "Not verified by machine" items in plain words.

If `gh` cannot publish (no sign-in), commit everything, record it, and stop at that step. The landing page must then point to the version 1 release, not to a missing file.

## iPhone

Version 1 built its unsigned iPhone file on a GitHub-hosted Mac. Without GitHub Actions that route is gone, so 2.0 is Android only.

- Leave `ios/` in place, untouched except where a Dart package requires a minimum version bump (ONNX Runtime needs iOS 16).
- Remove the iPhone file from the landing page and README.
- Record "iPhone build needs a Mac" under "Not done, needs a person".
- Only if this machine is a Mac with Xcode, and only after v2.0.0 for Android is published, you may build the unsigned iPhone file the way `notes/IOS_SELF_SIGNING.md` describes and publish it in a later patch release (published releases cannot be changed). Never let this delay the Android release.

## What goes in git

| Yes | No |
|---|---|
| Source, tests, fixtures, generator scripts | APKs, AABs, symbols |
| Models and fonts the app bundles (each under 95 MB) | Keystores, `key.properties`, tokens |
| `evidence/M<n>/` summaries, logs, screenshots (keep each milestone under 20 MB) | Emulator images, build folders |
| `docs/` landing page | Downloaded tools |

Do not use Git LFS; Pages and a plain clone must both work. If a model file would exceed 95 MB, it does not ship.
