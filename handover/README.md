# Rosid handover

Written 26 November 2026 for the implementing agent. Start at `AGENTS.md` in the repository root if you have not read it.

## What you are delivering

1. **Rosid 2.0 for Android**: the app shown in the Figma file "Rosid", working offline, verified on your machine.
2. **A landing page** at `https://tanzir71.github.io/rosid/`, hosted on GitHub Pages from this repository, with the download for the app.
3. **A public repository** whose `main` branch holds all of it, pushed milestone by milestone.

## The files

| File | What it tells you |
|---|---|
| `STATUS.md` | The checklist you keep current. Read it first every session. |
| `00-current-state.md` | What exists in the repository today, and what is unproven. |
| `01-product.md` | What Rosid 2.0 is, feature by feature, and what it is not. |
| `02-architecture.md` | Technology decisions, the data model, and the fallback for each risk. |
| `03-verification.md` | How "working" is proved without a person and without GitHub Actions. |
| `04-repo-and-release.md` | Making the repository public, working on `main`, releases, signing. |
| `05-landing-page.md` | The landing page: structure, copy in both languages, hosting. |
| `milestones/M0` to `M9` | The work, in order. Each has a goal, steps, a "Done when" list and fallbacks. |
| `../design/` | Tokens, icons, a picture and a written spec of every screen. |

## How to work

1. Open `STATUS.md`. Find the first milestone that is not done.
2. Read that milestone file and the sections of `01` to `05` it points to.
3. Do the steps. Commit small, to `main`.
4. Run the verification the milestone asks for. Write the evidence to `evidence/M<n>/`.
5. Update `STATUS.md`: tick the milestone, add measured numbers, list anything not done and why.
6. Push. Then start the next milestone.

Every session ends with a push. If a session is cut short, `STATUS.md` must already say what is half done.

## Milestones at a glance

| | Milestone | Ends with |
|---|---|---|
| M0 | Ground rules and baseline | Public repo, no workflows, Pages from `main`, `tool/verify`, baseline green |
| M1 | Design system and app shell | New look, navigation, first run, both languages, light and dark |
| M2 | Capture and image | Live edge detection, auto capture, ID card mode, adjust page |
| M3 | Reading text | Benchmark, new text pipeline, measured gains, progress screen |
| M4 | Read and fix | Text view, key details, check words, tap a line, unit conversion |
| M5 | English draft | On-device translation, name book, term choices, dates and units |
| M6 | Export | PDF, Word, text, pictures, size limit, watermark, cover a detail |
| M7 | Library and bundles | Search inside papers, checklists, one-file bundle export |
| M8 | Expenses, settings, safety | Month view, receipt check, app lock, backup and restore |
| M9 | Landing page and release | Live page, signed APKs on GitHub Releases, final evidence |

After every milestone the app must build, start, and do everything it did before.

## Facts worth knowing before you start

- The owner's machine is Windows. The repository has PowerShell and Bash scripts side by side.
- Version 1.0.0 was published in July 2026 and has never run on a physical phone.
- Version 1's iPhone file was built by GitHub Actions on a hosted Mac. With no Actions, 2.0 is Android only. See `04-repo-and-release.md`.
- A branch named `codex/v2` holds an abandoned plan to train a handwriting model. Leave it alone. Do not merge it.
- Research behind the technology choices was done on 26 November 2026. Versions named in `02-architecture.md` were current that day. Check each on pub.dev or its source before you depend on it, and record what you actually used.
