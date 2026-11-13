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
        .frame(width: 560, height: 530)
    }
    
    // MARK: - Glass & Liquid Tab
    private var glassTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Display Style", subtitle: "Choose between borderless lock screen text or a floating glass card")
            
            Picker("", selection: $settings.displayMode) {
                ForEach(WidgetDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(title: "Text Transparency & Blur Material", subtitle: "Controls backdrop optical blur and see-through translucency inside numbers")
            
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
            
            sectionHeader(title: "Liquid Glass Optics & Refraction", subtitle: "Adjust fluid refraction highlights, specular bevel, and surface reflection")
            
            // Unified Liquid Glass Intensity
            sliderRow(
                title: "Glass Intensity",
                value: $settings.liquidGlassIntensity,
                range: 0.1...1.0,
                unit: "%",
                multiplier: 100
            )
            
            // Liquid Refraction Strength
            sliderRow(
                title: "Refraction Caustics",
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
                title: "Surface Glare Sheen",
                value: $settings.surfaceSheen,
                range: 0.0...1.0,
                unit: "%",
                multiplier: 100
            )
            
            sliderRow(
                title: "Depth Shadow",
                value: $settings.shadowIntensity,
                range: 0.0...1.0,
                unit: "%",
                multiplier: 100
            )
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(title: "Glass Tint Color", subtitle: "Apply a subtle color cast to the liquid glass digits")
            
            HStack {
                Text("Tint Color")
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
            
            if settings.displayMode == .card {
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
            }
        }
    }
    
    // MARK: - Typography Tab
    private var typographyTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Layout & Indicators", subtitle: "Choose between horizontal and stacked Lock Screen layout")
            
            HStack {
                Text("Time Layout")
                    .frame(width: 140, alignment: .leading)
                
                Picker("", selection: $settings.timeLayout) {
                    ForEach(TimeLayout.allCases) { layout in
                        Text(layout.rawValue).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Toggle("24-Hour Time Format", isOn: $settings.is24Hour)
                    .toggleStyle(.checkbox)
                
                Spacer()
                
                Toggle("Show Seconds Ticker", isOn: $settings.showSeconds)
                    .toggleStyle(.checkbox)
            }
            
            HStack {
                Toggle("Show Date Header", isOn: $settings.showDate)
                    .toggleStyle(.checkbox)
                
                Spacer()
                
                if !settings.is24Hour {
                    Toggle("Show AM / PM", isOn: $settings.showAmPm)
                        .toggleStyle(.checkbox)
                }
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(title: "Typeface & Weight", subtitle: "Apple Lock Screen font choices and scaling")
            
            HStack {
                Text("Typeface")
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
                title: "Scale Size",
                value: $settings.clockScale,
                range: 0.7...2.0,
                unit: "x",
                multiplier: 1
            )
        }
    }
    
    // MARK: - Position & Window Tab
    private var positionTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Screen Placement & Dragging", subtitle: "Click and drag the clock anywhere across any screen")
            
            HStack(spacing: 16) {
                Button {
                    settings.onCenterRequested?()
                } label: {
                    Label("Snap to Screen Center", systemImage: "viewfinder")
                }
                .buttonStyle(.borderedProminent)
            }
            
            Toggle("Lock Position (prevent dragging)", isOn: $settings.isLocked)
                .toggleStyle(.checkbox)
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Click-Through Mode (pass clicks to desktop)", isOn: $settings.clickThrough)
                    .toggleStyle(.checkbox)
                
                Text("When enabled, clicks pass through to icons underneath. You can reopen settings from the Menu Bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider().padding(.vertical, 4)
            
            sectionHeader(title: "Window Hierarchy", subtitle: "Choose where the clock sits in macOS layers")
            
            VStack(alignment: .leading, spacing: 10) {
                Picker("Window Layer", selection: $settings.windowLevel) {
                    ForEach(WindowLevelOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text("• Normal: Freely draggable over desktop icons; stays behind other active app windows.\n• Desktop Level: Sits directly on desktop wallpaper.\n• Always On Top: Floats above all open windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Presets Tab
    private var presetsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Curated Glass Presets", subtitle: "One-click designer glassmorphic styles")
            
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
        case .lockScreenClassic: return "Border-free Apple Lock Screen typography with rich frosted liquid glass fill."
        case .visionPro: return "Signature Apple VisionOS frosted glass with crisp specular rims."
        case .pureCrystal: return "Ultra-clear heavy glass refraction with icy specular bevels."
        case .deepObsidian: return "Smoked dark glass with subtle perimeter lighting for dark wallpapers."
        case .warmSunset: return "Subtle amber golden-hour glass cast with luminous rim highlights."
        case .auroraMist: return "Deep ethereal indigo tint with atmospheric backdrop vibrancy."
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
