import SwiftUI

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
        ClockPreview(settings: settings, timeManager: timeManager)

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
        }

        SettingsGroup("Typeface") {
            Row("Font") {
                Picker("", selection: $settings.fontDesign) {
                    ForEach(ClockFontDesign.allCases) { Text($0.shortName).tag($0) }
                }
                // Five options are too wide for a segmented control at macOS 27 sizing
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            RowDivider()
            Row("Weight") {
                Picker("", selection: $settings.fontWeight) {
                    ForEach(ClockFontWeight.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            RowDivider()
            Row("Layout") {
                GlassSegmentedControl(
                    selection: $settings.timeLayout,
                    segments: TimeLayout.allCases.map { GlassSegment(value: $0, title: $0.shortName) }
                )
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

    var body: some View {
        let design = settings.fontDesign.design

        VStack(spacing: 2) {
            if settings.showDate {
                Text(timeManager.dateFormattedString)
                    .font(.system(size: 13, weight: .semibold, design: design))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(timeManager.hoursString):\(timeManager.minutesString)")
                    .font(.system(size: 46, weight: settings.fontWeight.weight, design: design))
                    .contentTransition(.numericText())

                if settings.showSeconds {
                    Text(timeManager.secondsString)
                        .font(.system(size: 17, weight: .medium, design: design))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .transition(.blurReplace)
                }

                if !settings.is24Hour && settings.showAmPm && !timeManager.amPmString.isEmpty {
                    Text(timeManager.amPmString)
                        .font(.system(size: 15, weight: .semibold, design: design))
                        .foregroundStyle(.secondary)
                        .transition(.blurReplace)
                }
            }
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 112)
        .background(GroupBackground())
        .animation(.snappy, value: timeManager.secondsString)
        .animation(.snappy, value: timeManager.amPmString)
        .animation(.snappy, value: timeManager.hoursString)
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

private extension ClockFontDesign {
    var shortName: String {
        switch self {
        case .lockScreen: return "Lock Screen"
        case .rounded: return "Rounded"
        case .system: return "Default"
        case .monospaced: return "Mono"
        case .serif: return "Serif"
        }
    }
}

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
        case .visionPro: return "Vision"
        case .pureCrystal: return "Crystal"
        case .deepObsidian: return "Obsidian"
        case .warmSunset: return "Sunset"
        case .auroraMist: return "Aurora"
        }
    }

    var summary: String {
        switch self {
        case .lockScreenClassic: return "Clear text with a soft white glow"
        case .visionPro: return "Frosted glass card"
        case .pureCrystal: return "Maximum clarity and refraction"
        case .deepObsidian: return "Dark smoked glass card"
        case .warmSunset: return "Warm amber tint"
        case .auroraMist: return "Soft mint tint"
        }
    }

    var swatchHex: String {
        switch self {
        case .lockScreenClassic: return "#F8FAFC"
        case .visionPro: return "#E2E8F0"
        case .pureCrystal: return "#E0F2FE"
        case .deepObsidian: return "#141E28"
        case .warmSunset: return "#FDE68A"
        case .auroraMist: return "#A7F3D0"
        }
    }

    var isCard: Bool { self == .visionPro || self == .deepObsidian }
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
