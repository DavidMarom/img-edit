import AppKit

/// A brief, non-blocking message near the top of the screen. Used instead of
/// UNUserNotificationCenter so this app never needs to ask for any permission.
enum ToastWindow {
    private static var current: NSWindow?

    static func show(_ message: String) {
        current?.close()

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.sizeToFit()

        let padding: CGFloat = 14
        let size = CGSize(width: label.frame.width + padding * 2, height: label.frame.height + padding * 2)

        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let container = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        container.material = .hudWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true

        label.frame = CGRect(x: padding, y: padding, width: label.frame.width, height: label.frame.height)
        container.addSubview(label)
        panel.contentView = container

        if let screen = NSScreen.main {
            let origin = CGPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 40)
            panel.setFrameOrigin(origin)
        }

        panel.orderFrontRegardless()
        current = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            panel.animator().alphaValue = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                panel.close()
                if current === panel { current = nil }
            }
        }
    }
}
