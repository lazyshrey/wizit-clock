import SwiftUI

public struct ClockWidgetView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var timeManager: TimeManager
    
    @State private var isHovering: Bool = false
    @State private var pinchBaseScale: Double?
    
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
            VStack(spacing: settings.timeLayout == .stacked ? -6 * baseScale : 10 * baseScale) {
                // 1. Date Header (Mathematically Centered above digits)
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
            
            // Edit Mode Outline / Feedback
            if settings.isEditMode {
                RoundedRectangle(cornerRadius: 18 * baseScale)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            }
            
            // Hover & Edit Controls Overlay: Resize buttons, Glass Intensity, Snap Center, Settings
            if (isHovering || settings.isEditMode) && !settings.clickThrough {
                hoverControls(baseScale: baseScale)
                    .offset(y: -34)
            }
        }
        .fixedSize()
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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            widgetContextMenu
        }
    }
    
    // MARK: - Date Header (Clean Apple Lock Screen header)
    @ViewBuilder
    private func dateHeaderView(baseScale: Double) -> some View {
        let dateText = "\(timeManager.weekdayString), \(timeManager.dateFormattedString)"
        
        HStack(spacing: 7 * baseScale) {
            Image(systemName: "calendar")
                .font(.system(size: 17 * baseScale, weight: .semibold, design: settings.fontDesign.design))
            
            Text(dateText)
                .font(.system(size: 18 * baseScale, weight: .semibold, design: settings.fontDesign.design))
                .tracking(0.3)
        }
        .foregroundStyle(
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.96), location: 0.0),
                    .init(color: .white.opacity(0.82), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(settings.shadowIntensity * 0.35), radius: 5 * baseScale, x: 0, y: 2 * baseScale)
        .padding(.bottom, 2 * baseScale)
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
                        Text(timeManager.amPmString)
                            .font(.system(
                                size: 21 * baseScale,
                                weight: .bold,
                                design: settings.fontDesign.design
                            ))
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.92), location: 0.0),
                                        .init(color: Color.white.opacity(0.68), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(settings.shadowIntensity * 0.30), radius: 3, x: 0, y: 1.5)
                    }
                    
                    if settings.showSeconds {
                        Text(timeManager.secondsString)
                            .font(.system(
                                size: 20 * baseScale,
                                weight: .semibold,
                                design: settings.fontDesign.design
                            ))
                            .monospacedDigit()
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.88), location: 0.0),
                                        .init(color: Color.white.opacity(0.64), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(settings.shadowIntensity * 0.30), radius: 3, x: 0, y: 1.5)
                    }
                }
                .frame(width: pmWidth, alignment: .leading)
                .padding(.leading, 6 * baseScale)
                .padding(.bottom, 16 * baseScale) // Aligns with bottom baseline of digits
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
    
    // MARK: - Hover & Edit Controls Bar
    @ViewBuilder
    private func hoverControls(baseScale: Double) -> some View {
        HStack(spacing: 6) {
            // Move indicator
            HStack(spacing: 3) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 9, weight: .bold))
                Text("Drag")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            
            // Shrink Size Button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    settings.clockScale = max(0.45, settings.clockScale - 0.05)
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .help("Shrink size")
            
            // Scale Percentage Reset Button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    settings.clockScale = 0.85
                }
            } label: {
                Text("\(Int(round(settings.clockScale * 100)))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .help("Reset to 85% default")
            
            // Enlarge Size Button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    settings.clockScale = min(1.6, settings.clockScale + 0.05)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .help("Enlarge size")
            
            // Liquid Glass Intensity Cycle Button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if settings.liquidGlassIntensity < 0.65 {
                        settings.liquidGlassIntensity = 0.85
                    } else if settings.liquidGlassIntensity < 0.95 {
                        settings.liquidGlassIntensity = 1.00
                    } else {
                        settings.liquidGlassIntensity = 0.50
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                    Text("\(Int(round(settings.liquidGlassIntensity * 100)))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color.cyan.opacity(0.95))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .help("Cycle liquid glass intensity (50% / 85% / 100%)")
            
            // Center Button
            Button {
                settings.onCenterRequested?()
            } label: {
                Image(systemName: "viewfinder")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .help("Snap dead center under camera notch")
            
            // Settings Button
            Button {
                NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(5)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .help("Open settings panel")
            
            // If in Edit Mode, show "Done" button to pin back to desktop
            if settings.isEditMode {
                Button {
                    withAnimation {
                        settings.isEditMode = false
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Done")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue))
                }
                .buttonStyle(.plain)
                .help("Exit edit mode and pin to desktop")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6))
        )
        .shadow(color: Color.black.opacity(0.30), radius: 8, x: 0, y: 3)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var widgetContextMenu: some View {
        Button {
            withAnimation {
                settings.isEditMode.toggle()
            }
        } label: {
            Label(settings.isEditMode ? "✓ Done Editing (Pin to Desktop)" : "✏️ Move & Resize Widget (Edit Mode)", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
        }
        
        Button {
            settings.onCenterRequested?()
        } label: {
            Label("Snap Dead Center (Under Notch)", systemImage: "viewfinder")
        }
        
        Divider()
        
        Menu("💧 Liquid Glass Intensity") {
            Button("Subtle Frosted Glass (50%)") { settings.liquidGlassIntensity = 0.50 }
            Button("Apple Lock Screen Glass (85% Default)") { settings.liquidGlassIntensity = 0.85 }
            Button("Pure Refractive Crystal (100%)") { settings.liquidGlassIntensity = 1.00 }
        }
        
        Menu("📏 Clock Size") {
            Button("Compact (70%)") { settings.clockScale = 0.70 }
            Button("Standard Lock Screen (85% Default)") { settings.clockScale = 0.85 }
            Button("Large (100%)") { settings.clockScale = 1.00 }
            Button("Extra Large (115%)") { settings.clockScale = 1.15 }
        }
        
        Divider()
        
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
        } label: {
            Label("Settings & Appearance…", systemImage: "slider.horizontal.3")
        }
        
        Toggle(isOn: $settings.isLocked) {
            Label("Lock Position", systemImage: "lock")
        }
        
        Divider()
        
        Button(role: .destructive) {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Wizit", systemImage: "power")
        }
    }
}
