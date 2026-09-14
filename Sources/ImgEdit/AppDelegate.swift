import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKeyManager = HotKeyManager()
    private var editorWindowController: EditorWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        hotKeyManager.onTrigger = { [weak self] in self?.trigger() }
        hotKeyManager.register()
        registerAsLoginItemIfNeeded()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "crop", accessibilityDescription: "ImgEdit")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func registerAsLoginItemIfNeeded() {
        guard SMAppService.mainApp.status != .enabled else { return }
        try? SMAppService.mainApp.register()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func trigger() {
        if let controller = editorWindowController, controller.window?.isVisible == true {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let image = PasteboardImageLoader.loadSourceImage() else {
            ToastWindow.show("No image found on the clipboard")
            return
        }

        let controller = EditorWindowController(sourceImage: image)
        controller.onClose = { [weak self] in self?.editorWindowController = nil }
        editorWindowController = controller
        controller.showWindow()
    }
}
