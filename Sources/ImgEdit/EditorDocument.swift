import CoreGraphics

enum Tool {
    case move
    case crop
}

enum MoveState {
    case idle
    case drawingSelection(start: CGPoint, current: CGPoint)
    /// baseWithHole: committed image with the original selection rect punched transparent.
    /// currentOrigin: where the piece is currently drawn, top-left-origin pixel coords.
    case floating(piece: CGImage, currentOrigin: CGPoint, baseWithHole: LayerBitmap, dragAnchorOffset: CGPoint?)
}

enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

enum CropAdjust {
    case moveWhole(mouseStart: CGPoint, rectStart: CGRect)
    case resize(corner: Corner, fixedCorner: CGPoint)
}

enum CropState {
    case idle
    case drawingRect(start: CGPoint, current: CGPoint)
    case adjustable(rect: CGRect, activeDrag: CropAdjust?)
}

/// Owns the committed pixel state plus whatever the active tool has in flight
/// but not yet committed. Only one Editing Session's worth of state — no undo stack.
final class EditorDocument {
    private(set) var committed: LayerBitmap
    private(set) var activeTool: Tool = .move
    private(set) var moveState: MoveState = .idle
    private(set) var cropState: CropState = .idle

    init(bitmap: LayerBitmap) {
        committed = bitmap
    }

    private func imageBounds() -> CGRect {
        CGRect(origin: .zero, size: committed.pixelSize)
    }

    private func normalized(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
        // Round to integer pixel coords so the piece this rect is cut from starts out
        // pixel-aligned — a fractional origin forces resampling (blur) when it's later drawn.
        return rect.intersection(imageBounds()).integral
    }

    // MARK: Tool switching / global actions

    func switchTool(_ tool: Tool) {
        guard tool != activeTool else { return }
        commitPending()
        activeTool = tool
    }

    /// Bakes whichever tool has pending uncommitted state into `committed`.
    func commitPending() {
        if case .floating(let piece, let origin, let base, _) = moveState {
            base.draw(image: piece, at: origin)
            committed = base
        }
        moveState = .idle

        if case .adjustable(let rect, _) = cropState, rect.width >= 1, rect.height >= 1 {
            if let cropped = committed.croppedBitmap(to: rect) {
                committed = cropped
            }
        }
        cropState = .idle
    }

    func cancelPending() {
        moveState = .idle
        cropState = .idle
    }

    // MARK: Move tool

    func moveMouseDown(at point: CGPoint) {
        switch moveState {
        case .idle, .drawingSelection:
            moveState = .drawingSelection(start: point, current: point)
        case .floating(let piece, let origin, let base, _):
            let pieceRect = CGRect(origin: origin, size: CGSize(width: piece.width, height: piece.height))
            if pieceRect.contains(point) {
                moveState = .floating(piece: piece, currentOrigin: origin, baseWithHole: base, dragAnchorOffset: CGPoint(x: point.x - origin.x, y: point.y - origin.y))
            } else {
                // Starting a new selection elsewhere commits the current floating piece first.
                base.draw(image: piece, at: origin)
                committed = base
                moveState = .drawingSelection(start: point, current: point)
            }
        }
    }

    func moveMouseDragged(to point: CGPoint) {
        switch moveState {
        case .drawingSelection(let start, _):
            moveState = .drawingSelection(start: start, current: point)
        case .floating(let piece, _, let base, .some(let anchor)):
            // Snap to integer pixel coords: a fractional origin forces CoreGraphics to
            // resample the piece on every draw, blurring it (and baking that blur in on commit).
            let newOrigin = CGPoint(x: (point.x - anchor.x).rounded(), y: (point.y - anchor.y).rounded())
            moveState = .floating(piece: piece, currentOrigin: newOrigin, baseWithHole: base, dragAnchorOffset: anchor)
        case .floating, .idle:
            break
        }
    }

