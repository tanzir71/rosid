# Rosid: instructions for the implementing agent

You are building version 2 of Rosid (রসিদ), an offline Android app that scans any Bangla or English paper, reads it, makes an English draft, and packs papers for an application. You also build its landing page on GitHub Pages.

You work alone. The owner will not test, review, approve, tap, sign in, or answer questions. Everything you need is in this repository.

## Read in this order

1. `handover/README.md` (how the work is organised)
2. `handover/STATUS.md` (where the work stands; you keep it current)
3. `handover/00-current-state.md` to `handover/05-landing-page.md`
4. `design/README.md` and `design/screens.md`
5. The milestone file you are about to start, in `handover/milestones/`

`CODEX_HANDOVER.md`, `TASKS.md` and `PROGRESS.md` describe version 1. They are history. Where they disagree with `handover/`, `handover/` wins.

## Rules that never bend

1. **The app never goes online.** No `INTERNET` or `ACCESS_NETWORK_STATE` permission in the release manifest. No analytics, crash reporting, remote config, cloud OCR, cloud translation, or model download at run time. Every model and font ships inside the APK. Your development machine may download dependencies, models and fonts while building.
2. **No owner involvement.** Never write a step that needs the owner. Never stop to wait for an answer. If something cannot be done without a human, record it in `handover/STATUS.md` under "Not done, needs a person", take the documented fallback, and continue.
3. **Commit straight to `main`.** No feature branches, no pull requests. Push after every green verification. Never force-push. Never rewrite history.
4. **No GitHub Actions.** Delete the existing workflow files in M0 and never add one. All checks run on your machine.
5. **Deliver in milestones.** Work through M0 to M9 in order. A milestone is done only when its "Done when" list passes on your machine, its evidence is committed, `handover/STATUS.md` is updated, and the commits are pushed.
6. **Never claim what you did not check.** A gate you could not run is "not run", with the reason. It is never "passed". This applies to commit messages, STATUS, release notes and the landing page.
7. **Never weaken a gate silently.** If a threshold in `handover/03-verification.md` cannot be met, keep the number, record the measured value and the reason in STATUS, and ship the documented fallback.
8. **Keep secrets out of git.** Keystores, passwords and tokens stay outside the repository. Never print a token.
9. **Stay inside this repository's purpose.** Do not add features that are not in `handover/01-product.md` or the Figma design.

## Commands

Run from the repository root. PowerShell is the primary shell on the owner's machine; keep the Bash scripts working too.

```powershell
flutter pub get
.\tool\verify.ps1                 # level A: generate, format, analyse, test, offline audit
.\tool\verify.ps1 -Emulator       # level B: adds emulator end-to-end checks
.\tool\verify.ps1 -Release        # level A + B + release build, size and alignment checks
```

`tool/verify.ps1` and `tool/verify.sh` do not exist yet. You create them in M0 from `tool/check.ps1` and `tool/check.sh`. See `handover/03-verification.md`.

## How to commit

- Message: `M<number>: <what changed>` in the imperative, for example `M3: add line detector and Latin recogniser`.
- One logical change per commit. Evidence and STATUS updates go in the same push as the work they describe.
- Before every push: `tool/verify` at the level the milestone asks for is green.

## When something fails

1. Read the error. Fix the cause, not the symptom.
2. After three failed attempts at the same problem, stop that approach. Write what you tried in STATUS, take the fallback named in the milestone file, and move on.
3. If there is no fallback, mark the item "not done" with the reason and continue with work that does not depend on it.
4. Never disable a test to get green. A test that is wrong is fixed or replaced, and the commit says why.

## Design

The Figma file "Rosid" is the source of truth: <https://www.figma.com/design/klPtRBHW0EB1xghRgoReKt/Rosid>. If you have Figma access, read frames by the node ids in `design/screens.md`. If you do not, `design/screens/*.png`, `design/tokens.json`, `design/icons/*.svg` and `design/screens.md` are complete enough to build from.

Do not redesign. Where the design does not show a state (empty, loading, error), build it from the same components and tokens and note it in STATUS.

## What only a person could do

Do not wait for any of these. Record them and continue.

- Choosing a licence for the repository (none exists; do not invent one).
- Signing in to GitHub on this machine, if neither `git push` nor `gh` works.
- Anything on a physical phone.
- Anything involving Apple signing or an iPhone build.
- Android developer verification, if Google later requires it for Bangladesh.
