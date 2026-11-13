import SwiftUI

public struct ClockWidgetView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var timeManager: TimeManager
    
    @State private var isHovering: Bool = false
    
    public init(settings: AppSettings = .shared, timeManager: TimeManager = .shared) {
        self.settings = settings
        self.timeManager = timeManager
    }
    
    public var body: some View {
        let baseScale = settings.clockScale
        
        ZStack {
            // Liquid Glass Background Frame
            LiquidGlassSurface(settings: settings)
            
            // Content
            VStack(spacing: 8 * baseScale) {
                // Top row: Date & Calendar capsule
                if settings.showDate {
                    HStack(spacing: 6 * baseScale) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11 * baseScale, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text("\(timeManager.weekdayString.uppercased()) · \(timeManager.dateFormattedString.uppercased())")
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
                                Capsule()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    )
                }
                
                // Center row: Time (Hours : Minutes + Seconds & AM/PM)
                HStack(alignment: .firstTextBaseline, spacing: 4 * baseScale) {
                    // Hours
                    Text(timeManager.hoursString)
                        .font(.system(
                            size: 68 * baseScale,
                            weight: settings.fontWeight.weight,
                            design: settings.fontDesign.design
                        ))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.92)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                    
                    // Blinking Colon Separator
                    Text(":")
                        .font(.system(
                            size: 62 * baseScale,
                            weight: .light,
                            design: settings.fontDesign.design
                        ))
                        .foregroundStyle(.white.opacity(0.75))
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                        .offset(y: -4 * baseScale)
                    
                    // Minutes
                    Text(timeManager.minutesString)
                        .font(.system(
                            size: 68 * baseScale,
                            weight: settings.fontWeight.weight,
                            design: settings.fontDesign.design
                        ))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.92)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                    
                    // Trailing stack: Seconds and/or AM/PM
                    if settings.showSeconds || (!settings.is24Hour && settings.showAmPm) {
                        VStack(alignment: .leading, spacing: 2 * baseScale) {
                            if !settings.is24Hour && settings.showAmPm && !timeManager.amPmString.isEmpty {
                                Text(timeManager.amPmString)
                                    .font(.system(size: 13 * baseScale, weight: .bold, design: settings.fontDesign.design))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .padding(.horizontal, 5 * baseScale)
                                    .padding(.vertical, 2 * baseScale)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color.white.opacity(0.12))
                                    )
                            }
                            
                            if settings.showSeconds {
                                Text(timeManager.secondsString)
                                    .font(.system(
                                        size: 22 * baseScale,
                                        weight: .regular,
                                        design: settings.fontDesign.design
                                    ))
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.70))
                            }
                        }
                        .padding(.leading, 6 * baseScale)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - (6 * baseScale) }
                    }
                }
            }
            .padding(.horizontal, 36 * baseScale)
            .padding(.vertical, 24 * baseScale)
            
            // Hover controls overlay: Quick Settings button & Lock status
            if isHovering && !settings.clickThrough {
                VStack {
                    HStack {
                        if settings.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(6)
                        } else {
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(6)
                        }
                        
                        Spacer()
                        
                        Button {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                        .help("Widget Settings")
                    }
                    Spacer()
                }
                .padding(10)
                .transition(.opacity)
            }
        }
        .frame(minWidth: 320 * baseScale, minHeight: 140 * baseScale)
        .fixedSize()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            widgetContextMenu
        }
    }
    
    @ViewBuilder
    private var widgetContextMenu: some View {
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsWindow"), object: nil)
        } label: {
            Label("Settings & Appearance…", systemImage: "slider.horizontal.3")
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
