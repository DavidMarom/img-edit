import AppKit

final class CanvasView: NSView {
    let document: EditorDocument
    var scale: CGFloat
    /// Fired whenever a mouse/keyboard interaction may have changed the document's
    /// selection state, so the toolbar can refresh things like Deselect's visibility.
    var onSelectionChanged: (() -> Void)?

    init(document: EditorDocument, scale: CGFloat) {
        self.document = document
        self.scale = scale
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("unsupported") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private func imagePoint(from viewPoint: NSPoint) -> CGPoint {
        CGPoint(x: viewPoint.x / scale, y: viewPoint.y / scale)
    }

    /// Image-space point of a mouseDown that landed outside the current selection.
    /// Left unresolved until the gesture turns out to be a plain click (deselect) or
    /// a click-drag (commit the old selection and start a new one from this point).
    private var pendingOutsideClickStart: CGPoint?

    // MARK: Mouse events

    override func mouseDown(with event: NSEvent) {
        let p = imagePoint(from: convert(event.locationInWindow, from: nil))
        if document.isOutsideSelection(at: p) {
            pendingOutsideClickStart = p
        } else {
            switch document.activeTool {
            case .move: document.moveMouseDown(at: p)
            case .crop: document.cropMouseDown(at: p)
            case .pen: document.penMouseDown(at: p)
            }
        }
        needsDisplay = true
        onSelectionChanged?()
    }

    override func mouseDragged(with event: NSEvent) {
        let p = imagePoint(from: convert(event.locationInWindow, from: nil))
        if let start = pendingOutsideClickStart {
            pendingOutsideClickStart = nil
            switch document.activeTool {
            case .move: document.moveMouseDown(at: start)
            case .crop: document.cropMouseDown(at: start)
            case .pen: document.penMouseDown(at: start)
            }
        }
        switch document.activeTool {
        case .move: document.moveMouseDragged(to: p)
        case .crop: document.cropMouseDragged(to: p)
        case .pen: document.penMouseDragged(to: p)
        }
        needsDisplay = true
        onSelectionChanged?()
    }

    override func mouseUp(with event: NSEvent) {
        let p = imagePoint(from: convert(event.locationInWindow, from: nil))
        if pendingOutsideClickStart != nil {
            pendingOutsideClickStart = nil
            document.deselect()
        } else {
            switch document.activeTool {
            case .move: document.moveMouseUp(at: p)
            case .crop: document.cropMouseUp(at: p)
            case .pen: document.penMouseUp(at: p)
            }
        }
        needsDisplay = true
        onSelectionChanged?()
    }

    // MARK: Keyboard: Enter commits, Escape cancels

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: // Return, Enter (keypad)
            document.commitPending()
            needsDisplay = true
            onSelectionChanged?()
        case 53: // Escape
            document.cancelPending()
            needsDisplay = true
            onSelectionChanged?()
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)

        drawBackground(in: ctx)
        drawMoveOverlay(in: ctx)
        drawCropOverlay(in: ctx)

        ctx.restoreGState()
    }

    /// Convert a top-left-origin image rect to a top-left-origin view rect (identity, since view is flipped).
    private func viewRect(_ imageRect: CGRect) -> CGRect { imageRect }

    private func drawBackground(in ctx: CGContext) {
        let bounds = CGRect(origin: .zero, size: document.committed.pixelSize)
        if case .floating(let piece, let origin, let base, _) = document.moveState {
            drawImageRightSideUp(base.cgImage, in: bounds, context: ctx)
            let pieceRect = CGRect(x: origin.x, y: origin.y, width: CGFloat(piece.width), height: CGFloat(piece.height))
            drawImageRightSideUp(piece, in: pieceRect, context: ctx)
        } else {
            drawImageRightSideUp(document.committed.cgImage, in: bounds, context: ctx)
        }
    }

    /// `CGContext.draw(_:in:)` always renders a CGImage right-side-up in a
    /// standard bottom-left-origin, y-up space. This view's context is
    /// flipped (isFlipped = true, y-down), so a plain `draw` call here would
    /// render images upside-down. Apply a local flip around the rect before
    /// drawing to compensate — this only affects image draws; rect fill/stroke
    /// used elsewhere for overlays needs no such correction.
    private func drawImageRightSideUp(_ image: CGImage, in rect: CGRect, context ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: rect.maxY + rect.minY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }

    private func drawMoveOverlay(in ctx: CGContext) {
        let rect: CGRect
        switch document.moveState {
        case .drawingSelection(let start, let current):
            rect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(start.x - current.x), height: abs(start.y - current.y))
        case .floating(let piece, let origin, _, _):
            rect = CGRect(x: origin.x, y: origin.y, width: CGFloat(piece.width), height: CGFloat(piece.height))
        case .idle:
            return
        }
        ctx.setStrokeColor(NSColor.systemGreen.cgColor)
        ctx.setLineDash(phase: 0, lengths: [4, 3])
        ctx.setLineWidth(1 / scale)
        ctx.stroke(rect)
    }

    private func drawCropOverlay(in ctx: CGContext) {
        let rect: CGRect
        switch document.cropState {
        case .drawingRect(let start, let current):
            rect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(start.x - current.x), height: abs(start.y - current.y))
        case .adjustable(let r, _):
            rect = r
        case .idle:
            return
        }

        let bounds = CGRect(origin: .zero, size: document.committed.pixelSize)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
        for dimRect in [
            CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: rect.minY - bounds.minY),
            CGRect(x: bounds.minX, y: rect.maxY, width: bounds.width, height: bounds.maxY - rect.maxY),
            CGRect(x: bounds.minX, y: rect.minY, width: rect.minX - bounds.minX, height: rect.height),
            CGRect(x: rect.maxX, y: rect.minY, width: bounds.maxX - rect.maxX, height: rect.height),
        ] where dimRect.width > 0 && dimRect.height > 0 {
            ctx.fill(dimRect)
        }

        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1 / scale)
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.stroke(rect)

        if case .adjustable = document.cropState {
            let handleSize: CGFloat = 8 / scale
            ctx.setFillColor(NSColor.white.cgColor)
            for corner in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)] {
                ctx.fill(CGRect(x: corner.x - handleSize / 2, y: corner.y - handleSize / 2, width: handleSize, height: handleSize))
            }
        }
    }
}
