import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedTab: SettingsTab = .glass
    
    public enum SettingsTab: String, CaseIterable, Identifiable {
        case glass = "Glass & Liquid"
        case typography = "Clock & Typography"
        case position = "Position & Window"
        case presets = "Presets"
        
        public var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .glass: return "sparkles"
            case .typography: return "textformat"
            case .position: return "macwindow"
            case .presets: return "swatchpalette"
            }
        }
    }
    
    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with Tab Bar
            HStack(spacing: 12) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == tab
                                ? Capsule().fill(Color.accentColor.opacity(0.18))
                                : Capsule().fill(Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedTab == tab ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .glass:
                        glassTab
                    case .typography:
                        typographyTab
                    case .position:
                        positionTab
                    case .presets:
                        presetsTab
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 540, height: 490)
    }
    
    // MARK: - Glass & Liquid Tab
    private var glassTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Transparency & Blur Material", subtitle: "Controls background optical translucency and frosted blur")
            
            // Transparency slider
            sliderRow(
                title: "Transparency",
                value: $settings.transparency,
                range: 0.05...0.95,
                unit: "%",
                multiplier: 100
            )
            
            // Blur Material Picker
            HStack {
                Text("Vibrancy Material")
                    .frame(width: 140, alignment: .leading)
                
                Picker("", selection: $settings.glassMaterial) {
                    ForEach(GlassMaterialOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(title: "Liquid Glass & Refraction Effects", subtitle: "Micro-optics simulating curved fluid glass, caustics, and edge refraction")
            
            // Liquid Refraction Strength
            sliderRow(
                title: "Liquid Refraction",
                value: $settings.liquidRefraction,
                range: 0.0...1.0,
                unit: "%",
                multiplier: 100
            )
            
            // Rim Light / Incident Highlight
            sliderRow(
                title: "Specular Rim Light",
                value: $settings.rimLightIntensity,
                range: 0.0...1.0,
                unit: "%",
                multiplier: 100
            )
            
            // Surface Sheen Glare
            sliderRow(
                title: "Convex Surface Sheen",
                value: $settings.surfaceSheen,
                range: 0.0...1.0,
                unit: "%",
                multiplier: 100
            )
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(title: "Tint & Edge Geometry", subtitle: "Glass color cast and corner curvature")
            
            // Tint Color Picker & Opacity
            HStack {
                Text("Glass Tint Color")
                    .frame(width: 140, alignment: .leading)
                
                ColorPicker("", selection: Binding(
                    get: { Color(hex: settings.tintColorHex) },
                    set: { newColor in
                        if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
                            let hex = String(format: "#%02X%02X%02X",
                                             Int(nsColor.redComponent * 255),
                                             Int(nsColor.greenComponent * 255),
                                             Int(nsColor.blueComponent * 255))
                            settings.tintColorHex = hex
                        }
                    }
                ))
                .labelsHidden()
                
                Spacer()
                
                Text("Tint Opacity: \(Int(settings.tintOpacity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .trailing)
            }
            
            sliderRow(
                title: "Tint Opacity",
                value: $settings.tintOpacity,
                range: 0.0...0.60,
                unit: "%",
                multiplier: 100
            )
            
            sliderRow(
                title: "Corner Squircle",
                value: $settings.cornerRadius,
                range: 16.0...56.0,
                unit: "pt",
                multiplier: 1
            )
            
            sliderRow(
                title: "Glass Rim Width",
                value: $settings.glassBorderWidth,
                range: 0.5...2.5,
                unit: "pt",
                multiplier: 1
            )
            
            sliderRow(
                title: "Depth Shadow",
                value: $settings.shadowIntensity,
                range: 0.0...1.0,
                unit: "%",
                multiplier: 100
            )
        }
    }
    
    // MARK: - Typography Tab
    private var typographyTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Time Display & Format", subtitle: "Configure clock layout and indicators")
            
            HStack {
                Toggle("24-Hour Time Format", isOn: $settings.is24Hour)
                    .toggleStyle(.checkbox)
                
                Spacer()
                
                Toggle("Show Seconds Ticker", isOn: $settings.showSeconds)
                    .toggleStyle(.checkbox)
            }
            
            HStack {
                Toggle("Show Date Capsule", isOn: $settings.showDate)
                    .toggleStyle(.checkbox)
                
                Spacer()
                
                if !settings.is24Hour {
                    Toggle("Show AM / PM", isOn: $settings.showAmPm)
                        .toggleStyle(.checkbox)
                }
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(title: "Typography & Scaling", subtitle: "Font face, weights, and overall size")
            
            HStack {
                Text("Typeface Family")
                    .frame(width: 140, alignment: .leading)
                
                Picker("", selection: $settings.fontDesign) {
                    ForEach(ClockFontDesign.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Text("Font Weight")
                    .frame(width: 140, alignment: .leading)
                
                Picker("", selection: $settings.fontWeight) {
                    ForEach(ClockFontWeight.allCases) { w in
                        Text(w.rawValue).tag(w)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            
            sliderRow(
                title: "Widget Scale",
                value: $settings.clockScale,
                range: 0.7...1.6,
                unit: "x",
                multiplier: 1
            )
        }
    }
    
    // MARK: - Position & Window Tab
    private var positionTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Desktop Placement & Level", subtitle: "Choose where the clock sits in macOS window hierarchy")
            
            VStack(alignment: .leading, spacing: 10) {
                Picker("Window Layer", selection: $settings.windowLevel) {
                    ForEach(WindowLevelOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text("• Desktop Level: Widget sits directly above your desktop wallpaper, behind your open apps.\n• Always On Top: Widget floats above all apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(title: "Alignment & Mouse Behavior", subtitle: "Lock position or allow click-through to desktop files")
            
            HStack(spacing: 16) {
                Button {
                    settings.onCenterRequested?()
                } label: {
                    Label("Snap Clock to Screen Center", systemImage: "viewfinder")
                }
                .buttonStyle(.borderedProminent)
            }
            
            Toggle("Lock Position (prevent dragging)", isOn: $settings.isLocked)
                .toggleStyle(.checkbox)
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Click-Through Mode (pass clicks to desktop)", isOn: $settings.clickThrough)
                    .toggleStyle(.checkbox)
                
                Text("When enabled, clicks pass through the widget to desktop icons. You can re-open settings from the Menu Bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Presets Tab
    private var presetsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Curated Glass Presets", subtitle: "One-click designer glassmorphism styles")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(GlassPreset.allCases) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            settings.applyPreset(preset)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(preset.rawValue)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .opacity(0.4)
                            }
                            Text(presetDescription(preset))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func presetDescription(_ preset: GlassPreset) -> String {
        switch preset {
        case .visionPro: return "Signature Apple VisionOS frosted glass with crisp specular rims."
        case .pureCrystal: return "Ultra-clear refraction with icy highlight bevels and strong reflection."
        case .deepObsidian: return "Smoked dark glass with subtle perimeter lighting, perfect for dark wallpapers."
        case .warmSunset: return "Subtle amber golden-hour glass cast with luminous rim highlights."
        case .auroraMist: return "Deep ethereal indigo tint with atmospheric backdrop vibrancy."
        case .minimalistGhost: return "Near-invisible high translucency with faint sub-pixel edge."
        }
    }
    
    // Helper Views
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        multiplier: Double
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: 140, alignment: .leading)
            
            Slider(value: value, in: range)
            
            Text(unit == "x" ? String(format: "%.1fx", value.wrappedValue) : "\(Int(value.wrappedValue * multiplier))\(unit)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}
