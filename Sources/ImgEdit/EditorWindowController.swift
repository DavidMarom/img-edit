import AppKit

final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let editorDocument: EditorDocument
    private let canvasView: CanvasView
    private let toolbarHeight: CGFloat = 44
    var onClose: (() -> Void)?

    init(sourceImage: NSImage) {
        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            fatalError("Source Image has no backing CGImage")
        }
        let document = EditorDocument(bitmap: LayerBitmap(cgImage: cgImage))
        self.editorDocument = document

        let imageSize = document.committed.pixelSize
        let visible = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let maxSize = CGSize(width: visible.width * 0.8, height: visible.height * 0.8)
        let scale = min(1.0, min(maxSize.width / imageSize.width, maxSize.height / imageSize.height))
        let viewSize = CGSize(width: (imageSize.width * scale).rounded(), height: (imageSize.height * scale).rounded())

        let canvasView = CanvasView(document: document, scale: scale)
        canvasView.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: viewSize)
        self.canvasView = canvasView

        let contentSize = CGSize(width: viewSize.width, height: viewSize.height + toolbarHeight)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ImgEdit"
        window.isReleasedWhenClosed = false
        window.contentMinSize = CGSize(width: 200, height: 200 + toolbarHeight)
        window.center()

        super.init(window: window)
        window.delegate = self

        let contentView = FlippedContainerView(frame: CGRect(origin: .zero, size: contentSize))
        contentView.addSubview(canvasView)
        canvasView.frame = CGRect(x: 0, y: toolbarHeight, width: viewSize.width, height: viewSize.height)
        contentView.addSubview(makeToolbar(width: contentSize.width))
        window.contentView = contentView
    }

    required init?(coder: NSCoder) { fatalError("unsupported") }

    private func makeToolbar(width: CGFloat) -> NSView {
        let bar = NSVisualEffectView(frame: CGRect(x: 0, y: 0, width: width, height: toolbarHeight))
        bar.material = .titlebar
        bar.autoresizingMask = [.width]

        let segmented = NSSegmentedControl(labels: ["Move", "Crop"], trackingMode: .selectOne, target: self, action: #selector(toolChanged(_:)))
        segmented.selectedSegment = 0
        segmented.frame = CGRect(x: 12, y: (toolbarHeight - 24) / 2, width: 140, height: 24)

        let saveButton = NSButton(title: "Save to Clipboard", target: self, action: #selector(saveToClipboard))
        saveButton.bezelStyle = .rounded
        saveButton.frame = CGRect(x: width - 172, y: (toolbarHeight - 24) / 2, width: 160, height: 24)
        saveButton.autoresizingMask = [.minXMargin]

        bar.addSubview(segmented)
        bar.addSubview(saveButton)
        return bar
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(canvasView)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toolChanged(_ sender: NSSegmentedControl) {
        editorDocument.switchTool(sender.selectedSegment == 0 ? .move : .crop)
        canvasView.needsDisplay = true
    }

    @objc private func saveToClipboard() {
        editorDocument.commitPending()
        guard let data = editorDocument.committed.pngData() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(data, forType: .png)
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    /// Window is user-resizable independent of the image's own pixel size: whenever the
    /// content area changes, rescale the canvas to fit the space now available under the toolbar.
    func windowDidResize(_ notification: Notification) {
        guard let contentView = window?.contentView else { return }
        let imageSize = editorDocument.committed.pixelSize
        let available = CGSize(width: contentView.bounds.width, height: max(0, contentView.bounds.height - toolbarHeight))
        guard available.width > 0, available.height > 0 else { return }

        let scale = min(1.0, min(available.width / imageSize.width, available.height / imageSize.height))
        let viewSize = CGSize(width: (imageSize.width * scale).rounded(), height: (imageSize.height * scale).rounded())

        canvasView.scale = scale
        canvasView.frame = CGRect(x: 0, y: toolbarHeight, width: viewSize.width, height: viewSize.height)
        canvasView.needsDisplay = true
    }
}

/// Plain top-left-origin container so toolbar/canvas frame math below reads naturally.
private final class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}
