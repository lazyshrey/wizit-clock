import SwiftUI

public struct ClockWidgetView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var timeManager: TimeManager
    
    @State private var pinchBaseScale: Double?
    @State private var dragInitialWindowOrigin: CGPoint? = nil
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
            VStack(spacing: settings.timeLayout == .stacked ? -8 * baseScale : -2 * baseScale) {
                // 1. Date Header (Mathematically Centered above digits, tight lock-screen spacing)
                if settings.showDate {
                    dateHeaderView(baseScale: baseScale)
                }
                
                // 2. Time Digits (Hours : Minutes + PM)
                if settings.timeLayout == .stacked {
                    stackedTimeView(digitSize: digitSize, baseScale: baseScale)
                } else {
                    horizontalTimeView(digitSize: digitSize, pmWidth: pmWidth, baseScale: baseScale)
                }
            }
            .padding(.horizontal, settings.displayMode == .card ? 32 * baseScale : 20 * baseScale)
            .padding(.vertical, settings.displayMode == .card ? 22 * baseScale : 14 * baseScale)
            
            // Move Mode Visual Boundary & Header (Only visible when unlocked to move)
            if settings.isEditMode {
                RoundedRectangle(cornerRadius: 18 * baseScale)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { gesture in
                                guard let window = NSApp.windows.first(where: { $0 is DesktopClockWindow }) else { return }
                                if dragInitialWindowOrigin == nil {
                                    dragInitialWindowOrigin = window.frame.origin
                                    NSCursor.closedHand.push()
                                }
                                guard let initial = dragInitialWindowOrigin else { return }
                                let newOrigin = CGPoint(
                                    x: initial.x + gesture.translation.width,
                                    y: initial.y - gesture.translation.height
                                )
                                window.setFrameOrigin(newOrigin)
                            }
                            .onEnded { _ in
                                NSCursor.pop()
                                if let window = NSApp.windows.first(where: { $0 is DesktopClockWindow }) {
                                    settings.windowPositionX = Double(window.frame.origin.x)
                                    settings.windowPositionY = Double(window.frame.origin.y)
                                    UserDefaults.standard.synchronize()
                                }
                                dragInitialWindowOrigin = nil
                            }
                    )
                    .overlay(alignment: .bottomTrailing) {
                        singleResizeNotch(baseScale: baseScale)
                    }
                
                Button {
                    withAnimation {
                        settings.isEditMode = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Done Moving (Click to Lock)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue))
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .offset(y: -30)
            }
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
    }
    
    // MARK: - Single Corner Grab Notch (Sets both Scale and Height)
    @ViewBuilder
    private func singleResizeNotch(baseScale: Double) -> some View {
        HStack(spacing: 2.5) {
            Capsule().fill(Color.white.opacity(0.95)).frame(width: 2.5, height: 10 * baseScale)
            Capsule().fill(Color.white.opacity(0.95)).frame(width: 2.5, height: 10 * baseScale)
            Capsule().fill(Color.white.opacity(0.95)).frame(width: 2.5, height: 10 * baseScale)
        }
        .padding(.horizontal, 7 * baseScale)
        .padding(.vertical, 5 * baseScale)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.95), Color.blue.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .offset(x: 6 * baseScale, y: 6 * baseScale)
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartScale == nil {
                        dragStartScale = settings.clockScale
                        dragStartHeightRatio = settings.clockHeightRatio
                        settings.isResizing = true
                    }
                    guard let startScale = dragStartScale,
                          let startHeight = dragStartHeightRatio else { return }
                    
                    // 1. Horizontal movement controls overall clock size (Scale)
                    let scaleDelta = Double(value.translation.width) / 280.0
                    let newScale = min(1.65, max(0.45, startScale + scaleDelta))
                    settings.clockScale = newScale
                    
                    // 2. Vertical movement controls height ratio (Stretch / Condense)
                    let heightDelta = Double(value.translation.height) / 140.0
                    let newHeight = min(1.85, max(0.65, startHeight + heightDelta))
                    settings.clockHeightRatio = newHeight
                }
                .onEnded { _ in
                    dragStartScale = nil
                    dragStartHeightRatio = nil
                    settings.isResizing = false
                    settings.onLayoutChanged?()
                    if let window = NSApp.windows.first(where: { $0 is DesktopClockWindow }) {
                        settings.windowPositionX = Double(window.frame.origin.x)
                        settings.windowPositionY = Double(window.frame.origin.y)
                    }
                    UserDefaults.standard.synchronize()
                }
        )
        .overlay(alignment: .topTrailing) {
            if dragStartScale != nil {
                Text("\(Int(round(settings.clockScale * 100)))% Scale • \(String(format: "%.1fx", settings.clockHeightRatio)) H")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.85)))
                    .shadow(radius: 4)
                    .fixedSize()
                    .offset(x: 0, y: -26 * baseScale)
            }
        }
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
    
    // MARK: - Animated Split Digits (Per-digit independent sliding transitions)
    @ViewBuilder
    private func splitDigitsView(
        prefix: String,
        text: String,
        digitSize: CGFloat,
        weight: Font.Weight,
        heightRatio: Double
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                let charString = String(char)
                LiquidGlassText(
                    charString,
                    fontSize: digitSize,
                    weight: weight,
                    design: settings.fontDesign,
                    heightRatio: heightRatio,
                    settings: settings
                )
                .id("\(prefix)_\(index)_\(charString)")
                .transition(.push(from: .bottom))
            }
        }
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
            
            // Core Digits: Hours : Minutes (Each digit animates independently)
            HStack(alignment: .center, spacing: 6 * baseScale) {
                splitDigitsView(
                    prefix: "hours",
                    text: timeManager.hoursString,
                    digitSize: digitSize,
                    weight: settings.fontWeight.weight,
                    heightRatio: settings.clockHeightRatio
                )
                
                // Colon (Clean Apple Lock Screen Colon)
                LiquidGlassText(
                    ":",
                    fontSize: digitSize * 0.90,
                    weight: settings.fontWeight.weight,
                    design: settings.fontDesign,
                    heightRatio: settings.clockHeightRatio,
                    settings: settings
                )
                
                splitDigitsView(
                    prefix: "minutes",
                    text: timeManager.minutesString,
                    digitSize: digitSize,
                    weight: settings.fontWeight.weight,
                    heightRatio: settings.clockHeightRatio
                )
            }
            
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
                        splitDigitsView(
                            prefix: "seconds",
                            text: timeManager.secondsString,
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
            splitDigitsView(
                prefix: "stacked_hours",
                text: timeManager.hoursString,
                digitSize: digitSize * 0.95,
                weight: settings.fontWeight.weight,
                heightRatio: settings.clockHeightRatio
            )
            
            splitDigitsView(
                prefix: "stacked_minutes",
                text: timeManager.minutesString,
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
