import AppKit
import SwiftUI

// MARK: - Draggable Desktop Clock Window
public final class DesktopClockWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        // Sits strictly BEHIND active applications on the desktop layer!
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.normalWindow)) - 1)
    }
    
    override public var canBecomeKey: Bool {
        return true
    }
    
    override public var canBecomeMain: Bool {
        return true
    }
    
    // Always report as key window so SwiftUI and macOS never dim the liquid glass when focusing away!
    override public var isKeyWindow: Bool {
        return true
    }
    
    override public var isMainWindow: Bool {
        return true
    }
    
    override public func resignKey() {
        // Intentionally no-op: remain key window permanently so liquid glass never disables
    }
    
    override public func resignMain() {
        // Intentionally no-op: remain main window permanently so liquid glass never disables
    }
}

// MARK: - Permanent Active Hosting View
public final class PermanentActiveHostingView<Content: View>: NSHostingView<Content> {
    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        enforceActiveVibrancy()
    }
    
    override public func layout() {
        super.layout()
        enforceActiveVibrancy()
    }
    
    public func enforceActiveVibrancy() {
        Self.recursivelyActivate(self)
    }
    
    public static func recursivelyActivate(_ view: NSView) {
        if let effect = view as? NSVisualEffectView {
            effect.state = .active
            effect.isEmphasized = true
        }
        for sub in view.subviews {
            recursivelyActivate(sub)
        }
    }
}

// MARK: - Desktop Window Manager
@MainActor
public final class DesktopWindowManager: NSObject {
    public static let shared = DesktopWindowManager()
    
    private var clockWindow: DesktopClockWindow?
    private var settingsWindow: NSWindow?
    
    private let settings = AppSettings.shared
    
    override private init() {
        super.init()
        setupCallbacks()
        setupNotificationObservers()
    }
    
    public func start() {
        setupAppIcon()
        createClockWindow()
    }
    
    private func setupAppIcon() {
        if let iconURL = Bundle.main.url(forResource: "logo", withExtension: "png") ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = image
        } else if let fallback = NSImage(contentsOfFile: "logo.png") {
            NSApplication.shared.applicationIconImage = fallback
        }
    }
    
    // MARK: - Clock Window Setup
    private func createClockWindow() {
        let initialRect = NSRect(x: 0, y: 0, width: 600, height: 350)
        let window = DesktopClockWindow(contentRect: initialRect)
        
        let clockView = ClockWidgetView(settings: settings, timeManager: TimeManager.shared)
            .environment(\.controlActiveState, .active)
            .padding(40) // Ensure soft ambient shadow is never clipped
        let hostingView = PermanentActiveHostingView(rootView: clockView)
        hostingView.frame = initialRect
        hostingView.autoresizingMask = [.width, .height]
        
        window.contentView = hostingView
        
        applyWindowLevel(settings.windowLevel, to: window)
        window.ignoresMouseEvents = settings.clickThrough
        
        // Auto-fit content size
        let fittingSize = hostingView.fittingSize
        window.setContentSize(fittingSize)
        
        // Position window dead-center on screen under camera notch
        centerWindow(window)
        
        window.orderFront(nil)
        self.clockWindow = window
    }
    
    public func updatePanelSize() {
        guard let window = self.clockWindow,
              let contentView = window.contentView else { return }
        
        let fittingSize = contentView.fittingSize
        
        if settings.isEditMode {
            // Keep window origin stationary in edit mode so resize handles never jump away from cursor
            let cur = window.frame
            window.setFrame(
                NSRect(
                    x: cur.origin.x,
                    y: cur.origin.y - (fittingSize.height - cur.height),
                    width: fittingSize.width,
                    height: fittingSize.height
                ),
                display: true,
                animate: false
            )
            return
        }
        
        let currentOrigin = window.frame.origin
        let oldSize = window.frame.size
        let newSize = fittingSize
        
        // Keep center point stationary when scaling outside edit mode
        let newX = currentOrigin.x + (oldSize.width - newSize.width) / 2
        let newY = currentOrigin.y + (oldSize.height - newSize.height) / 2
        
        window.setFrame(NSRect(origin: NSPoint(x: newX, y: newY), size: newSize), display: true, animate: false)
    }
    
    // MARK: - Center Window on Primary Screen
    public func centerWindow(_ windowToCenter: NSWindow? = nil) {
        guard let window = windowToCenter ?? self.clockWindow,
              let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let windowSize = window.frame.size
        
        // Exact horizontal screen center under the camera notch
        let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2.0
        // Upper center placement (matches lock screen elevation)
        let y = screenFrame.origin.y + (screenFrame.height * 0.52)
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
        settings.windowPositionX = Double(x)
        settings.windowPositionY = Double(y)
    }
    
    // MARK: - Window Level
    private func applyWindowLevel(_ levelOption: WindowLevelOption, to window: NSWindow) {
        if settings.isEditMode {
            // In Edit Mode, elevate so user can position widget cleanly without apps blocking
            window.level = .floating
            window.orderFrontRegardless()
            return
        }
        
        switch levelOption {
        case .desktop, .normal:
            // Sits strictly BEHIND all regular application windows on the desktop!
            window.level = NSWindow.Level(Int(CGWindowLevelForKey(.normalWindow)) - 1)
        case .floating:
            window.level = .floating
        }
        window.orderFront(nil)
    }
    
    // MARK: - Callbacks & Notifications
    private func setupCallbacks() {
        settings.onWindowLevelChanged = { [weak self] level in
            guard let self = self, let window = self.clockWindow else { return }
            self.applyWindowLevel(level, to: window)
        }
        
        settings.onEditModeChanged = { [weak self] isEdit in
            guard let self = self, let window = self.clockWindow else { return }
            self.applyWindowLevel(self.settings.windowLevel, to: window)
            window.isMovableByWindowBackground = isEdit
        }
        
        settings.onClickThroughChanged = { [weak self] clickThrough in
            guard let self = self, let window = self.clockWindow else { return }
            window.ignoresMouseEvents = clickThrough
        }
        
        settings.onCenterRequested = { [weak self] in
            self?.centerWindow()
        }
        
        settings.onLayoutChanged = { [weak self] in
            Task { @MainActor in
                self?.updatePanelSize()
            }
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenSettingsWindow"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openSettingsWindow()
            }
        }
        
        // Ensure that switching to other apps or other displays NEVER deactivates liquid glass
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let window = self.clockWindow else { return }
                if let view = window.contentView {
                    PermanentActiveHostingView<AnyView>.recursivelyActivate(view)
                }
                NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
            }
        }
    }
    
    // MARK: - Settings Window
    public func openSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Wizit Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
