# Write PNG only when saving to clipboard

The Move tool can leave transparent holes in the image, so saved output must support an alpha channel. Rather than writing multiple pasteboard representations (e.g. PNG + TIFF, which `NSPasteboard` supports natively and some older/pickier apps prefer), we write PNG only. Simpler, and PNG with alpha is broadly understood by modern macOS paste targets. If a target app turns out to handle PNG-with-alpha poorly, revisit by adding a TIFF representation alongside it.
