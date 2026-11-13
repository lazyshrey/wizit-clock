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
            // Optional Card background (if user explicitly chooses Card mode in settings)
            if settings.displayMode == .card {
                LiquidGlassSurface(settings: settings)
            }
            
            // Content
            VStack(spacing: settings.timeLayout == .stacked ? 0 : 12 * baseScale) {
                // Date & Calendar Header (Centered directly above digits)
                if settings.showDate {
                    dateHeaderView(baseScale: baseScale)
                }
                
                // Clock Digits & AM/PM
                if settings.timeLayout == .stacked {
                    stackedTimeView(baseScale: baseScale)
                } else {
                    horizontalTimeView(baseScale: baseScale)
                }
            }
            .padding(.horizontal, settings.displayMode == .card ? 36 * baseScale : 20 * baseScale)
            .padding(.vertical, settings.displayMode == .card ? 24 * baseScale : 14 * baseScale)
            .contentShape(Rectangle()) // Makes the whole bounding area draggable!
            
            // Hover controls overlay: Settings button & Lock status
            if isHovering && !settings.clickThrough {
                hoverControls
            }
        }
        .fixedSize()
        // Direct drag gesture anywhere on the clock
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
    
    // MARK: - Date Header (Exactly as on macOS / iOS Lock Screen)
    @ViewBuilder
    private func dateHeaderView(baseScale: Double) -> some View {
        let dateText = "\(timeManager.weekdayString), \(timeManager.dateFormattedString)"
        
        HStack(spacing: 7 * baseScale) {
            Image(systemName: "calendar")
                .font(.system(size: 20 * baseScale, weight: .semibold, design: settings.fontDesign.design))
            
            Text(dateText)
                .font(.system(size: 21 * baseScale, weight: .semibold, design: settings.fontDesign.design))
                .tracking(0.3)
        }
        .foregroundStyle(
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.98), location: 0.0),
                    .init(color: .white.opacity(0.85), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(settings.shadowIntensity * 0.35), radius: 5, x: 0, y: 2)
        .padding(.bottom, 2 * baseScale)
    }
    
    // MARK: - Horizontal Time View (10:46 PM)
    @ViewBuilder
    private func horizontalTimeView(baseScale: Double) -> some View {
        let fontSize: CGFloat = (settings.displayMode == .lockScreen ? 132 : 88) * baseScale
        
        HStack(alignment: .bottom, spacing: 10 * baseScale) {
            // Hours : Minutes
            GlassmorphicText(settings: settings) {
                HStack(alignment: .center, spacing: 6 * baseScale) {
                    Text(timeManager.hoursString)
                        .font(.system(
                            size: fontSize,
                            weight: settings.fontWeight.weight,
                            design: settings.fontDesign.design
                        ))
                        .monospacedDigit()
                    
                    Text(":")
                        .font(.system(
                            size: fontSize * 0.88,
                            weight: settings.fontWeight.weight,
                            design: settings.fontDesign.design
                        ))
                        .offset(y: -fontSize * 0.06)
                    
                    Text(timeManager.minutesString)
                        .font(.system(
                            size: fontSize,
                            weight: settings.fontWeight.weight,
                            design: settings.fontDesign.design
                        ))
                        .monospacedDigit()
                }
            }
            
            // Trailing stack: PM & optional seconds
            if (!settings.is24Hour && settings.showAmPm) || settings.showSeconds {
                VStack(alignment: .leading, spacing: 3 * baseScale) {
                    if !settings.is24Hour && settings.showAmPm && !timeManager.amPmString.isEmpty {
                        Text(timeManager.amPmString)
                            .font(.system(
                                size: 26 * baseScale,
                                weight: .bold,
                                design: settings.fontDesign.design
                            ))
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.82), location: 0.0),
                                        .init(color: Color(hex: settings.tintColorHex).opacity(0.65), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(settings.shadowIntensity * 0.35), radius: 4, x: 0, y: 2)
                    }
                    
                    if settings.showSeconds {
                        Text(timeManager.secondsString)
                            .font(.system(
                                size: 26 * baseScale,
                                weight: .semibold,
                                design: settings.fontDesign.design
                            ))
                            .monospacedDigit()
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.80), location: 0.0),
                                        .init(color: Color(hex: settings.tintColorHex).opacity(0.60), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(settings.shadowIntensity * 0.35), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.bottom, 24 * baseScale) // Aligns PM to the bottom baseline of the digits
            }
        }
    }
    
    // MARK: - Stacked Time View (10 / 46)
    @ViewBuilder
    private func stackedTimeView(baseScale: Double) -> some View {
        let fontSize: CGFloat = 110 * baseScale
        
        GlassmorphicText(settings: settings) {
            VStack(spacing: -18 * baseScale) {
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
