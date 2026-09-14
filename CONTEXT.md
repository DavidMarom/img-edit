# Photo Editor

A macOS menu-bar utility for quick, file-free image touch-ups: grab whatever image is on the clipboard, reposition or crop it with exactly two tools, and push the result back to the clipboard. No library, no saved files, no persistence across sessions, no filters or adjustments.

## Language

**Trigger**:
The fixed global hotkey press that invokes the app and starts an Editing Session by reading the current pasteboard.
_Avoid_: Launch, activation

**Source Image**:
The image loaded into an Editing Session at Trigger time. Resolved from the system pasteboard, either from raw image data (PNG/TIFF/JPEG) or by reading a file-reference (`public.file-url`) found on the pasteboard.
_Avoid_: Input image, original

**Editing Session**:
The lifetime of one open editing window, from Trigger until the user saves to clipboard or dismisses it. Holds exactly one Source Image. Nothing about a session persists once it ends, and there is no undo/redo across committed actions. At most one Editing Session can be open at a time — a Trigger while one is already open just focuses that window rather than starting a new one or replacing its Source Image. Closing the window without saving leaves the clipboard exactly as it was before the Trigger.
_Avoid_: Project, document

**Move Tool**:
One of the two tools. Lets the user drag out a rectangular selection on the image, which becomes a Floating Selection that can be repositioned before being committed.
_Avoid_: Select tool, marquee

**Crop Tool**:
The other of the two tools. Lets the user drag out a rectangle defining new canvas bounds, committed the same way as a Floating Selection (Enter to commit, Escape to cancel). Only one tool is active at a time.
_Avoid_: Trim

**Floating Selection**:
The rectangular piece of the image picked up by the Move Tool, mid-drag and not yet committed. Committing it (Enter, starting a new selection, switching tools, or saving) bakes it into its new position and leaves its original spot transparent. Escape cancels it, snapping it back with no transparency left behind.
_Avoid_: Floating layer (implies a persistent layer stack, which this app doesn't have)

## Example dialogue

> **Dev**: What happens if the pasteboard is empty when the user hits the hotkey?
> **Domain expert**: There's no Source Image to load, so no Editing Session starts — the user just gets a quick notification instead of a window.
> **Dev**: And if they copied a PNG file in Finder instead of copying pixels from an app?
> **Domain expert**: Still counts — we resolve the file-reference on the pasteboard into a Source Image the same way as raw image data.
> **Dev**: If I drag a Floating Selection somewhere and then start a new selection with the Move Tool, what happens to the first one?
> **Domain expert**: It commits automatically — starting a new selection is one of the actions that bakes the current Floating Selection in. You can do several moves in a row that way.
> **Dev**: Can I undo a move after it's committed?
> **Domain expert**: No — once it's committed there's no undo. Escape only helps before you commit.
