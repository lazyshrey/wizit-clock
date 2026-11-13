import AppKit
import SwiftUI

// MARK: - Draggable Desktop Clock Window
public final class DesktopClockWindow: NSWindow {
    private var initialLocation: NSPoint = .zero
    
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
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
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
    
    override public func mouseDown(with event: NSEvent) {
        if AppSettings.shared.isEditMode {
            initialLocation = event.locationInWindow
            NSCursor.closedHand.push()
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override public func mouseDragged(with event: NSEvent) {
        guard AppSettings.shared.isEditMode && !AppSettings.shared.clickThrough else {
            super.mouseDragged(with: event)
            return
        }
        let currentLocation = event.locationInWindow
        var newOrigin = frame.origin
        newOrigin.x += (currentLocation.x - initialLocation.x)
        newOrigin.y += (currentLocation.y - initialLocation.y)
        setFrameOrigin(newOrigin)
    }
    
    override public func mouseUp(with event: NSEvent) {
        if AppSettings.shared.isEditMode {
            NSCursor.pop()
            AppSettings.shared.windowPositionX = Double(frame.origin.x)
            AppSettings.shared.windowPositionY = Double(frame.origin.y)
        } else {
            super.mouseUp(with: event)
        }
    }
}

// MARK: - Desktop Window Manager
@MainActor
public final class DesktopWindowManager: NSObject {
    public static let shared = DesktopWindowManager()
    
    private var clockWindow: DesktopClockWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    
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
        
        // Position window dead-center on screen under camera notch
        centerWindow(window)
        
        window.orderFront(nil)
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
        
        settings.onEditModeChanged = { [weak self] _ in
            guard let self = self, let window = self.clockWindow else { return }
            self.applyWindowLevel(self.settings.windowLevel, to: window)
            self.updateMenuBarState()
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
        window.title = "Wizit Settings"
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
        
        let titleItem = NSMenuItem(title: "Wizit Apple Lock Screen Clock", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 1. Edit / Move Mode
        let editItem = NSMenuItem(title: "✏️ Move & Resize Widget (Edit Mode)", action: #selector(menuToggleEditMode), keyEquivalent: "e")
        editItem.state = settings.isEditMode ? .on : .off
        menu.addItem(editItem)
        
        // 2. Snap to center
        menu.addItem(NSMenuItem(title: "🎯 Snap Dead Center (Under Notch)", action: #selector(menuSnapToCenter), keyEquivalent: "c"))
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Quick Size Submenu
        let sizeMenu = NSMenu()
        let sizes: [(String, Double)] = [
            ("Compact (70%)", 0.70),
            ("Standard Lock Screen (85%)", 0.85),
            ("Large (100%)", 1.00),
            ("Extra Large (115%)", 1.15)
        ]
        for (label, val) in sizes {
            let item = NSMenuItem(title: label, action: #selector(menuSelectScale(_:)), keyEquivalent: "")
            item.representedObject = val
            sizeMenu.addItem(item)
        }
        let sizeParent = NSMenuItem(title: "📏 Clock Size", action: nil, keyEquivalent: "")
        sizeParent.submenu = sizeMenu
        menu.addItem(sizeParent)
        
        // 4. Quick Liquid Glass Intensity Submenu
        let glassMenu = NSMenu()
        let intensities: [(String, Double)] = [
            ("Subtle Frosted Glass (50%)", 0.50),
            ("Apple Lock Screen Glass (85%)", 0.85),
            ("High Refraction Crystal (100%)", 1.00)
        ]
        for (label, val) in intensities {
            let item = NSMenuItem(title: label, action: #selector(menuSelectGlassIntensity(_:)), keyEquivalent: "")
            item.representedObject = val
            glassMenu.addItem(item)
        }
        let glassParent = NSMenuItem(title: "💧 Liquid Glass Intensity", action: nil, keyEquivalent: "")
        glassParent.submenu = glassMenu
        menu.addItem(glassParent)
        
        // 5. Presets submenu
        let presetsMenu = NSMenu()
        for preset in GlassPreset.allCases {
            let item = NSMenuItem(title: preset.rawValue, action: #selector(menuSelectPreset(_:)), keyEquivalent: "")
            item.representedObject = preset
            presetsMenu.addItem(item)
        }
        let presetsItem = NSMenuItem(title: "✨ Glass Presets", action: nil, keyEquivalent: "")
        presetsItem.submenu = presetsMenu
        menu.addItem(presetsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Window Layer
        let layerMenu = NSMenu()
        let desktopLayerItem = NSMenuItem(title: "Desktop (Behind All Apps)", action: #selector(menuSetDesktopLevel), keyEquivalent: "")
        desktopLayerItem.state = settings.windowLevel == .desktop ? .on : .off
        layerMenu.addItem(desktopLayerItem)
        
        let floatingLayerItem = NSMenuItem(title: "Always On Top (Floating)", action: #selector(menuSetFloatingLevel), keyEquivalent: "")
        floatingLayerItem.state = settings.windowLevel == .floating ? .on : .off
        layerMenu.addItem(floatingLayerItem)
        
        let layerParent = NSMenuItem(title: "🪟 Window Layer", action: nil, keyEquivalent: "")
        layerParent.submenu = layerMenu
        menu.addItem(layerParent)
        
        let lockItem = NSMenuItem(title: "🔒 Lock Position", action: #selector(menuToggleLock), keyEquivalent: "l")
        lockItem.state = settings.isLocked ? .on : .off
        menu.addItem(lockItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "⚙️ Settings & Appearance…", action: #selector(menuOpenSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Wizit", action: #selector(menuQuit), keyEquivalent: "q"))
        
        for item in menu.items {
            item.target = self
        }
        for item in sizeMenu.items { item.target = self }
        for item in glassMenu.items { item.target = self }
        for item in presetsMenu.items { item.target = self }
        for item in layerMenu.items { item.target = self }
        
        statusItem.menu = menu
        self.statusItem = statusItem
    }
    
    private func updateMenuBarState() {
        guard let menu = statusItem?.menu else { return }
        if let item = menu.item(withTitle: "✏️ Move & Resize Widget (Edit Mode)") {
            item.state = settings.isEditMode ? .on : .off
        }
    }
    
    @objc private func menuToggleEditMode() {
        withAnimation {
            settings.isEditMode.toggle()
        }
    }
    
    @objc private func menuOpenSettings() {
        openSettingsWindow()
    }
    
    @objc private func menuSnapToCenter() {
        centerWindow()
    }
    
    @objc private func menuSelectScale(_ sender: NSMenuItem) {
        if let scale = sender.representedObject as? Double {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.clockScale = scale
            }
        }
    }
    
    @objc private func menuSelectGlassIntensity(_ sender: NSMenuItem) {
        if let intensity = sender.representedObject as? Double {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.liquidGlassIntensity = intensity
            }
        }
    }
    
    @objc private func menuSelectPreset(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? GlassPreset {
            withAnimation(.easeInOut(duration: 0.25)) {
                settings.applyPreset(preset)
            }
        }
    }
    
    @objc private func menuSetDesktopLevel() {
        settings.windowLevel = .desktop
    }
    
    @objc private func menuSetFloatingLevel() {
        settings.windowLevel = .floating
    }
    
    @objc private func menuToggleLock() {
        settings.isLocked.toggle()
        if let menu = statusItem?.menu, let item = menu.item(withTitle: "🔒 Lock Position") {
            item.state = settings.isLocked ? .on : .off
        }
    }
    
    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }
}
