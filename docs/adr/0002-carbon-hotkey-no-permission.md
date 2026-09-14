# Global hotkey needs no Accessibility permission

We originally planned a first-launch flow that checks for and requests Accessibility/Input Monitoring permission before the global hotkey would work, assuming that's required for any global hotkey on macOS. It isn't: the Carbon Hot Key API (`RegisterEventHotKey`), which `HotKeyManager` uses, is a permission-free mechanism — that permission class is only needed for simulating input or reading other apps' windows, neither of which this app does. So there's no permission gate at all; the hotkey just works once registered.
