import SwiftUI

public struct ClockWidgetView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var timeManager: TimeManager
    
    @State private var pinchBaseScale: Double?
    @State private var dragInitialWindowOrigin: CGPoint? = nil
    
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
                                }
                                dragInitialWindowOrigin = nil
                            }
                    )
                
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
    
    // MARK: - Horizontal Time View (Symmetrically Balanced so 10:46 is Dead Center)
    @ViewBuilder
    private func horizontalTimeView(digitSize: CGFloat, pmWidth: CGFloat, baseScale: Double) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Left invisible balance spacer matching PM width (keeps digits dead center under notch!)
            if pmWidth > 0 {
                Color.clear
                    .frame(width: pmWidth, height: 1)
            }
            
            // Core Digits: Hours : Minutes
            HStack(alignment: .center, spacing: 6 * baseScale) {
                LiquidGlassText(
                    timeManager.hoursString,
                    fontSize: digitSize,
                    weight: settings.fontWeight.weight,
                    design: settings.fontDesign,
                    settings: settings
                )
                .id("hours_" + timeManager.hoursString)
                .transition(.push(from: .bottom))
                
                // Colon (Clean Apple Lock Screen Colon)
                LiquidGlassText(
                    ":",
                    fontSize: digitSize * 0.90,
                    weight: settings.fontWeight.weight,
                    design: settings.fontDesign,
                    settings: settings
                )
                
                LiquidGlassText(
                    timeManager.minutesString,
                    fontSize: digitSize,
                    weight: settings.fontWeight.weight,
                    design: settings.fontDesign,
                    settings: settings
                )
                .id("minutes_" + timeManager.minutesString)
                .transition(.push(from: .bottom))
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
                            settings: settings
                        )
                        .padding(.leading, 6 * baseScale)
                        .padding(.bottom, 14 * baseScale)
                    }
                    
                    if settings.showSeconds {
                        LiquidGlassText(
                            timeManager.secondsString,
                            fontSize: 20 * baseScale,
                            weight: .semibold,
                            design: settings.fontDesign,
                            settings: settings
                        )
                        .id("seconds_" + timeManager.secondsString)
                        .transition(.push(from: .bottom))
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
            LiquidGlassText(
                timeManager.hoursString,
                fontSize: digitSize * 0.95,
                weight: settings.fontWeight.weight,
                design: settings.fontDesign,
                settings: settings
            )
            .id("stacked_hours_" + timeManager.hoursString)
            .transition(.push(from: .bottom))
            
            LiquidGlassText(
                timeManager.minutesString,
                fontSize: digitSize * 0.95,
                weight: settings.fontWeight.weight,
                design: settings.fontDesign,
                settings: settings
            )
            .id("stacked_minutes_" + timeManager.minutesString)
            .transition(.push(from: .bottom))
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
                settings.isEditMode ? "🔒 Lock Clock Position" : "✏️ Unlock to Move Clock",
                systemImage: settings.isEditMode ? "lock.fill" : "arrow.up.and.down.and.arrow.left.and.right"
            )
        }
        
        Button {
            settings.onCenterRequested?()
        } label: {
            Label("🎯 Snap to Center (Under Camera Notch)", systemImage: "viewfinder")
        }
        
        Divider()
        
        Menu("💧 Liquid Glass Intensity") {
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
        
        Menu("📏 Clock Size") {
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
        
        Menu("🪟 Window Layer") {
            Button(settings.windowLevel == .desktop ? "✓ Desktop (Behind Active Apps)" : "Desktop (Behind Active Apps)") {
                settings.windowLevel = .desktop
            }
            Button(settings.windowLevel == .floating ? "✓ Always On Top (Floating)" : "Always On Top (Floating)") {
                settings.windowLevel = .floating
            }
        }
        
        Divider()
        
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
        } label: {
            Label("⚙️ Settings & Appearance…", systemImage: "slider.horizontal.3")
        }
        
        Divider()
        
        Button(role: .destructive) {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Wizit", systemImage: "power")
        }
    }
}
