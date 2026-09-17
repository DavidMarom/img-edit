# ImgEdit

A tiny macOS menu-bar utility for quick, file-free image touch-ups. Hit a hotkey, edit whatever's on your clipboard, push it back — no windows to manage, no files to save, nothing left behind.

## Why

Sometimes you just copied a screenshot or an image and want to crop it, nudge a piece around, or scribble a quick annotation before pasting it somewhere else. Opening a full editor for that is overkill. ImgEdit lives quietly in the menu bar and does exactly that one job.

## Features

- **Global hotkey** — press `⌘⇧E` from anywhere to open an editor on whatever image is currently on the clipboard.
- **Move tool** — drag out a selection, reposition it, commit with `Enter` or cancel with `Esc`.
- **Crop tool** — drag out new canvas bounds, with draggable corner handles before committing.
- **Pen tool** — freehand annotate directly on the image.
- **Clipboard in, clipboard out** — no file dialogs, no saved documents. Save writes a PNG (with alpha) straight back to the pasteboard.
- **Stays out of the way** — a menu-bar–only app (no Dock icon), optionally launches at login.

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ / Xcode 15+

## Getting started

Clone the repo and run it straight from Swift Package Manager:

```bash
swift run
```

Or open it in Xcode:

```bash
open Package.swift
```

To produce a signed, double-clickable `.app` bundle (installed to the repo root as `ImgEdit.app`):

```bash
./Scripts/build_app.sh
```

## Usage

1. Copy an image — a screenshot, a file in Finder, pixels from any app.
2. Press `⌘⇧E`. An editor window opens with that image loaded.
3. Pick a tool from the toolbar (Move, Crop, or Pen) and edit.
4. Click **Save to Clipboard** to write the result back and close the window.

Only one editing session runs at a time — triggering the hotkey again just refocuses the open window instead of starting a new one.

## Project layout

```
Sources/ImgEdit/
├── main.swift                  — app entry point (accessory/menu-bar app)
├── AppDelegate.swift           — status item, global hotkey wiring, login item
├── HotKeyManager.swift         — Carbon Hot Key API registration (⌘⇧E)
├── PasteboardImageLoader.swift — resolves an image from the general pasteboard
├── EditorDocument.swift        — editing state machine: tools, selections, commits
├── LayerBitmap.swift           — pixel buffer backing the committed image
├── CanvasView.swift            — drawing + mouse/keyboard input for the canvas
├── EditorWindowController.swift— editor window, toolbar, layout
└── ToastWindow.swift           — lightweight transient notifications
```

For the domain vocabulary this codebase uses (Trigger, Source Image, Editing Session, Floating Selection, etc.), see [CONTEXT.md](CONTEXT.md). Notable design decisions are recorded under [docs/adr/](docs/adr/).

## Design notes

- No undo/redo, no persistence across sessions — an Editing Session is fully disposable.
- The global hotkey uses the Carbon Hot Key API, which requires no Accessibility/Input Monitoring permission ([ADR 0002](docs/adr/0002-carbon-hotkey-no-permission.md)).
- Clipboard output is PNG-only to preserve transparency left behind by the Move tool ([ADR 0001](docs/adr/0001-png-only-clipboard-output.md)).
