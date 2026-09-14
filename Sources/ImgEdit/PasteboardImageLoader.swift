import AppKit
import UniformTypeIdentifiers

enum PasteboardImageLoader {
    /// Resolves a Source Image from the general pasteboard: prefers a file-reference
    /// that points at a readable image file (how Finder puts a copied file on the
    /// pasteboard), falling back to raw image data (PNG/TIFF/JPEG).
    static func loadSourceImage() -> NSImage? {
        let pb = NSPasteboard.general

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]) as? [URL],
           let url = urls.first,
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let image = NSImage(pasteboard: pb) {
            return image
        }

        return nil
    }
}
