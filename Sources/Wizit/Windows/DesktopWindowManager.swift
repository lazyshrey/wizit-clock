import AppKit
import SwiftUI

// MARK: - Draggable Desktop Clock Panel
public final class DesktopClockPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
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
    
    private var clockPanel: DesktopClockPanel?
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
        createClockPanel()
        setupMenuBar()
    }
    
    // MARK: - Smooth Dragging Engine
    public func startDrag() {
        guard let panel = clockPanel else { return }
        dragStartOrigin = panel.frame.origin
    }
    
    public func drag(by translation: CGSize) {
        guard let panel = clockPanel, let startOrigin = dragStartOrigin else { return }
        // macOS AppKit origin is bottom-left, so y decreases when moving down
        let newX = startOrigin.x + translation.width
        let newY = startOrigin.y - translation.height
        let newOrigin = NSPoint(x: newX, y: newY)
        
        panel.setFrameOrigin(newOrigin)
        settings.windowPositionX = Double(newX)
        settings.windowPositionY = Double(newY)
    }
    
    public func endDrag() {
        dragStartOrigin = nil
    }
    
    // MARK: - Clock Panel Setup
    private func createClockPanel() {
        let initialRect = NSRect(x: 0, y: 0, width: 600, height: 350)
        let panel = DesktopClockPanel(contentRect: initialRect)
        
        let clockView = ClockWidgetView(settings: settings, timeManager: TimeManager.shared)
            .padding(40) // Ensure soft ambient shadow is never clipped
        let hostingView = NSHostingView(rootView: clockView)
        hostingView.frame = initialRect
        hostingView.autoresizingMask = [.width, .height]
        
        panel.contentView = hostingView
        
        applyWindowLevel(settings.windowLevel, to: panel)
        panel.ignoresMouseEvents = settings.clickThrough
        
        // Auto-fit content size
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(fittingSize)
        
        // Position panel: either saved position or centered
        if settings.windowPositionX != 0 && settings.windowPositionY != 0 {
            panel.setFrameOrigin(NSPoint(x: settings.windowPositionX, y: settings.windowPositionY))
        } else {
            centerPanel(panel)
        }
        
        panel.orderFront(nil)
        self.clockPanel = panel
    }
    
    public func updatePanelSize() {
        guard let panel = self.clockPanel,
              let contentView = panel.contentView else { return }
        
        let currentOrigin = panel.frame.origin
        let oldSize = panel.frame.size
        let newSize = contentView.fittingSize
        
        // Keep center point stationary when scaling
        let newX = currentOrigin.x + (oldSize.width - newSize.width) / 2
        let newY = currentOrigin.y + (oldSize.height - newSize.height) / 2
        
        panel.setFrame(NSRect(origin: NSPoint(x: newX, y: newY), size: newSize), display: true, animate: false)
    }
    
    // MARK: - Center Panel on Primary Screen
    public func centerPanel(_ panelToCenter: NSPanel? = nil) {
        guard let panel = panelToCenter ?? self.clockPanel,
              let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let panelSize = panel.frame.size
        
        // Center horizontally; place in the golden center (upper portion like macOS lock screen)
        let x = screenRect.origin.x + (screenRect.width - panelSize.width) / 2.0
        let y = screenRect.origin.y + (screenRect.height - panelSize.height) * 0.60
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        settings.windowPositionX = Double(x)
        settings.windowPositionY = Double(y)
    }
    
    // MARK: - Window Level
    private func applyWindowLevel(_ levelOption: WindowLevelOption, to panel: NSPanel) {
        switch levelOption {
        case .normal:
            panel.level = .normal
        case .desktop:
            panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        case .floating:
            panel.level = .floating
        }
    }
    
    // MARK: - Callbacks & Notifications
    private func setupCallbacks() {
        settings.onWindowLevelChanged = { [weak self] level in
            guard let self = self, let panel = self.clockPanel else { return }
            self.applyWindowLevel(level, to: panel)
        }
        
        settings.onClickThroughChanged = { [weak self] clickThrough in
            guard let self = self, let panel = self.clockPanel else { return }
            panel.ignoresMouseEvents = clickThrough
        }
        
        settings.onCenterRequested = { [weak self] in
            self?.centerPanel()
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
        centerPanel()
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
