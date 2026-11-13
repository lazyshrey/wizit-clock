import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedTab: SettingsTab = .glass
    
    public enum SettingsTab: String, CaseIterable, Identifiable {
        case glass = "Liquid Glass"
        case typography = "Clock & Font"
        case window = "Desktop & Position"
        case presets = "Presets"
        
        public var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .glass: return "drop.fill"
            case .typography: return "clock.fill"
            case .window: return "macwindow"
            case .presets: return "sparkles"
            }
        }
    }
    
    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Modern Segmented Header Bar
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selectedTab == tab
                                ? Capsule().fill(Color.accentColor.opacity(0.18))
                                : Capsule().fill(Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedTab == tab ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                }
                
                Spacer()
                
                Button("Reset Defaults") {
                    withAnimation {
                        settings.resetToDefaults()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .glass:
                        glassSection
                    case .typography:
                        typographySection
                    case .window:
                        windowSection
                    case .presets:
                        presetsSection
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 540, height: 480)
    }
    
    // MARK: - 1. Liquid Glass Tab
    private var glassSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Glass Material & Transparency", icon: "drop.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Glass Style")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: $settings.glassVariant) {
                            ForEach(LiquidGlassVariant.allCases) { v in
                                Text(v.rawValue).tag(v)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 280)
                    }
                    
                    Divider()
                    
                    sliderRow(
                        title: "Refraction Intensity",
                        subtitle: "Specular rim brightness and optical lensing",
                        value: $settings.liquidGlassIntensity,
                        range: 0.1...1.0,
                        unit: "%",
                        multiplier: 100
                    )
                    
                    Divider()
                    
                    sliderRow(
                        title: "3D Drop Shadow",
                        subtitle: "Depth elevation above desktop wallpaper",
                        value: $settings.shadowIntensity,
                        range: 0.0...1.0,
                        unit: "%",
                        multiplier: 100
                    )
                }
            }
            
            settingsCard(title: "Display Container", icon: "rectangle.inset.filled") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Presentation Mode")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: $settings.displayMode) {
                            ForEach(WidgetDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 240)
                    }
                }
            }
        }
    }
    
    // MARK: - 2. Typography & Clock Tab
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Typography", icon: "textformat") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Font Design")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: $settings.fontDesign) {
                            ForEach(ClockFontDesign.allCases) { fd in
                                Text(fd.rawValue).tag(fd)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Font Weight")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: $settings.fontWeight) {
                            ForEach(ClockFontWeight.allCases) { fw in
                                Text(fw.rawValue).tag(fw)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    
                    Divider()
                    
                    sliderRow(
                        title: "Clock Size / Scale",
                        subtitle: "Standard lock screen size is 85%",
                        value: $settings.clockScale,
                        range: 0.45...1.50,
                        unit: "%",
                        multiplier: 100
                    )
                }
            }
            
            settingsCard(title: "Time & Date Format", icon: "calendar") {
                VStack(spacing: 12) {
                    Toggle("24-Hour Time Format", isOn: $settings.is24Hour)
                    Divider()
                    Toggle("Show Date Header", isOn: $settings.showDate)
                    Divider()
                    Toggle("Show Seconds", isOn: $settings.showSeconds)
                }
            }
        }
    }
    
    // MARK: - 3. Window & Placement Tab
    private var windowSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Screen Placement", icon: "viewfinder") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Snap Dead Center")
                                .font(.system(size: 13, weight: .medium))
                            Text("Center horizontally directly beneath MacBook camera notch")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Center Clock") {
                            settings.onCenterRequested?()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock to Move Clock")
                                .font(.system(size: 13, weight: .medium))
                            Text("Enables dragging across the desktop screen")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.isEditMode)
                            .toggleStyle(.switch)
                    }
                }
            }
            
            settingsCard(title: "Window Layer", icon: "macwindow") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Window Layer", selection: $settings.windowLevel) {
                        ForEach(WindowLevelOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
            }
        }
    }
    
    // MARK: - 4. Presets Tab
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Curated Glass Presets")
                .font(.headline)
            
            ForEach(GlassPreset.allCases) { preset in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        settings.applyPreset(preset)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(presetDescription(preset))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("Apply")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func presetDescription(_ preset: GlassPreset) -> String {
        switch preset {
        case .lockScreenClassic: return "Apple Lock Screen 100% transparent clear liquid glass with specular rims."
        case .visionPro: return "VisionOS translucent glass card with real-time backdrop blur."
        case .pureCrystal: return "Ultra-clear pure crystal refraction with icy specular rim bevels."
        case .deepObsidian: return "Smoked obsidian glass with perimeter rim reflections."
        case .warmSunset: return "Amber sunset liquid glass cast with golden rim highlights."
        case .auroraMist: return "Ethereal emerald liquid glass with atmospheric vibrancy."
        }
    }
    
    // MARK: - Helper Views
    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    private func sliderRow(
        title: String,
        subtitle: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        multiplier: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(round(value.wrappedValue * multiplier)))\(unit)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 45, alignment: .trailing)
            }
            
            Slider(value: value, in: range)
        }
    }
}