    func moveMouseUp(at point: CGPoint) {
        switch moveState {
        case .drawingSelection(let start, let current):
            let rect = normalized(start, current)
            if rect.width >= 1, rect.height >= 1, let piece = committed.subImage(rect: rect) {
                let base = committed.copy()
                base.clear(rect: rect)
                moveState = .floating(piece: piece, currentOrigin: rect.origin, baseWithHole: base, dragAnchorOffset: nil)
            } else {
                moveState = .idle
            }
        case .floating(let piece, let origin, let base, .some):
            moveState = .floating(piece: piece, currentOrigin: origin, baseWithHole: base, dragAnchorOffset: nil)
        case .floating, .idle:
            break
        }
    }

    // MARK: Crop tool

    private let handleRadius: CGFloat = 8

    private func corners(of rect: CGRect) -> [Corner: CGPoint] {
        [
            .topLeft: CGPoint(x: rect.minX, y: rect.minY),
            .topRight: CGPoint(x: rect.maxX, y: rect.minY),
            .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
            .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
        ]
    }

    func cropMouseDown(at point: CGPoint) {
        switch cropState {
        case .idle, .drawingRect:
            cropState = .drawingRect(start: point, current: point)
        case .adjustable(let rect, _):
            for (corner, cornerPoint) in corners(of: rect) {
                if hypot(cornerPoint.x - point.x, cornerPoint.y - point.y) <= handleRadius {
                    let opposite: Corner
                    switch corner {
                    case .topLeft: opposite = .bottomRight
                    case .topRight: opposite = .bottomLeft
                    case .bottomLeft: opposite = .topRight
                    case .bottomRight: opposite = .topLeft
                    }
                    cropState = .adjustable(rect: rect, activeDrag: .resize(corner: corner, fixedCorner: corners(of: rect)[opposite]!))
                    return
                }
            }
            if rect.contains(point) {
                cropState = .adjustable(rect: rect, activeDrag: .moveWhole(mouseStart: point, rectStart: rect))
            } else {
                if let cropped = committed.croppedBitmap(to: rect) {
                    committed = cropped
                }
                cropState = .drawingRect(start: point, current: point)
            }
        }
    }

    func cropMouseDragged(to point: CGPoint) {
        switch cropState {
        case .drawingRect(let start, _):
            cropState = .drawingRect(start: start, current: point)
        case .adjustable(_, .some(.moveWhole(let mouseStart, let rectStart))):
            var moved = rectStart.offsetBy(dx: point.x - mouseStart.x, dy: point.y - mouseStart.y)
            let bounds = imageBounds()
            if moved.minX < bounds.minX { moved.origin.x = bounds.minX }
            if moved.minY < bounds.minY { moved.origin.y = bounds.minY }
            if moved.maxX > bounds.maxX { moved.origin.x = bounds.maxX - moved.width }
            if moved.maxY > bounds.maxY { moved.origin.y = bounds.maxY - moved.height }
            cropState = .adjustable(rect: moved, activeDrag: .moveWhole(mouseStart: mouseStart, rectStart: rectStart))
        case .adjustable(_, .some(.resize(let corner, let fixedCorner))):
            let rect = normalized(fixedCorner, point)
            cropState = .adjustable(rect: rect, activeDrag: .resize(corner: corner, fixedCorner: fixedCorner))
        case .adjustable(let rect, nil):
            cropState = .adjustable(rect: rect, activeDrag: nil)
        case .idle:
            break
        }
    }

    func cropMouseUp(at point: CGPoint) {
        switch cropState {
        case .drawingRect(let start, let current):
            let rect = normalized(start, current)
            cropState = (rect.width >= 1 && rect.height >= 1) ? .adjustable(rect: rect, activeDrag: nil) : .idle
        case .adjustable(let rect, _):
            cropState = .adjustable(rect: rect, activeDrag: nil)
        case .idle:
            break
        }
    }
}
