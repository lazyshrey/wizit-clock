import SwiftUI

public struct ClockWidgetView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var timeManager: TimeManager
    
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    
    public init(settings: AppSettings = .shared, timeManager: TimeManager = .shared) {
        self.settings = settings
        self.timeManager = timeManager
    }
    
    public var body: some View {
        let baseScale = settings.clockScale
        
        ZStack {
            // Background: If card mode is enabled, show the card. If lockscreen mode, background is 100% transparent!
            if settings.displayMode == .card {
                LiquidGlassSurface(settings: settings)
            }
            
            // Content
            VStack(spacing: settings.timeLayout == .stacked ? 0 : 8 * baseScale) {
                // Date & Calendar Header
                if settings.showDate {
                    dateHeaderView(baseScale: baseScale)
                }
                
                // Hero Clock Digits
                if settings.timeLayout == .stacked {
                    stackedTimeView(baseScale: baseScale)
                } else {
                    horizontalTimeView(baseScale: baseScale)
                }
            }
            .padding(.horizontal, settings.displayMode == .card ? 36 * baseScale : 20 * baseScale)
            .padding(.vertical, settings.displayMode == .card ? 24 * baseScale : 14 * baseScale)
            .contentShape(Rectangle()) // Makes the whole bounding area draggable!
            
            // Hover controls overlay: Quick Settings button & Lock status
            if isHovering && !settings.clickThrough {
                hoverControls
            }
        }
        .fixedSize()
        // Reliable direct-drag gesture across any screen
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard !settings.isLocked && !settings.clickThrough else { return }
                    if !isDragging {
                        isDragging = true
                        DesktopWindowManager.shared.startDrag()
                    }
                    DesktopWindowManager.shared.drag(by: value.translation)
                }
                .onEnded { _ in
                    isDragging = false
                    DesktopWindowManager.shared.endDrag()
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            widgetContextMenu
        }
    }
    
    // MARK: - Date Header
    @ViewBuilder
    private func dateHeaderView(baseScale: Double) -> some View {
        let dateText = "\(timeManager.weekdayString), \(timeManager.dateFormattedString)"
        
        if settings.displayMode == .lockScreen {
            GlassmorphicText(settings: settings) {
                HStack(spacing: 6 * baseScale) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14 * baseScale, weight: .semibold))
                    
                    Text(dateText)
                        .font(.system(size: 16 * baseScale, weight: .semibold, design: settings.fontDesign.design))
                        .tracking(0.5)
                }
            }
            .padding(.bottom, 2 * baseScale)
        } else {
            HStack(spacing: 6 * baseScale) {
                Image(systemName: "calendar")
                    .font(.system(size: 11 * baseScale, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(dateText.uppercased())
                    .font(.system(size: 11 * baseScale, weight: .semibold, design: settings.fontDesign.design))
                    .tracking(1.4)
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .padding(.horizontal, 12 * baseScale)
            .padding(.vertical, 4 * baseScale)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - Horizontal Time View (10:42)
    @ViewBuilder
    private func horizontalTimeView(baseScale: Double) -> some View {
        let fontSize: CGFloat = (settings.displayMode == .lockScreen ? 92 : 68) * baseScale
        
        GlassmorphicText(settings: settings) {
            HStack(alignment: .firstTextBaseline, spacing: 4 * baseScale) {
                // Hours
                Text(timeManager.hoursString)
                    .font(.system(
                        size: fontSize,
                        weight: settings.fontWeight.weight,
                        design: settings.fontDesign.design
                    ))
                    .monospacedDigit()
                
                // Colon Separator
                Text(":")
                    .font(.system(
                        size: fontSize * 0.90,
                        weight: .light,
                        design: settings.fontDesign.design
                    ))
                    .offset(y: -fontSize * 0.05)
                
                // Minutes
                Text(timeManager.minutesString)
                    .font(.system(
                        size: fontSize,
                        weight: settings.fontWeight.weight,
                        design: settings.fontDesign.design
                    ))
                    .monospacedDigit()
                
                // Seconds & AM/PM
                if settings.showSeconds || (!settings.is24Hour && settings.showAmPm) {
                    VStack(alignment: .leading, spacing: 2 * baseScale) {
                        if !settings.is24Hour && settings.showAmPm && !timeManager.amPmString.isEmpty {
                            Text(timeManager.amPmString)
                                .font(.system(size: 14 * baseScale, weight: .bold, design: settings.fontDesign.design))
                                .padding(.horizontal, 5 * baseScale)
                                .padding(.vertical, 2 * baseScale)
                        }
                        
                        if settings.showSeconds {
                            Text(timeManager.secondsString)
                                .font(.system(
                                    size: 26 * baseScale,
                                    weight: .medium,
                                    design: settings.fontDesign.design
                                ))
                                .monospacedDigit()
                        }
                    }
                    .padding(.leading, 6 * baseScale)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - (8 * baseScale) }
                }
            }
        }
    }
    
    // MARK: - Stacked Time View (10 on top, 42 on bottom)
    @ViewBuilder
    private func stackedTimeView(baseScale: Double) -> some View {
        let fontSize: CGFloat = 86 * baseScale
        
        GlassmorphicText(settings: settings) {
            VStack(spacing: -14 * baseScale) {
                Text(timeManager.hoursString)
                    .font(.system(
                        size: fontSize,
                        weight: settings.fontWeight.weight,
                        design: settings.fontDesign.design
                    ))
                    .monospacedDigit()
                
                Text(timeManager.minutesString)
                    .font(.system(
                        size: fontSize,
                        weight: settings.fontWeight.weight,
                        design: settings.fontDesign.design
                    ))
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Hover Controls
    @ViewBuilder
    private var hoverControls: some View {
        VStack {
            HStack {
                if settings.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                } else {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                        .help("Drag anywhere to move widget")
                }
                
                Spacer()
                
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                }
                .buttonStyle(.plain)
                .help("Widget Settings")
            }
            Spacer()
        }
        .padding(8)
        .transition(.opacity)
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var widgetContextMenu: some View {
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
        } label: {
            Label("Settings & Appearance…", systemImage: "slider.horizontal.3")
        }
        
        Divider()
        
        Picker("Style Mode", selection: $settings.displayMode) {
            ForEach(WidgetDisplayMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        
        Picker("Time Layout", selection: $settings.timeLayout) {
            ForEach(TimeLayout.allCases) { layout in
                Text(layout.rawValue).tag(layout)
            }
        }
        
        Divider()
        
        Button {
            settings.onCenterRequested?()
        } label: {
            Label("Snap to Screen Center", systemImage: "viewfinder")
        }
        
        Toggle(isOn: $settings.isLocked) {
            Label("Lock Position", systemImage: "lock")
        }
        
        Toggle(isOn: $settings.clickThrough) {
            Label("Click-Through Mode", systemImage: "cursorarrow.and.square.on.square.dashed")
        }
        
        Divider()
        
        Menu("Glass Presets") {
            ForEach(GlassPreset.allCases) { preset in
                Button(preset.rawValue) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        settings.applyPreset(preset)
                    }
                }
            }
        }
        
        Divider()
        
        Button(role: .destructive) {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Wizit", systemImage: "power")
        }
    }
}
