# Rosid design

Source of truth: Figma file "Rosid", <https://www.figma.com/design/klPtRBHW0EB1xghRgoReKt/Rosid>.

| Figma page | What is on it |
|---|---|
| Screens (`0:1`) | Board "00 Start here" (`14:1600`), then sections 01 to 11 with 33 phone screens at 412 by 915 |
| Design system (`3:2`) | Foundations board (`15:2090`), 15 components with variants, 56 icons (`5:2`) |
| Landing page (`19:2090`) | Desktop English (`19:2100`) and mobile Bangla (`19:2577`) |

This folder lets you build without Figma access:

| Path | Contents |
|---|---|
| `screens.md` | Every screen: node id, picture, route, content, behaviour |
| `screens/*.png` | Every screen at 412 by 915 |
| `tokens.json` | Colours (light and dark), sizes, radii, text styles, shadows, exported from Figma variables and styles |
| `icons/*.svg` | 56 stroke icons, 24 by 24, `stroke="currentColor"` |
| `landing/*.png` | The two landing frames |
| `landing/papers/*.svg` | Six paper illustrations used on the landing page |

If Figma and this folder disagree, Figma wins. If the design and `handover/01-product.md` disagree about behaviour, the product file wins; about looks, the design wins.

## Language of the design: "Mohor"

Named after the office seal. The app is about official paper, so its look borrows from paper, ink and rubber stamps, and nothing else.

- **Canvas** is pale official paper (`bg/canvas` `#F2F4EE`). **Ink** is blue-black (`ink/primary` `#1A1B2E`). The **accent** is stamp-pad violet (`accent/base` `#4333B0`).
- **Paper is always light.** Any surface that shows a scanned or generated page uses the `paper/*` colours, in dark theme too. Pages are never tinted dark.
- **Two motifs, used sparingly.** The rubber stamp marks the state of a document (DRAFT, SAVED, CERTIFIED). The highlighter marks something the user should check. Do not use either as decoration. A screen has at most one stamp.
- **Two typefaces.** Anek Bangla for the interface in both scripts. Tiro Bangla for document text (what is on the paper). Never mix them inside one line.
- **No italics** anywhere.
- **Radii carry meaning**: paper 4, controls 12, sheets 24, pills 999.
- **Words**: sentence case, plain verbs, the action named the same way through a flow ("Save to phone" leads to "Saved to your phone"). Errors say what happened and what to do. Empty screens invite the next action.
- **Overusing an element makes it cheap.** Prefer one strong element per screen to many small ones.

## Components

On page "Design system". Variant property in brackets.

| Component | Node | Variants |
|---|---|---|
| Status bar | `6:11` | |
| Button | `6:36` | kind: primary, tonal, outline, ghost |
| Chip | `6:47` | state: off, on |
| Pill | `6:63` | tone: neutral, accent, good, warn, bad |
| Stamp | `6:76` | tone: accent, good, bad |
| Field | `6:94` | state: default, check |
| Toggle | `6:101` | |
| Radio | `6:107` | |
| Paper (thumbnail) | `6:164` | kind: letter, land, certificate, id, receipt (the landing page adds a notes sheet; add `notes` in code) |
| Nav dock | `6:313` | active: home, library, bundles, expenses |
| Top bar | `6:327` | |
| Paper row | `6:345` | |
| Check row | `6:375` | status: done, check, missing |
| Reader tabs | `6:400` | active: scan, text, english |
| Icons | `5:2` | 56 components named `icon/<name>` |

Sizes: buttons and fields 52 high; chips and tabs 36 to 40; touch targets at least 48 by 48. Screen side margin 20. Bottom dock floats 12 above the bottom edge with `elev/dock`.

## Dark theme

Dark values for every colour token are in `tokens.json`. Screens "Home (dark)", "Read / Text (dark)" and "Translate / English draft (dark)" show how paper stays light on a dark canvas.
