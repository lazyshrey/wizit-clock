import AppKit
import SwiftUI

// MARK: - Draggable Desktop Clock Window (Standard NSWindow, NOT a floating panel)
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
        self.isMovableByWindowBackground = true // Native drag support
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.acceptsMouseMovedEvents = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
    }
    
    override public var canBecomeKey: Bool {
        return false
    }
    
    override public var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Desktop Window Manager
@MainActor
public final class DesktopWindowManager: NSObject {
    public static let shared = DesktopWindowManager()
    
    private var clockWindow: DesktopClockWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    
    private var dragStartOrigin: NSPoint?
    
    private let settings = AppSettings.shared
    
    override private init() {
        super.init()
        setupCallbacks()
        setupNotificationObservers()
    }
    
    public func start() {
        createClockWindow()
        setupMenuBar()
    }
    
    // MARK: - Smooth Dragging Engine
    public func startDrag() {
        guard let window = clockWindow else { return }
        dragStartOrigin = window.frame.origin
    }
    
    public func drag(by translation: CGSize) {
        guard let window = clockWindow, let startOrigin = dragStartOrigin else { return }
        // macOS AppKit origin is bottom-left, so y decreases when moving down
        let newX = startOrigin.x + translation.width
        let newY = startOrigin.y - translation.height
        let newOrigin = NSPoint(x: newX, y: newY)
        
        window.setFrameOrigin(newOrigin)
        settings.windowPositionX = Double(newX)
        settings.windowPositionY = Double(newY)
    }
    
    public func endDrag() {
        dragStartOrigin = nil
    }
    
    // MARK: - Clock Window Setup
    private func createClockWindow() {
        let initialRect = NSRect(x: 0, y: 0, width: 600, height: 350)
        let window = DesktopClockWindow(contentRect: initialRect)
        
        let clockView = ClockWidgetView(settings: settings, timeManager: TimeManager.shared)
            .padding(40) // Ensure soft ambient shadow is never clipped
        let hostingView = NSHostingView(rootView: clockView)
        hostingView.frame = initialRect
        hostingView.autoresizingMask = [.width, .height]
        
        window.contentView = hostingView
        
        applyWindowLevel(settings.windowLevel, to: window)
        window.ignoresMouseEvents = settings.clickThrough
        
        // Auto-fit content size
        let fittingSize = hostingView.fittingSize
        window.setContentSize(fittingSize)
        
        // Position window dead-center on screen
        centerWindow(window)
        
        if settings.windowLevel == .floating {
            window.orderFront(nil)
        } else {
            window.orderBack(nil)
        }
        
        self.clockWindow = window
    }
    
    public func updatePanelSize() {
        guard let window = self.clockWindow,
              let contentView = window.contentView else { return }
        
        let currentOrigin = window.frame.origin
        let oldSize = window.frame.size
        let newSize = contentView.fittingSize
        
        // Keep center point stationary when scaling
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
        // Upper center placement
        let y = screenFrame.origin.y + (screenFrame.height * 0.52)
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
        settings.windowPositionX = Double(x)
        settings.windowPositionY = Double(y)
    }
    
    // MARK: - Window Level
    private func applyWindowLevel(_ levelOption: WindowLevelOption, to window: NSWindow) {
        switch levelOption {
        case .desktop:
            // Pinned directly to the desktop wallpaper behind all app windows
            window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.orderBack(nil)
        case .normal:
            // Sits below all standard active app windows
            window.level = NSWindow.Level(Int(CGWindowLevelForKey(.normalWindow)) - 1)
            window.orderBack(nil)
        case .floating:
            // Only if user explicitly requests it to stay on top
            window.level = .floating
            window.orderFront(nil)
        }
    }
    
    // MARK: - Callbacks & Notifications
    private func setupCallbacks() {
        settings.onWindowLevelChanged = { [weak self] level in
            guard let self = self, let window = self.clockWindow else { return }
            self.applyWindowLevel(level, to: window)
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
        window.title = "Wizit Clock Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Menu Bar Item
    private func setupMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock.badge.sparkles", accessibilityDescription: "Wizit")
        }
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "Wizit Glass Clock", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Settings & Appearance…", action: #selector(menuOpenSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Snap to Screen Center", action: #selector(menuSnapToCenter), keyEquivalent: "c"))
        
        // Presets submenu
        let presetsMenu = NSMenu()
        for preset in GlassPreset.allCases {
            let item = NSMenuItem(title: preset.rawValue, action: #selector(menuSelectPreset(_:)), keyEquivalent: "")
            item.representedObject = preset
            presetsMenu.addItem(item)
        }
        let presetsItem = NSMenuItem(title: "Glass Presets", action: nil, keyEquivalent: "")
        presetsItem.submenu = presetsMenu
        menu.addItem(presetsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let lockItem = NSMenuItem(title: "Lock Position", action: #selector(menuToggleLock), keyEquivalent: "l")
        lockItem.state = settings.isLocked ? .on : .off
        menu.addItem(lockItem)
        
        let clickThroughItem = NSMenuItem(title: "Click-Through Mode", action: #selector(menuToggleClickThrough), keyEquivalent: "")
        clickThroughItem.state = settings.clickThrough ? .on : .off
        menu.addItem(clickThroughItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit Wizit", action: #selector(menuQuit), keyEquivalent: "q"))
        
        for item in menu.items {
            item.target = self
        }
        
        statusItem.menu = menu
        self.statusItem = statusItem
    }
    
    @objc private func menuOpenSettings() {
        openSettingsWindow()
    }
    
    @objc private func menuSnapToCenter() {
        centerWindow()
    }
    
    @objc private func menuSelectPreset(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? GlassPreset {
            withAnimation(.easeInOut(duration: 0.25)) {
                settings.applyPreset(preset)
            }
        }
    }
    
    @objc private func menuToggleLock() {
        settings.isLocked.toggle()
        if let menu = statusItem?.menu, let item = menu.item(withTitle: "Lock Position") {
            item.state = settings.isLocked ? .on : .off
        }
    }
    
    @objc private func menuToggleClickThrough() {
        settings.clickThrough.toggle()
        if let menu = statusItem?.menu, let item = menu.item(withTitle: "Click-Through Mode") {
            item.state = settings.clickThrough ? .on : .off
        }
    }
    
    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }
}
