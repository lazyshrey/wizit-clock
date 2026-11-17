import SwiftUI
import Combine

// MARK: - Settings Window

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var timeManager = TimeManager.shared

    @State private var selectedTab: Tab = .clock
    @State private var direction: CGFloat = 1
    @State private var justApplied: GlassPreset?
    @State private var didReset = false
    @State private var didCenter = false
    @Namespace private var swatchNamespace

    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    enum Tab: Int, CaseIterable, Identifiable {
        case clock, glass, window, presets

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .clock: return "Clock"
            case .glass: return "Glass"
            case .window: return "Window"
            case .presets: return "Presets"
            }
        }

        var icon: String {
            switch self {
            case .clock: return "clock"
            case .glass: return "drop"
            case .window: return "macwindow"
            case .presets: return "sparkles"
            }
        }
    }

    static let windowSize = CGSize(width: 560, height: 640)
    private static let contentInset: CGFloat = 24
    private let tabAnimation = Animation.snappy(duration: 0.32, extraBounce: 0.04)

    public var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                ScrollView {
                    tabContent(selectedTab)
                        // Hard width so no control can ever push the page wider than the window
                        .frame(width: Self.windowSize.width - Self.contentInset * 2)
                        .padding(.horizontal, Self.contentInset)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                }
                .scrollIndicators(.never)
                .id(selectedTab)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 18 * direction)),
                        removal: .opacity.combined(with: .offset(x: -18 * direction))
                    )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        // Content stays inside the safe area: the title bar swallows clicks, so nothing
        // interactive may sit under it. The background still extends behind it.
        .background(Palette.window)
        .onChange(of: settings.is24Hour) { timeManager.updateTime() }
        .onChange(of: settings.showSeconds) { timeManager.updateTime() }
    }

    // MARK: Header

    /// Liquid Glass icon bar. Selection goes through a binding so the page
    /// transition knows which way to slide.
    private var header: some View {
        GlassSegmentedControl(
            selection: tabBinding,
            segments: Tab.allCases.map { GlassSegment(value: $0, title: $0.title, icon: $0.icon) },
            style: .icons
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 12)
    }

    private var tabBinding: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { tab in
                guard tab != selectedTab else { return }
                direction = tab.rawValue > selectedTab.rawValue ? 1 : -1
                withAnimation(tabAnimation) { selectedTab = tab }
            }
        )
    }

    @ViewBuilder
    private func tabContent(_ tab: Tab) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            switch tab {
            case .clock: clockTab
            case .glass: glassTab
            case .window: windowTab
            case .presets: presetsTab
            }
        }
    }

    // MARK: Clock

    @ViewBuilder
    private var clockTab: some View {
        SettingsGroup("Preview") {
            ClockPreview(settings: settings, timeManager: timeManager)
        }

        SettingsGroup("macOS Lock Screen Styles") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LockScreenClockStyle.allCases) { style in
                        ClockStyleCard(
                            style: style,
                            isSelected: settings.clockStyle == style,
                            settings: settings,
                            onSelect: {
                                withAnimation(.snappy) {
                                    settings.applyClockStyle(style)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }

        SettingsGroup("Font & Color") {
            // Horizontal row of 12 buttons (matching Apple Lock Screen customizer)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ClockFontDesign.allCases) { design in
                        LockScreenFontButton(
                            design: design,
                            isSelected: settings.fontDesign == design,
                            settings: settings,
                            onSelect: {
                                withAnimation(.snappy) {
                                    settings.fontDesign = design
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            
            RowDivider()
            
            // Continuous weight slider
            SliderRow("Weight", value: fontWeightSliderBinding, in: 0...6)
            
            RowDivider()
            
            // Color Swatches
            HStack(spacing: 8) {
                ForEach(Swatch.all) { swatch in
                    swatchButton(swatch)
                }
                Spacer(minLength: 8)
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(width: 1, height: 18)
                    .padding(.horizontal, 4)
                ColorPicker("", selection: customTintBinding, supportsOpacity: false)
                    .labelsHidden()
                    .help("Custom color")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            
            RowDivider()
            
            Row("Style") {
                GlassSegmentedControl(
                    selection: glassVsSolidBinding,
                    segments: [
                        GlassSegment(value: true, title: "Glass"),
                        GlassSegment(value: false, title: "Solid")
                    ]
                )
            }
            
            RowDivider()
            
            Row("Layout") {
                GlassSegmentedControl(
                    selection: $settings.timeLayout,
                    segments: TimeLayout.allCases.map { GlassSegment(value: $0, title: $0.shortName) }
                )
            }
        }

        SettingsGroup("Format") {
            ToggleRow("24-hour time", isOn: $settings.is24Hour.animation(.snappy))
            if !settings.is24Hour {
                RowDivider()
                ToggleRow("Show AM/PM", isOn: $settings.showAmPm.animation(.snappy))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            RowDivider()
            ToggleRow("Show seconds", isOn: $settings.showSeconds.animation(.snappy))
            RowDivider()
            ToggleRow("Show date", isOn: $settings.showDate.animation(.snappy))
            RowDivider()
            Row("Numerals") {
                Picker("", selection: $settings.numeralSystem) {
                    ForEach(NumeralSystem.allCases) { Text($0.shortName).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
        }

        SettingsGroup("Number animation") {
            DigitAnimationPreview(settings: settings)
            RowDivider()
            Row("Style") {
                GlassSegmentedControl(
                    selection: $settings.digitAnimationStyle.animation(.snappy),
                    segments: DigitAnimationStyle.allCases.map { GlassSegment(value: $0, title: $0.title) }
                )
            }
            if settings.digitAnimationStyle != .off {
                Group {
                    RowDivider()
                    ToggleRow("Motion blur", subtitle: "Digits blur while they move", isOn: $settings.digitBlurEnabled.animation(.snappy))
                    if settings.digitBlurEnabled {
                        RowDivider()
                        SliderRow("Blur", value: $settings.digitBlurAmount, in: 0.1...1)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if settings.digitAnimationStyle != .pop {
                        RowDivider()
                        SliderRow("Travel", value: $settings.digitTravel, in: 0...2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    RowDivider()
                    SliderRow("Bounce", value: $settings.digitBounce, in: 0...1)
                    RowDivider()
                    SliderRow("Speed", value: $settings.digitSpeed, in: 0.5...2)
                    RowDivider()
                    ToggleRow("Cascade", subtitle: "Ones digit first, then tens, like an odometer", isOn: $settings.digitCascade)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }

        SettingsGroup("Size") {
            SliderRow("Scale", value: $settings.clockScale, in: 0.45...1.5)
            RowDivider()
            SliderRow("Height", value: $settings.clockHeightRatio, in: 0.65...1.85)
        }
    }

    // MARK: Glass

    @ViewBuilder
    private var glassTab: some View {
        SettingsGroup("Style") {
            Row("Material") {
                GlassSegmentedControl(
                    selection: $settings.glassVariant,
                    segments: LiquidGlassVariant.allCases.map { GlassSegment(value: $0, title: $0.shortName) }
                )
            }
            RowDivider()
            Row("Container") {
                GlassSegmentedControl(
                    selection: $settings.displayMode,
                    segments: WidgetDisplayMode.allCases.map { GlassSegment(value: $0, title: $0.shortName) }
                )
            }
        }

        SettingsGroup("Tint") {
            HStack(spacing: 6) {
                ForEach(Swatch.all) { swatch in
                    swatchButton(swatch)
                }
                Spacer(minLength: 8)
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(width: 1, height: 18)
                    .padding(.horizontal, 6)
                ColorPicker("", selection: customTintBinding, supportsOpacity: false)
                    .labelsHidden()
                    .help("Custom color")
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
        }

        SettingsGroup("Optics") {
            SliderRow("Opacity", value: $settings.glassOpacity, in: 0...0.85)
            RowDivider()
            SliderRow("Refraction", value: $settings.liquidGlassIntensity, in: 0.1...1)
            RowDivider()
            SliderRow("Rim light", value: $settings.rimLightIntensity, in: 0...1)
            RowDivider()
            SliderRow("Sheen", value: $settings.surfaceSheen, in: 0...1)
            RowDivider()
            SliderRow("Shadow", value: $settings.shadowIntensity, in: 0...1)
        }
    }

    private func swatchButton(_ swatch: Swatch) -> some View {
        let isSelected = settings.tintColorHex.uppercased() == swatch.hex
        return Button {
            withAnimation(.snappy(duration: 0.28)) { settings.tintColorHex = swatch.hex }
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .matchedGeometryEffect(id: "ring", in: swatchNamespace)
                }
                Circle()
                    .fill(swatch.color)
                    .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
                    .padding(5)
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(swatch.name)
    }

    private var customTintBinding: Binding<Color> {
        Binding(
            get: { Color(hex: settings.tintColorHex) },
            set: { newColor in
                if let hex = newColor.toHex() {
                    withAnimation(.snappy(duration: 0.28)) { settings.tintColorHex = hex }
                }
            }
        )
    }

    private var fontWeightSliderBinding: Binding<Double> {
        Binding<Double>(
            get: {
                switch settings.fontWeight {
                case .ultraLight: return 0
                case .light: return 1
                case .regular: return 2
                case .medium: return 3
                case .semibold: return 4
                case .bold: return 5
                case .heavy: return 6
                }
            },
            set: { val in
                let idx = Int(round(val))
                let weights: [ClockFontWeight] = [.ultraLight, .light, .regular, .medium, .semibold, .bold, .heavy]
                if idx >= 0 && idx < weights.count {
                    settings.fontWeight = weights[idx]
                }
            }
        )
    }

    private var glassVsSolidBinding: Binding<Bool> {
        Binding<Bool>(
            get: { settings.liquidGlassIntensity > 0.35 },
            set: { isGlass in
                withAnimation(.snappy) {
                    if isGlass {
                        settings.liquidGlassIntensity = 0.85
                        settings.rimLightIntensity = 0.90
                        settings.surfaceSheen = 0.60
                        settings.glassOpacity = 0.0
                    } else {
                        settings.liquidGlassIntensity = 0.15
                        settings.rimLightIntensity = 0.20
                        settings.surfaceSheen = 0.10
                        settings.glassOpacity = 0.85
                    }
                }
            }
        )
    }

    // MARK: Window

    @ViewBuilder
    private var windowTab: some View {
        SettingsGroup("Position") {
            ToggleRow(
                "Move clock",
                subtitle: settings.isEditMode ? "Drag the clock anywhere on your desktop" : "Position is locked",
                isOn: $settings.isEditMode.animation(.snappy)
            )
            RowDivider()
            Row("Center under notch") {
                Button {
                    settings.onCenterRequested?()
                    flash($didCenter)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: didCenter ? "checkmark" : "viewfinder")
                            .contentTransition(.symbolEffect(.replace))
                        Text("Center")
                    }
                    .frame(minWidth: 64)
                }
                .controlSize(.small)
            }
        }

        SettingsGroup("Layer") {
            Row("Show clock") {
                GlassSegmentedControl(
                    selection: windowLayerBinding,
                    segments: [
                        GlassSegment(value: WindowLevelOption.desktop, title: "Behind windows"),
                        GlassSegment(value: WindowLevelOption.floating, title: "Always on top")
                    ]
                )
            }
        }

        SettingsGroup("System") {
            ToggleRow("Open at login", isOn: $settings.launchAtStartup)
        }
    }

    /// `.desktop` and `.normal` behave identically, so only two choices are shown.
    private var windowLayerBinding: Binding<WindowLevelOption> {
        Binding(
            get: { settings.windowLevel == .floating ? .floating : .desktop },
            set: { settings.windowLevel = $0 }
        )
    }

    // MARK: Presets

    @ViewBuilder
    private var presetsTab: some View {
        SettingsGroup("Presets") {
            ForEach(Array(GlassPreset.allCases.enumerated()), id: \.element) { index, preset in
                if index > 0 { RowDivider(inset: 50) }
                presetRow(preset)
            }
        }

        HStack {
            Spacer()
            Button {
                withAnimation(.snappy) { settings.resetToDefaults() }
                flash($didReset)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: didReset ? "checkmark" : "arrow.counterclockwise")
                        .contentTransition(.symbolEffect(.replace))
                    Text(didReset ? "Restored" : "Restore defaults")
                        .contentTransition(.interpolate)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func presetRow(_ preset: GlassPreset) -> some View {
        Button {
            withAnimation(.snappy) {
                settings.applyPreset(preset)
                justApplied = preset
            }
            let applied = preset
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                if justApplied == applied {
                    withAnimation(.snappy) { justApplied = nil }
                }
            }
        } label: {
            HoverHighlight {
                HStack(spacing: 12) {
                    PresetSwatch(preset: preset)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(preset.shortName)
                            .font(.system(size: 13))
                        Text(preset.summary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if justApplied == preset {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .transition(.blurReplace)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 50)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    /// Briefly flips a flag to show a confirmation state, then animates it back.
    private func flash(_ flag: Binding<Bool>) {
        withAnimation(.snappy) { flag.wrappedValue = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.snappy) { flag.wrappedValue = false }
        }
    }
}

// MARK: - Live Clock Preview

private struct ClockPreview: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var timeManager: TimeManager
    @State private var testOffset: Int = 0

    private var displayMinutes: String {
        if testOffset == 0 {
            return timeManager.minutesString
        }
        let base = Int(timeManager.minutesString) ?? 0
        let val = (base + testOffset) % 60
        return settings.numeralSystem.format(String(format: "%02d", val))
    }

    var body: some View {
        let digitSize: CGFloat = settings.timeLayout == .stacked ? 36 : 46
        let pmWidth: CGFloat = (!settings.is24Hour && settings.showAmPm) ? 28 : 0

        ZStack(alignment: .topTrailing) {
            // Optional Card surface preview if user chose Card mode
            if settings.displayMode == .card {
                LiquidGlassSurface(settings: settings)
                    .padding(8)
            }

            VStack(spacing: settings.timeLayout == .stacked ? -6 : 2) {
                // 1. Date Header (Matches desktop widget with real glass)
                if settings.showDate {
                    LiquidGlassText(
                        timeManager.dateFormattedString,
                        fontSize: 13,
                        weight: .bold,
                        design: settings.fontDesign,
                        settings: settings
                    )
                    .padding(.bottom, 2)
                }

                // 2. Time Digits (True optical glass with digit transition animations)
                if settings.timeLayout == .stacked {
                    VStack(spacing: -8) {
                        GlyphixGlassText(
                            text: timeManager.hoursString,
                            fontSize: digitSize,
                            weight: settings.fontWeight.weight,
                            heightRatio: settings.clockHeightRatio,
                            minimumSlots: 2,
                            baseDelay: 2 * GlyphixCurve.stagger(settings),
                            settings: settings
                        )
                        GlyphixGlassText(
                            text: displayMinutes,
                            fontSize: digitSize,
                            weight: settings.fontWeight.weight,
                            heightRatio: settings.clockHeightRatio,
                            settings: settings
                        )
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 0) {
                        // Balance spacer matching PM width (keeps digits dead center)
                        if pmWidth > 0 {
                            Color.clear
                                .frame(width: pmWidth, height: 1)
                        }

                        GlyphixGlassText(
                            text: "\(timeManager.hoursString):\(displayMinutes)",
                            fontSize: digitSize,
                            weight: settings.fontWeight.weight,
                            heightRatio: settings.clockHeightRatio,
                            colonSpacing: 4,
                            minimumSlots: 5,
                            settings: settings
                        )

                        if pmWidth > 0 || settings.showSeconds {
                            VStack(alignment: .leading, spacing: 1) {
                                if !settings.is24Hour && settings.showAmPm && !timeManager.amPmString.isEmpty {
                                    LiquidGlassText(
                                        timeManager.amPmString,
                                        fontSize: 12,
                                        weight: .bold,
                                        design: settings.fontDesign,
                                        heightRatio: 1.0,
                                        settings: settings
                                    )
                                    .padding(.leading, 4)
                                    .padding(.bottom, 6)
                                }

                                if settings.showSeconds {
                                    GlyphixGlassText(
                                        text: timeManager.secondsString,
                                        fontSize: 12,
                                        weight: .semibold,
                                        heightRatio: 1.0,
                                        minimumSlots: 2,
                                        settings: settings
                                    )
                                    .padding(.leading, 4)
                                    .padding(.bottom, 6)
                                }
                            }
                            .frame(width: pmWidth, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Replay / test button in top trailing corner
            Button {
                testOffset += 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Test digit animation")
        }
        .frame(maxWidth: .infinity)
        .frame(height: settings.timeLayout == .stacked ? 134 : 116)
        .contentShape(Rectangle())
        .onTapGesture {
            testOffset += 1
        }
    }
}

// MARK: - Lock Screen Font Button (The 12 buttons from Lock Screen sheet)

private struct LockScreenFontButton: View {
    let design: ClockFontDesign
    let isSelected: Bool
    @ObservedObject var settings: AppSettings
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                ZStack {
                    LiquidGlassText(
                        "12",
                        fontSize: 24,
                        weight: settings.fontWeight.weight,
                        design: design,
                        heightRatio: 1.0,
                        settings: settings
                    )
                }
                .frame(width: 44, height: 38)
                
                Text(design.shortName)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .frame(width: 60, height: 68)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.18) : (isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.white.opacity(0.85) : (isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.10)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Clock Style Card

private struct ClockStyleCard: View {
    let style: LockScreenClockStyle
    let isSelected: Bool
    @ObservedObject var settings: AppSettings
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                // Typographic sample preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.04))
                    
                    if style == .stencil {
                        LiquidGlassText(
                            "6:31",
                            fontSize: 18,
                            weight: .bold,
                            design: .stencil,
                            heightRatio: 1.0,
                            settings: settings
                        )
                    } else if style == .rails {
                        LiquidGlassText(
                            "6:31",
                            fontSize: 18,
                            weight: .bold,
                            design: .rails,
                            heightRatio: 1.0,
                            settings: settings
                        )
                    } else if style == .futuraBauhaus {
                        LiquidGlassText("10:42", fontSize: 16, weight: .bold, design: .futura, settings: settings)
                    } else if style == .didotLuxury {
                        LiquidGlassText("10:42", fontSize: 16, weight: .bold, design: .didot, settings: settings)
                    } else if style == .dinTechnical {
                        LiquidGlassText("10:42", fontSize: 16, weight: .bold, design: .din, settings: settings)
                    } else if style == .stackedPoster {
                        VStack(spacing: -3) {
                            LiquidGlassText("10", fontSize: 13, weight: .heavy, design: .system, settings: settings)
                            LiquidGlassText("42", fontSize: 13, weight: .heavy, design: .system, settings: settings)
                        }
                    } else if style == .athleticCompact {
                        LiquidGlassText("10:42", fontSize: 16, weight: .bold, design: .compact, heightRatio: 1.25, settings: settings)
                    } else if style == .editorialSerif {
                        LiquidGlassText("10:42", fontSize: 16, weight: .medium, design: .serif, settings: settings)
                    } else if style == .modernSlab {
                        LiquidGlassText("10:42", fontSize: 16, weight: .bold, design: .slabSerif, settings: settings)
                    } else if style == .vintageTypewriter {
                        LiquidGlassText("10:42", fontSize: 15, weight: .bold, design: .typewriter, settings: settings)
                    } else if style == .markerCasual {
                        LiquidGlassText("10:42", fontSize: 15, weight: .bold, design: .handwritten, settings: settings)
                    } else if style == .copperplateGothic {
                        LiquidGlassText("10:42", fontSize: 14, weight: .bold, design: .copperplate, settings: settings)
                    } else if style == .retroMono {
                        LiquidGlassText("10:42", fontSize: 14, weight: .semibold, design: .monospaced, settings: settings)
                    } else if style == .minimalistHairline {
                        LiquidGlassText("10:42", fontSize: 16, weight: .ultraLight, design: .system, settings: settings)
                    } else {
                        LiquidGlassText("10:42", fontSize: 16, weight: .bold, design: .rounded, settings: settings)
                    }
                }
                .frame(width: 84, height: 46)
                
                Text(style.shortName)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(width: 104, height: 86)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : (isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.02)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.65) : (isHovered ? Color.white.opacity(0.20) : Color.white.opacity(0.08)),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Number Animation Preview

/// Plays the clock's digit animation with the current settings. Counts up on its own and can be
/// nudged with the button (jumping by 11 so both digits change and the cascade is visible).
private struct DigitAnimationPreview: View {
    @ObservedObject var settings: AppSettings
    @State private var value = 58

    private let ticker = Timer.publish(every: 1.6, on: .main, in: .common).autoconnect()

    var body: some View {
        Row("Preview", subtitle: "Uses the settings below") {
            HStack(spacing: 12) {
                GlyphixGlassText(
                    text: String(format: "%02d", value),
                    fontSize: 30,
                    weight: settings.fontWeight.weight,
                    heightRatio: 1.0,
                    minimumSlots: 2,
                    settings: settings
                )
                .frame(minWidth: 44)

                Button {
                    value = (value + 11) % 100
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Replay")
            }
        }
        .frame(height: 64)
        .onReceive(ticker) { _ in
            value = (value + 1) % 100
        }
    }
}

// MARK: - Building Blocks

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)

            VStack(spacing: 0) {
                content
            }
            .background(GroupBackground())
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct GroupBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Palette.group)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.5)
            )
    }
}

private struct Row<Accessory: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let accessory: Accessory

    init(_ title: String, subtitle: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .contentTransition(.interpolate)
                }
            }
            Spacer(minLength: 0)
            accessory
        }
        .padding(.horizontal, 12)
        .frame(minHeight: subtitle == nil ? 44 : 52)
    }
}

private struct ToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        Row(title, subtitle: subtitle) {
            // Native AppKit switch at its standard size
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>) {
        self.title = title
        self._value = value
        self.range = range
    }

    var body: some View {
        let percent = Int((value * 100).rounded())

        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13))
                .frame(width: 84, alignment: .leading)

            // Native AppKit slider at its standard size
            Slider(value: $value, in: range) {
                Text(title)
            }
            .labelsHidden()

            Text("\(percent)%")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(percent)))
                .animation(.snappy(duration: 0.2), value: percent)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }
}

private struct RowDivider: View {
    var inset: CGFloat = 12

    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 0.5)
            .padding(.leading, inset)
    }
}

private struct HoverHighlight<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var isHovering = false

    var body: some View {
        content
            .background(Color.primary.opacity(isHovering ? 0.045 : 0))
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct PresetSwatch: View {
    let preset: GlassPreset

    var body: some View {
        let color = Color(hex: preset.swatchHex)
        RoundedRectangle(cornerRadius: preset.isCard ? 7 : 13, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: preset.isCard ? 7 : 13, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
            .frame(width: 26, height: 26)
    }
}

// MARK: - Palette

private enum Palette {
    static let window = Color(nsColor: .windowBackgroundColor)
    static let group = adaptive(light: .white, dark: NSColor.white.withAlphaComponent(0.05))
    static let hairline = Color.primary.opacity(0.08)

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

// MARK: - Tint Swatches

private struct Swatch: Identifiable {
    let name: String
    let hex: String
    var id: String { hex }
    var color: Color { Color(hex: hex) }

    static let all: [Swatch] = [
        Swatch(name: "Clear", hex: "#FFFFFF"),
        Swatch(name: "Ice", hex: "#38BDF8"),
        Swatch(name: "Mint", hex: "#34D399"),
        Swatch(name: "Amber", hex: "#FBBF24"),
        Swatch(name: "Rose", hex: "#F472B6"),
        Swatch(name: "Graphite", hex: "#1E293B")
    ]
}

// MARK: - Display Names
// Raw values are persisted in UserDefaults, so short labels live here instead.

private extension TimeLayout {
    var shortName: String {
        switch self {
        case .horizontal: return "Inline"
        case .stacked: return "Stacked"
        }
    }
}

private extension LiquidGlassVariant {
    var shortName: String {
        switch self {
        case .clear: return "Clear"
        case .regular: return "Vibrant"
        }
    }
}

private extension WidgetDisplayMode {
    var shortName: String {
        switch self {
        case .lockScreen: return "Text only"
        case .card: return "Card"
        }
    }
}

private extension GlassPreset {
    var shortName: String {
        switch self {
        case .lockScreenClassic: return "Frost"
        case .stencilGlass: return "Stencil"
        case .pureCrystal: return "Crystal"
        case .deepObsidian: return "Obsidian"
        case .warmSunset: return "Sunset"
        case .auroraMist: return "Aurora"
        }
    }

    var summary: String {
        switch self {
        case .lockScreenClassic: return "Clear text with a soft white glow"
        case .stencilGlass: return "Segmented stencil glass with sharp cutouts"
        case .pureCrystal: return "Maximum clarity and refraction"
        case .deepObsidian: return "Dark smoked glass"
        case .warmSunset: return "Warm amber tint"
        case .auroraMist: return "Soft mint tint"
        }
    }

    var swatchHex: String {
        switch self {
        case .lockScreenClassic: return "#F8FAFC"
        case .stencilGlass: return "#F1F5F9"
        case .pureCrystal: return "#E0F2FE"
        case .deepObsidian: return "#141E28"
        case .warmSunset: return "#FDE68A"
        case .auroraMist: return "#A7F3D0"
        }
    }

    var isCard: Bool { false }
}

fileprivate extension Color {
    func toHex() -> String? {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
