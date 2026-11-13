import SwiftUI

public struct ClockWidgetView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var timeManager: TimeManager
    
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var pinchBaseScale: Double?
    
    public init(settings: AppSettings = .shared, timeManager: TimeManager = .shared) {
        self.settings = settings
        self.timeManager = timeManager
    }
    
    public var body: some View {
        let baseScale = settings.clockScale
        let digitSize: CGFloat = (settings.displayMode == .lockScreen ? 82 : 64) * baseScale
        let pmWidth: CGFloat = (!settings.is24Hour && settings.showAmPm) ? 42 * baseScale : 0
        
        ZStack {
            // Optional Card background (if user explicitly chooses Card mode)
            if settings.displayMode == .card {
                LiquidGlassSurface(settings: settings)
            }
            
            // Content
            VStack(spacing: settings.timeLayout == .stacked ? -6 * baseScale : 8 * baseScale) {
                // 1. Date & Calendar Header (Mathematically Centered)
                if settings.showDate {
                    dateHeaderView(baseScale: baseScale)
                }
                
                // 2. Clock Digits (Hours : Minutes + PM)
                if settings.timeLayout == .stacked {
                    stackedTimeView(digitSize: digitSize, baseScale: baseScale)
                } else {
                    horizontalTimeView(digitSize: digitSize, pmWidth: pmWidth, baseScale: baseScale)
                }
            }
            .padding(.horizontal, settings.displayMode == .card ? 32 * baseScale : 18 * baseScale)
            .padding(.vertical, settings.displayMode == .card ? 22 * baseScale : 12 * baseScale)
            .contentShape(Rectangle()) // Makes the whole bounding area draggable!
            
            // Hover controls overlay: Resize buttons, Gear button, Lock status
            if isHovering && !settings.clickThrough {
                hoverControls(baseScale: baseScale)
            }
        }
        .fixedSize()
        // Direct pinch-to-zoom resizing gesture (trackpad two-finger pinch)
        .gesture(
            MagnificationGesture()
                .onChanged { scale in
                    if pinchBaseScale == nil {
                        pinchBaseScale = settings.clockScale
                    }
                    if let startScale = pinchBaseScale {
                        let newScale = min(1.8, max(0.45, startScale * scale))
                        settings.clockScale = newScale
                    }
                }
                .onEnded { _ in
                    pinchBaseScale = nil
                }
        )
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
    
    // MARK: - Date Header
    @ViewBuilder
    private func dateHeaderView(baseScale: Double) -> some View {
        let dateText = "\(timeManager.weekdayString), \(timeManager.dateFormattedString)"
        
        HStack(spacing: 6 * baseScale) {
            Image(systemName: "calendar")
                .font(.system(size: 15 * baseScale, weight: .semibold, design: settings.fontDesign.design))
            
            Text(dateText)
                .font(.system(size: 16 * baseScale, weight: .semibold, design: settings.fontDesign.design))
                .tracking(0.3)
        }
        .foregroundStyle(
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.98), location: 0.0),
                    .init(color: .white.opacity(0.82), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(settings.shadowIntensity * 0.40), radius: 4 * baseScale, x: 0, y: 2 * baseScale)
        .padding(.bottom, 2 * baseScale)
    }
    
    // MARK: - Horizontal Time View (Symmetrically Balanced so 10:50 is Dead Center)
    @ViewBuilder
    private func horizontalTimeView(digitSize: CGFloat, pmWidth: CGFloat, baseScale: Double) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Left invisible balance spacer matching PM width (keeps 10:50 dead center under the notch!)
            if pmWidth > 0 {
                Color.clear
                    .frame(width: pmWidth, height: 1)
            }
            
            // Core Digits: Hours : Minutes
            HStack(alignment: .center, spacing: 4 * baseScale) {
                LiquidGlassText(
                    timeManager.hoursString,
                    fontSize: digitSize,
                    weight: settings.fontWeight.weight,
                    design: settings.fontDesign.design,
                    settings: settings
                )
                
                // Colon
                LiquidGlassText(
                    ":",
                    fontSize: digitSize * 0.90,
                    weight: settings.fontWeight.weight,
                    design: settings.fontDesign.design,
                    settings: settings
                )
                .offset(y: -digitSize * 0.06)
                
                LiquidGlassText(
                    timeManager.minutesString,
                    fontSize: digitSize,
                    weight: settings.fontWeight.weight,
                    design: settings.fontDesign.design,
                    settings: settings
                )
            }
            
            // Trailing: PM & optional seconds
            if pmWidth > 0 || settings.showSeconds {
                VStack(alignment: .leading, spacing: 2 * baseScale) {
                    if !settings.is24Hour && settings.showAmPm && !timeManager.amPmString.isEmpty {
                        Text(timeManager.amPmString)
                            .font(.system(
                                size: 19 * baseScale,
                                weight: .bold,
                                design: settings.fontDesign.design
                            ))
                            .foregroundStyle(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.85), location: 0.0),
                                        .init(color: Color(hex: settings.tintColorHex).opacity(0.65), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(settings.shadowIntensity * 0.35), radius: 3, x: 0, y: 1.5)
                    }
                    
                    if settings.showSeconds {
                        Text(timeManager.secondsString)
                            .font(.system(
                                size: 18 * baseScale,
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
                            .shadow(color: Color.black.opacity(settings.shadowIntensity * 0.35), radius: 3, x: 0, y: 1.5)
                    }
                }
                .frame(width: pmWidth, alignment: .leading)
                .padding(.leading, 6 * baseScale)
                .padding(.bottom, 14 * baseScale) // Aligns with the bottom baseline of the digits
            }
        }
    }
    
    // MARK: - Stacked Time View
    @ViewBuilder
    private func stackedTimeView(digitSize: CGFloat, baseScale: Double) -> some View {
        VStack(spacing: -12 * baseScale) {
            LiquidGlassText(
                timeManager.hoursString,
                fontSize: digitSize * 0.95,
                weight: settings.fontWeight.weight,
                design: settings.fontDesign.design,
                settings: settings
            )
            
            LiquidGlassText(
                timeManager.minutesString,
                fontSize: digitSize * 0.95,
                weight: settings.fontWeight.weight,
                design: settings.fontDesign.design,
                settings: settings
            )
        }
    }
    
    // MARK: - Hover Controls (Resize & Settings)
    @ViewBuilder
    private func hoverControls(baseScale: Double) -> some View {
        VStack {
            HStack(spacing: 8) {
                // Drag handle or lock indicator
                if settings.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                } else {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                        .help("Drag to move widget")
                }
                
                // Live scale down button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        settings.clockScale = max(0.45, settings.clockScale - 0.10)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .help("Shrink clock")
                
                // Scale indicator
                Text("\(Int(settings.clockScale * 100))%")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                
                // Live scale up button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        settings.clockScale = min(1.8, settings.clockScale + 0.10)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .help("Enlarge clock")
                
                Spacer()
                
                // Settings button
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .help("Widget Settings")
            }
            Spacer()
        }
        .padding(6)
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
        
        Menu("Size / Scale") {
            Button("Small (65%)") { settings.clockScale = 0.65 }
            Button("Medium (85% Default)") { settings.clockScale = 0.85 }
            Button("Large (110%)") { settings.clockScale = 1.10 }
            Button("Extra Large (135%)") { settings.clockScale = 1.35 }
        }
        
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
        
        Picker("Time Layout", selection: $settings.timeLayout) {
            ForEach(TimeLayout.allCases) { layout in
                Text(layout.rawValue).tag(layout)
            }
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
