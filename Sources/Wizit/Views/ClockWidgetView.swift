import SwiftUI

public struct ClockWidgetView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var timeManager: TimeManager
    
    @State private var pinchBaseScale: Double?
    @State private var dragInitialWindowOrigin: CGPoint? = nil
    @State private var dragStartMouseLocation: CGPoint? = nil
    @State private var dragAnchorTop: CGFloat? = nil
    @State private var dragAnchorLeft: CGFloat? = nil
    @State private var dragStartScale: Double? = nil
    @State private var dragStartHeightRatio: Double? = nil
    
    public init(settings: AppSettings = .shared, timeManager: TimeManager = .shared) {
        self.settings = settings
        self.timeManager = timeManager
    }
    
    public var body: some View {
        let baseScale = settings.clockScale
        let digitSize: CGFloat = (settings.displayMode == .lockScreen ? 92 : 72) * baseScale
        let pmWidth: CGFloat = (!settings.is24Hour && settings.showAmPm) ? 44 * baseScale : 0
        
        ZStack(alignment: .top) {
            // Optional Card background (if user explicitly chooses Card mode)
            if settings.displayMode == .card {
                LiquidGlassSurface(settings: settings)
            }
            
            // Content
            VStack(spacing: settings.isEditMode ? 6 * baseScale : (settings.timeLayout == .stacked ? -8 * baseScale : -2 * baseScale)) {
                // 1. Date Header (Mathematically Centered above digits, tight lock-screen spacing)
                if settings.showDate {
                    dateHeaderView(baseScale: baseScale)
                        .padding(.horizontal, settings.isEditMode ? 14 * baseScale : 0)
                        .padding(.vertical, settings.isEditMode ? 5 * baseScale : 0)
                        .background(
                            Group {
                                if settings.isEditMode {
                                    RoundedRectangle(cornerRadius: 12 * baseScale, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12 * baseScale, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.2)
                                        )
                                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 2)
                                }
                            }
                        )
                }
                
                // 2. Time Digits (Hours : Minutes + PM)
                timeDigitsView(digitSize: digitSize, pmWidth: pmWidth, baseScale: baseScale)
                    .padding(.horizontal, settings.isEditMode ? 24 * baseScale : 0)
                    .padding(.top, settings.isEditMode ? 14 * baseScale : 0)
                    .padding(.bottom, settings.isEditMode ? 10 * baseScale : 0)
                    .background(
                        Group {
                            if settings.isEditMode {
                                RoundedRectangle(cornerRadius: 18 * baseScale, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18 * baseScale, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.2)
                                    )
                                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
                                    .overlay(alignment: .topTrailing) {
                                        EditModeDoneButton(baseScale: baseScale) {
                                            withAnimation(.snappy) {
                                                settings.isEditMode = false
                                            }
                                        }
                                        .padding(.top, 8 * baseScale)
                                        .padding(.trailing, 10 * baseScale)
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        appleCornerResizeHandle(baseScale: baseScale, cornerRadius: 18 * baseScale)
                                    }
                            }
                        }
                    )
            }
            .padding(.horizontal, settings.displayMode == .card ? 32 * baseScale : 20 * baseScale)
            .padding(.vertical, settings.displayMode == .card ? 22 * baseScale : 14 * baseScale)
            .contentShape(Rectangle())
            .gesture(
                settings.isEditMode ?
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { _ in
                            if settings.isResizing { return }
                            guard let window = NSApp.windows.first(where: { $0 is DesktopClockWindow }) else { return }
                            let mouse = NSEvent.mouseLocation
                            if dragInitialWindowOrigin == nil {
                                dragInitialWindowOrigin = window.frame.origin
                                dragStartMouseLocation = mouse
                                NSCursor.closedHand.push()
                            }
                            guard let initial = dragInitialWindowOrigin,
                                  let startMouse = dragStartMouseLocation else { return }
                            
                            let rawX = initial.x + mouse.x - startMouse.x
                            let rawY = initial.y + mouse.y - startMouse.y
                            
                            // Find current screen for multi-monitor support
                            let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
                                ?? window.screen
                                ?? NSScreen.main
                                ?? NSScreen.screens[0]
                            let screenFrame = screen.frame
                            
                            // Clamp all 4 borders so widget cannot be dragged outside the display view
                            let minX = screenFrame.minX - 20
                            let maxX = max(minX, screenFrame.maxX - window.frame.width + 20)
                            let minY = screenFrame.minY - 20
                            let maxY = max(minY, screenFrame.maxY - window.frame.height)
                            
                            let clampedX = min(maxX, max(minX, rawX))
                            let clampedY = min(maxY, max(minY, rawY))
                            let newOrigin = CGPoint(x: clampedX.rounded(), y: clampedY.rounded())
                            
                            if newOrigin != window.frame.origin {
                                window.setFrameOrigin(newOrigin)
                            }
                        }
                        .onEnded { _ in
                            if settings.isResizing { return }
                            NSCursor.pop()
                            if let window = NSApp.windows.first(where: { $0 is DesktopClockWindow }) {
                                settings.windowPositionX = Double(window.frame.origin.x)
                                settings.windowPositionY = Double(window.frame.origin.y)
                                UserDefaults.standard.synchronize()
                            }
                            dragInitialWindowOrigin = nil
                            dragStartMouseLocation = nil
                        }
                : nil
            )
        }
        .fixedSize()
        .onHover { hovering in
            if settings.isEditMode {
                if hovering {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .environment(\.controlActiveState, .active)
        // Trackpad pinch-to-resize gesture
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    if pinchBaseScale == nil {
                        pinchBaseScale = settings.clockScale
                    }
                    if let startScale = pinchBaseScale {
                        let newScale = min(1.6, max(0.45, startScale * scale))
                        settings.clockScale = newScale
                    }
                }
                .onEnded { _ in
                    pinchBaseScale = nil
                }
        )
        .contextMenu {
            widgetContextMenu
        }
        // Center inside this view rather than leaving it to the hosting view, so that when the
        // time gets wider or narrower the re-centering animates together with the digits
        // instead of jumping. Sizing is unaffected: the ideal size is still the content's.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(GlyphixCurve.layout, value: timeAnimationKey)
    }
    
    // MARK: - Time Digits View Helper
    @ViewBuilder
    private func timeDigitsView(digitSize: CGFloat, pmWidth: CGFloat, baseScale: Double) -> some View {
        if settings.timeLayout == .stacked {
            stackedTimeView(digitSize: digitSize, baseScale: baseScale)
        } else {
            horizontalTimeView(digitSize: digitSize, pmWidth: pmWidth, baseScale: baseScale)
        }
    }
    
    // MARK: - Apple Lock Screen Corner Resize Handle
    @ViewBuilder
    private func appleCornerResizeHandle(baseScale: Double, cornerRadius: CGFloat) -> some View {
        let handleRadius = cornerRadius
        let strokeWidth = max(4.0, 5.0 * baseScale)
        
        ZStack {
            // Generous touch hit-box for easy grabbing
            Color.clear
                .frame(width: max(38, handleRadius * 1.8), height: max(38, handleRadius * 1.8))
                .contentShape(Rectangle())
            
            // Outer depth shadow
            AppleCornerArc(radius: handleRadius)
                .stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: strokeWidth + 2, lineCap: .round))
                .blur(radius: 1.5)
            
            // Native Apple translucent frosted glass arc handle
            AppleCornerArc(radius: handleRadius)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
        }
        .frame(width: handleRadius * 2, height: handleRadius * 2)
        .onHover { hovering in
            if hovering {
                NSCursor.crosshair.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    guard let window = NSApp.windows.first(where: { $0 is DesktopClockWindow }) else { return }
                    
                    if dragAnchorTop == nil {
                        dragAnchorTop = window.frame.origin.y + window.frame.height
                        dragAnchorLeft = window.frame.origin.x
                        dragStartScale = settings.clockScale
                        dragStartHeightRatio = settings.clockHeightRatio
                        dragStartMouseLocation = NSEvent.mouseLocation
                        settings.isResizing = true
                    }
                    
                    guard let startScale = dragStartScale,
                          let startHeight = dragStartHeightRatio,
                          let anchorTop = dragAnchorTop,
                          let anchorLeft = dragAnchorLeft else { return }
                    
                    // 1. Horizontal movement expands overall size (Scale)
                    let scaleDelta = Double(value.translation.width) / 260.0
                    let newScale = min(1.65, max(0.45, startScale + scaleDelta))
                    settings.clockScale = newScale
                    
                    // 2. Vertical movement expands height ratio (Stretch / Condense)
                    let heightDelta = Double(value.translation.height) / 160.0
                    let newHeight = min(1.85, max(0.65, startHeight + heightDelta))
                    settings.clockHeightRatio = newHeight
                    
                    // LIVE ANCHORED WINDOW RESIZE: Keeps top-left fixed, expands towards cursor!
                    DesktopWindowManager.shared.updatePanelSizeAnchored(anchorLeft: anchorLeft, anchorTop: anchorTop)
                }
                .onEnded { _ in
                    if let anchorTop = dragAnchorTop, let anchorLeft = dragAnchorLeft {
                        DesktopWindowManager.shared.updatePanelSizeAnchored(anchorLeft: anchorLeft, anchorTop: anchorTop)
                    }
                    dragAnchorTop = nil
                    dragAnchorLeft = nil
                    dragStartScale = nil
                    dragStartHeightRatio = nil
                    dragStartMouseLocation = nil
                    settings.isResizing = false
                    settings.onLayoutChanged?()
                    if let window = NSApp.windows.first(where: { $0 is DesktopClockWindow }) {
                        settings.windowPositionX = Double(window.frame.origin.x)
                        settings.windowPositionY = Double(window.frame.origin.y)
                    }
                    UserDefaults.standard.synchronize()
                }
        )
    }
    
    // MARK: - Date Header (Format: Sat, Nov 14 in Bold Liquid Glass, No Calendar Icon, Tight Spacing)
    @ViewBuilder
    private func dateHeaderView(baseScale: Double) -> some View {
        LiquidGlassText(
            timeManager.dateFormattedString,
            fontSize: 21 * baseScale,
            weight: .bold,
            design: settings.fontDesign,
            settings: settings
        )
    }
    
    // MARK: - Animated Digits
    /// Changes whenever anything that can resize the clock's content ticks over. Layout changes
    /// in that update (slot widths, re-centering, the PM label sliding) share one spring.
    private var timeAnimationKey: String {
        [
            timeManager.hoursString,
            timeManager.minutesString,
            settings.showSeconds ? timeManager.secondsString : "",
            timeManager.amPmString,
            timeManager.dateFormattedString
        ].joined(separator: "|")
    }

    private func animatedDigits(
        _ text: String,
        digitSize: CGFloat,
        weight: Font.Weight,
        heightRatio: Double,
        colonSpacing: CGFloat = 0,
        minimumSlots: Int = 0,
        baseDelay: TimeInterval = 0
    ) -> some View {
        GlyphixGlassText(
            text: text,
            fontSize: digitSize,
            weight: weight,
            heightRatio: heightRatio,
            colonSpacing: colonSpacing,
            minimumSlots: minimumSlots,
            baseDelay: baseDelay,
            settings: settings
        )
    }

    // MARK: - Horizontal Time View (Symmetrically Balanced so 10:46 is Dead Center)
    @ViewBuilder
    private func horizontalTimeView(digitSize: CGFloat, pmWidth: CGFloat, baseScale: Double) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Left invisible balance spacer matching PM width (keeps digits dead center under notch!)
            if pmWidth > 0 {
                Color.clear
                    .frame(width: pmWidth, height: 1)
            }
            
            // Core Digits: "HH:MM" (5 slots, so a 1-digit hour leaves the leading one empty)
            animatedDigits(
                "\(timeManager.hoursString):\(timeManager.minutesString)",
                digitSize: digitSize,
                weight: settings.fontWeight.weight,
                heightRatio: settings.clockHeightRatio,
                colonSpacing: 6 * baseScale,
                minimumSlots: 5
            )
            
            // Trailing: PM & optional seconds
            if pmWidth > 0 || settings.showSeconds {
                VStack(alignment: .leading, spacing: 2 * baseScale) {
                    if !settings.is24Hour && settings.showAmPm && !timeManager.amPmString.isEmpty {
                        LiquidGlassText(
                            timeManager.amPmString,
                            fontSize: 21 * baseScale,
                            weight: .bold,
                            design: settings.fontDesign,
                            heightRatio: 1.0,
                            settings: settings
                        )
                        .padding(.leading, 6 * baseScale)
                        .padding(.bottom, 14 * baseScale)
                    }
                    
                    if settings.showSeconds {
                        animatedDigits(
                            timeManager.secondsString,
                            digitSize: 20 * baseScale,
                            weight: .semibold,
                            heightRatio: 1.0
                        )
                        .padding(.leading, 6 * baseScale)
                        .padding(.bottom, 14 * baseScale)
                    }
                }
                .frame(width: pmWidth, alignment: .leading)
            }
        }
    }
    
    // MARK: - Stacked Time View
    @ViewBuilder
    private func stackedTimeView(digitSize: CGFloat, baseScale: Double) -> some View {
        VStack(spacing: -14 * baseScale) {
            // Hours start after both minute digits, so a rollover still carries right-to-left
            animatedDigits(
                timeManager.hoursString,
                digitSize: digitSize * 0.95,
                weight: settings.fontWeight.weight,
                heightRatio: settings.clockHeightRatio,
                minimumSlots: 2,
                baseDelay: 2 * GlyphixCurve.stagger(settings)
            )

            animatedDigits(
                timeManager.minutesString,
                digitSize: digitSize * 0.95,
                weight: settings.fontWeight.weight,
                heightRatio: settings.clockHeightRatio
            )
        }
    }
    
    // MARK: - Right-Click Context Menu
    @ViewBuilder
    private var widgetContextMenu: some View {
        Button {
            withAnimation {
                settings.isEditMode.toggle()
            }
        } label: {
            Label(
                settings.isEditMode ? "Lock Clock Position" : "Unlock to Move Clock",
                systemImage: settings.isEditMode ? "lock.fill" : "arrow.up.and.down.and.arrow.left.and.right"
            )
        }
        
        Button {
            settings.onCenterRequested?()
        } label: {
            Label("Snap to Center (Under Camera Notch)", systemImage: "viewfinder")
        }
        
        Divider()
        
        Menu("Clock Style") {
            ForEach(LockScreenClockStyle.allCases) { style in
                Button(settings.clockStyle == style ? "✓ \(style.rawValue)" : style.rawValue) {
                    withAnimation(.snappy) {
                        settings.applyClockStyle(style)
                    }
                }
            }
        }
        
        Menu("Font Typography") {
            ForEach(ClockFontDesign.allCases) { design in
                Button(settings.fontDesign == design ? "✓ \(design.rawValue)" : design.rawValue) {
                    withAnimation(.snappy) {
                        settings.fontDesign = design
                    }
                }
            }
        }
        
        Menu("Time Layout") {
            Button(settings.timeLayout == .horizontal ? "✓ Inline (Horizontal)" : "Inline (Horizontal)") {
                withAnimation(.snappy) { settings.timeLayout = .horizontal }
            }
            Button(settings.timeLayout == .stacked ? "✓ Stacked (Dual-Line)" : "Stacked (Dual-Line)") {
                withAnimation(.snappy) { settings.timeLayout = .stacked }
            }
        }
        
        Menu("Numeral System") {
            ForEach(NumeralSystem.allCases) { sys in
                Button(settings.numeralSystem == sys ? "✓ \(sys.rawValue)" : sys.rawValue) {
                    withAnimation(.snappy) { settings.numeralSystem = sys }
                }
            }
        }
        
        Menu("Liquid Glass Intensity") {
            Button(settings.liquidGlassIntensity == 0.50 ? "✓ Subtle (50%)" : "Subtle (50%)") {
                withAnimation { settings.liquidGlassIntensity = 0.50 }
            }
            Button(settings.liquidGlassIntensity == 0.85 ? "✓ Balanced Lock Screen (85%)" : "Balanced Lock Screen (85%)") {
                withAnimation { settings.liquidGlassIntensity = 0.85 }
            }
            Button(settings.liquidGlassIntensity == 1.00 ? "✓ Pure Crystal Refraction (100%)" : "Pure Crystal Refraction (100%)") {
                withAnimation { settings.liquidGlassIntensity = 1.00 }
            }
        }
        
        Menu("Clock Size") {
            Button(abs(settings.clockScale - 0.70) < 0.02 ? "✓ Compact (70%)" : "Compact (70%)") {
                withAnimation { settings.clockScale = 0.70 }
            }
            Button(abs(settings.clockScale - 0.85) < 0.02 ? "✓ Standard Lock Screen (85%)" : "Standard Lock Screen (85%)") {
                withAnimation { settings.clockScale = 0.85 }
            }
            Button(abs(settings.clockScale - 1.00) < 0.02 ? "✓ Large (100%)" : "Large (100%)") {
                withAnimation { settings.clockScale = 1.00 }
            }
            Button(abs(settings.clockScale - 1.15) < 0.02 ? "✓ Extra Large (115%)" : "Extra Large (115%)") {
                withAnimation { settings.clockScale = 1.15 }
            }
        }
        
        Menu("Clock Height Stretch") {
            Button(abs(settings.clockHeightRatio - 0.85) < 0.05 ? "✓ Condensed (85%)" : "Condensed (85%)") {
                withAnimation { settings.clockHeightRatio = 0.85 }
            }
            Button(abs(settings.clockHeightRatio - 1.00) < 0.05 ? "✓ Standard Proportions (100%)" : "Standard Proportions (100%)") {
                withAnimation { settings.clockHeightRatio = 1.00 }
            }
            Button(abs(settings.clockHeightRatio - 1.30) < 0.05 ? "✓ Apple Tall Lock Screen (130%)" : "Apple Tall Lock Screen (130%)") {
                withAnimation { settings.clockHeightRatio = 1.30 }
            }
            Button(abs(settings.clockHeightRatio - 1.55) < 0.05 ? "✓ Ultra Tall (155%)" : "Ultra Tall (155%)") {
                withAnimation { settings.clockHeightRatio = 1.55 }
            }
        }
        
        Menu("Window Layer") {
            Button(settings.windowLevel == .desktop ? "✓ Desktop (Behind Active Apps)" : "Desktop (Behind Active Apps)") {
                settings.windowLevel = .desktop
            }
            Button(settings.windowLevel == .floating ? "✓ Always On Top (Floating)" : "Always On Top (Floating)") {
                settings.windowLevel = .floating
            }
        }
        
        Divider()
        
        Toggle("Launch at Startup", isOn: $settings.launchAtStartup)
        
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
        } label: {
            Label("Settings & Appearance…", systemImage: "gearshape")
        }
        
        Divider()
        
        Button(role: .destructive) {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Wizit", systemImage: "power")
        }
    }
}

// MARK: - Apple Lock Screen Corner Arc Shape
private struct AppleCornerArc: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.maxX - radius
        let cy = rect.maxY - radius
        path.addRelativeArc(
            center: CGPoint(x: cx, y: cy),
            radius: radius,
            startAngle: .degrees(0),
            delta: .degrees(90)
        )
        return path
    }
}

// MARK: - Native Apple Lock Screen Edit Done Button
private struct EditModeDoneButton: View {
    let baseScale: Double
    let onDone: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onDone) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10 * baseScale, weight: .bold))
                Text("Done")
                    .font(.system(size: 11 * baseScale, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12 * baseScale)
            .padding(.vertical, 5 * baseScale)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(isHovered ? 0.22 : 0.12))
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.6 : 0.35),
                                Color.white.opacity(isHovered ? 0.3 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.04 : 1.0)
            .animation(.snappy(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
