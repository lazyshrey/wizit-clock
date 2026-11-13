import SwiftUI
import AppKit

// MARK: - Display Mode (Lock Screen Border-Free vs Card)
public enum WidgetDisplayMode: String, CaseIterable, Identifiable, Codable {
    case lockScreen = "Lock Screen (Border-Free Glass Text)"
    case card = "Glass Card Container"
    
    public var id: String { rawValue }
}

// MARK: - Time Layout (Horizontal vs Stacked)
public enum TimeLayout: String, CaseIterable, Identifiable, Codable {
    case horizontal = "Horizontal (10:42)"
    case stacked = "Stacked (10 / 42)"
    
    public var id: String { rawValue }
}

// MARK: - Blur Material Option
public enum GlassMaterialOption: String, CaseIterable, Identifiable, Codable {
    case ultraThin = "Ultra Thin"
    case thin = "Thin"
    case regular = "Regular"
    case thick = "Thick"
    case hud = "HUD Dark"
    case fullScreenUI = "Full Screen"
    
    public var id: String { rawValue }
    
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .ultraThin: return .hudWindow
        case .thin: return .sheet
        case .regular: return .windowBackground
        case .thick: return .underWindowBackground
        case .hud: return .fullScreenUI
        case .fullScreenUI: return .sidebar
        }
    }
}

// MARK: - Font Typography Option
public enum ClockFontDesign: String, CaseIterable, Identifiable, Codable {
    case rounded = "SF Pro Rounded"
    case system = "SF Pro Display"
    case monospaced = "SF Pro Mono"
    case serif = "New York Serif"
    
    public var id: String { rawValue }
    
    var design: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .system: return .default
        case .monospaced: return .monospaced
        case .serif: return .serif
        }
    }
}

// MARK: - Font Weight Option
public enum ClockFontWeight: String, CaseIterable, Identifiable, Codable {
    case ultraLight = "Ultra Light"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    
    public var id: String { rawValue }
    
    var weight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        }
    }
}

// MARK: - Window Level Option
public enum WindowLevelOption: String, CaseIterable, Identifiable, Codable {
    case desktop = "Desktop Level (Behind All Windows)"
    case normal = "Below Normal Windows"
    case floating = "Always On Top (Floating)"
    
    public var id: String { rawValue }
}

// MARK: - Pre-designed Glass Presets
public enum GlassPreset: String, CaseIterable, Identifiable {
    case lockScreenClassic = "Apple Lock Screen Frost"
    case visionPro = "Vision Pro Liquid Glass"
    case pureCrystal = "Pure Refractive Crystal"
    case deepObsidian = "Deep Obsidian Smoked"
    case warmSunset = "Sunset Amber Glow"
    case auroraMist = "Aurora Indigo"
    
    public var id: String { rawValue }
}

