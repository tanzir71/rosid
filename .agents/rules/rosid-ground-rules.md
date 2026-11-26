---
trigger: always_on
---

# Rosid ground rules

These repeat the rules in `AGENTS.md`. If the two ever differ, `AGENTS.md` wins.

- The app never goes online. No network permission, no analytics, no run-time downloads.
- The owner is not available. Never ask, never wait. Record what needs a person in `handover/STATUS.md` and continue.
- Commit straight to `main` and push after every green verification. No branches, no pull requests, no force-push.
- No GitHub Actions. All checks run locally through `tool/verify`.
- Work in milestones M0 to M9. A milestone is done only with passing gates, committed evidence and an updated STATUS.
- A check that was not run is reported as not run, never as passed.
- Follow the Figma design and `design/`. Do not redesign.