// MARK: - AppSettings
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    // Display Style
    @Published public var displayMode: WidgetDisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode")
            onLayoutChanged?()
        }
    }
    @Published public var timeLayout: TimeLayout {
        didSet {
            UserDefaults.standard.set(timeLayout.rawValue, forKey: "timeLayout")
            onLayoutChanged?()
        }
    }
    
    // Glass & Transparency
    @Published public var transparency: Double {
        didSet { UserDefaults.standard.set(transparency, forKey: "transparency") }
    }
    @Published public var glassMaterial: GlassMaterialOption {
        didSet { UserDefaults.standard.set(glassMaterial.rawValue, forKey: "glassMaterial") }
    }
    @Published public var liquidRefraction: Double {
        didSet { UserDefaults.standard.set(liquidRefraction, forKey: "liquidRefraction") }
    }
    @Published public var rimLightIntensity: Double {
        didSet { UserDefaults.standard.set(rimLightIntensity, forKey: "rimLightIntensity") }
    }
    @Published public var surfaceSheen: Double {
        didSet { UserDefaults.standard.set(surfaceSheen, forKey: "surfaceSheen") }
    }
    @Published public var tintColorHex: String {
        didSet { UserDefaults.standard.set(tintColorHex, forKey: "tintColorHex") }
    }
    @Published public var tintOpacity: Double {
        didSet { UserDefaults.standard.set(tintOpacity, forKey: "tintOpacity") }
    }
    @Published public var cornerRadius: Double {
        didSet { UserDefaults.standard.set(cornerRadius, forKey: "cornerRadius") }
    }
    @Published public var glassBorderWidth: Double {
        didSet { UserDefaults.standard.set(glassBorderWidth, forKey: "glassBorderWidth") }
    }
    @Published public var shadowIntensity: Double {
        didSet { UserDefaults.standard.set(shadowIntensity, forKey: "shadowIntensity") }
    }
    
    // Clock & Typography
    @Published public var is24Hour: Bool {
        didSet {
            UserDefaults.standard.set(is24Hour, forKey: "is24Hour")
            onLayoutChanged?()
        }
    }
    @Published public var showSeconds: Bool {
        didSet {
            UserDefaults.standard.set(showSeconds, forKey: "showSeconds")
            onLayoutChanged?()
        }
    }
    @Published public var fontDesign: ClockFontDesign {
        didSet { UserDefaults.standard.set(fontDesign.rawValue, forKey: "fontDesign") }
    }
    @Published public var fontWeight: ClockFontWeight {
        didSet { UserDefaults.standard.set(fontWeight.rawValue, forKey: "fontWeight") }
    }
    @Published public var clockScale: Double {
        didSet {
            UserDefaults.standard.set(clockScale, forKey: "clockScale")
            onLayoutChanged?()
        }
    }
    @Published public var showDate: Bool {
        didSet {
            UserDefaults.standard.set(showDate, forKey: "showDate")
            onLayoutChanged?()
        }
    }
    @Published public var showAmPm: Bool {
        didSet {
            UserDefaults.standard.set(showAmPm, forKey: "showAmPm")
            onLayoutChanged?()
        }
    }
    
    // Window & Behavior
    @Published public var windowLevel: WindowLevelOption {
        didSet {
            UserDefaults.standard.set(windowLevel.rawValue, forKey: "windowLevel")
            onWindowLevelChanged?(windowLevel)
        }
    }
    @Published public var isLocked: Bool {
        didSet { UserDefaults.standard.set(isLocked, forKey: "isLocked") }
    }
    @Published public var clickThrough: Bool {
        didSet {
            UserDefaults.standard.set(clickThrough, forKey: "clickThrough")
            onClickThroughChanged?(clickThrough)
        }
    }
    @Published public var windowPositionX: Double {
        didSet { UserDefaults.standard.set(windowPositionX, forKey: "windowPositionX") }
    }
    @Published public var windowPositionY: Double {
        didSet { UserDefaults.standard.set(windowPositionY, forKey: "windowPositionY") }
    }
    
    // Callbacks for AppKit synchronization
    public var onWindowLevelChanged: ((WindowLevelOption) -> Void)?
    public var onClickThroughChanged: ((Bool) -> Void)?
    public var onCenterRequested: (() -> Void)?
    public var onLayoutChanged: (() -> Void)?
    
    private init() {
        let defaults = UserDefaults.standard
        
        // Default to borderless lock screen text
        self.displayMode = WidgetDisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .lockScreen
        self.timeLayout = TimeLayout(rawValue: defaults.string(forKey: "timeLayout") ?? "") ?? .horizontal
        
        self.transparency = defaults.object(forKey: "transparency") != nil ? defaults.double(forKey: "transparency") : 0.30
        self.glassMaterial = GlassMaterialOption(rawValue: defaults.string(forKey: "glassMaterial") ?? "") ?? .ultraThin
        self.liquidRefraction = defaults.object(forKey: "liquidRefraction") != nil ? defaults.double(forKey: "liquidRefraction") : 0.75
        self.rimLightIntensity = defaults.object(forKey: "rimLightIntensity") != nil ? defaults.double(forKey: "rimLightIntensity") : 0.85
        self.surfaceSheen = defaults.object(forKey: "surfaceSheen") != nil ? defaults.double(forKey: "surfaceSheen") : 0.50
        self.tintColorHex = defaults.string(forKey: "tintColorHex") ?? "#C8D4E2"
        self.tintOpacity = defaults.object(forKey: "tintOpacity") != nil ? defaults.double(forKey: "tintOpacity") : 0.20
        self.cornerRadius = defaults.object(forKey: "cornerRadius") != nil ? defaults.double(forKey: "cornerRadius") : 38.0
        self.glassBorderWidth = defaults.object(forKey: "glassBorderWidth") != nil ? defaults.double(forKey: "glassBorderWidth") : 1.2
        self.shadowIntensity = defaults.object(forKey: "shadowIntensity") != nil ? defaults.double(forKey: "shadowIntensity") : 0.65
        
        self.is24Hour = defaults.bool(forKey: "is24Hour")
        self.showSeconds = defaults.object(forKey: "showSeconds") != nil ? defaults.bool(forKey: "showSeconds") : false
        self.fontDesign = ClockFontDesign(rawValue: defaults.string(forKey: "fontDesign") ?? "") ?? .rounded
        self.fontWeight = ClockFontWeight(rawValue: defaults.string(forKey: "fontWeight") ?? "") ?? .heavy
        self.clockScale = defaults.object(forKey: "clockScale") != nil ? defaults.double(forKey: "clockScale") : 1.25
        self.showDate = defaults.object(forKey: "showDate") != nil ? defaults.bool(forKey: "showDate") : true
        self.showAmPm = defaults.object(forKey: "showAmPm") != nil ? defaults.bool(forKey: "showAmPm") : true
        
        self.windowLevel = WindowLevelOption(rawValue: defaults.string(forKey: "windowLevel") ?? "") ?? .desktop
        self.isLocked = defaults.bool(forKey: "isLocked")
        self.clickThrough = defaults.bool(forKey: "clickThrough")
        self.windowPositionX = defaults.double(forKey: "windowPositionX")
        self.windowPositionY = defaults.double(forKey: "windowPositionY")
    }
    
    // Apply curated preset
    public func applyPreset(_ preset: GlassPreset) {
        switch preset {
        case .lockScreenClassic:
            displayMode = .lockScreen
            transparency = 0.25
            glassMaterial = .ultraThin
            liquidRefraction = 0.80
            rimLightIntensity = 1.0
            surfaceSheen = 0.55
            tintColorHex = "#C8D4E2"
            tintOpacity = 0.20
            fontWeight = .heavy
            fontDesign = .rounded
            shadowIntensity = 0.65
            showSeconds = false
            showAmPm = true
            
        case .visionPro:
            transparency = 0.35
            glassMaterial = .ultraThin
            liquidRefraction = 0.70
            rimLightIntensity = 0.85
            surfaceSheen = 0.45
            tintColorHex = "#FFFFFF"
            tintOpacity = 0.15
            cornerRadius = 38
            glassBorderWidth = 1.3
            shadowIntensity = 0.55
            
        case .pureCrystal:
            transparency = 0.18
            glassMaterial = .thin
            liquidRefraction = 0.90
            rimLightIntensity = 0.98
            surfaceSheen = 0.70
            tintColorHex = "#E0F2FE"
            tintOpacity = 0.20
            fontWeight = .heavy
            shadowIntensity = 0.50
            
        case .deepObsidian:
            transparency = 0.55
            glassMaterial = .hud
            liquidRefraction = 0.50
            rimLightIntensity = 0.40
            surfaceSheen = 0.30
            tintColorHex = "#1E293B"
            tintOpacity = 0.40
            shadowIntensity = 0.80
            
        case .warmSunset:
            transparency = 0.30
            glassMaterial = .ultraThin
            liquidRefraction = 0.75
            rimLightIntensity = 0.85
            surfaceSheen = 0.50
            tintColorHex = "#F59E0B"
            tintOpacity = 0.25
            shadowIntensity = 0.55
            
        case .auroraMist:
            transparency = 0.35
            glassMaterial = .thick
            liquidRefraction = 0.85
            rimLightIntensity = 0.85
            surfaceSheen = 0.45
            tintColorHex = "#818CF8"
            tintOpacity = 0.28
            shadowIntensity = 0.65
        }
    }
    
    public func resetToDefaults() {
        applyPreset(.lockScreenClassic)
        is24Hour = false
        showSeconds = false
        fontDesign = .rounded
        fontWeight = .bold
        clockScale = 1.25
        showDate = true
        showAmPm = true
        windowLevel = .normal
        isLocked = false
        clickThrough = false
    }
}
