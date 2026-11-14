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

// MARK: - Liquid Glass Variant
public enum LiquidGlassVariant: String, CaseIterable, Identifiable, Codable {
    case clear = "Clear Glass"
    case regular = "Vibrant Glass"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .clear: return "100% transparent crystal with optical caustics"
        case .regular: return "High-vibrancy optical liquid glass refraction"
        }
    }
}

// MARK: - Font Typography Option
public enum ClockFontDesign: String, CaseIterable, Identifiable, Codable {
    case lockScreen = "macOS 27 Lock Screen"
    case rounded = "SF Pro Rounded"
    case system = "SF Pro Display"
    case monospaced = "SF Pro Mono"
    case serif = "New York Serif"
    
    public var id: String { rawValue }
    
    var design: Font.Design {
        switch self {
        case .lockScreen: return .rounded
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

// MARK: - Digit Animation Style
public enum DigitAnimationStyle: String, CaseIterable, Identifiable, Codable {
    /// New digit rises in from below and grows; old one floats up and shrinks
    case rise
    /// Odometer-style: digits slide straight up at full size
    case roll
    /// Digits scale in place and crossfade
    case pop
    /// No animation
    case off

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rise: return "Rise"
        case .roll: return "Roll"
        case .pop: return "Pop"
        case .off: return "Off"
        }
    }
}

// MARK: - Window Level Option
public enum WindowLevelOption: String, CaseIterable, Identifiable, Codable {
    case desktop = "Desktop Level (Behind All Windows)"
    case normal = "Normal Window"
    case floating = "Always On Top (Floating)"
    
    public var id: String { rawValue }
}

// MARK: - Pre-designed Glass Presets
public enum GlassPreset: String, CaseIterable, Identifiable {
    case lockScreenClassic = "Apple Lock Screen Frost"
    case visionPro = "Vision Pro Liquid Glass"
    case pureCrystal = "Pure Refractive Crystal"
    case deepObsidian = "Deep Obsidian Glass"
    case warmSunset = "Warm Sunset Glow"
    case auroraMist = "Aurora Atmospheric Mist"
    
    public var id: String { rawValue }
}

// MARK: - AppSettings Observable Model
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    // Edit & Reposition Mode
    @Published public var isEditMode: Bool = false {
        didSet {
            onEditModeChanged?(isEditMode)
        }
    }
    
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
    
    // Liquid Glass Optics
    @Published public var glassVariant: LiquidGlassVariant {
        didSet { UserDefaults.standard.set(glassVariant.rawValue, forKey: "glassVariant") }
    }
    @Published public var liquidGlassIntensity: Double {
        didSet {
            UserDefaults.standard.set(liquidGlassIntensity, forKey: "liquidGlassIntensity")
            self.liquidRefraction = liquidGlassIntensity
        }
    }
    @Published public var transparency: Double {
        didSet { UserDefaults.standard.set(transparency, forKey: "transparency") }
    }
    @Published public var glassOpacity: Double {
        didSet { UserDefaults.standard.set(glassOpacity, forKey: "glassOpacity") }
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
    // Live interactive resizing state (suppresses window repositioning during active drags)
    @Published public var isResizing: Bool = false
    
    @Published public var clockScale: Double {
        didSet {
            UserDefaults.standard.set(clockScale, forKey: "clockScale")
            if !isResizing {
                onLayoutChanged?()
            }
        }
    }
    @Published public var clockHeightRatio: Double {
        didSet {
            UserDefaults.standard.set(clockHeightRatio, forKey: "clockHeightRatio")
            if !isResizing {
                onLayoutChanged?()
            }
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
    
    // Number Animation
    @Published public var digitAnimationStyle: DigitAnimationStyle {
        didSet { UserDefaults.standard.set(digitAnimationStyle.rawValue, forKey: "digitAnimationStyle") }
    }
    @Published public var digitBlurEnabled: Bool {
        didSet { UserDefaults.standard.set(digitBlurEnabled, forKey: "digitBlurEnabled") }
    }
    /// 0...1, scales the blur radius of a glyph while it moves
    @Published public var digitBlurAmount: Double {
        didSet { UserDefaults.standard.set(digitBlurAmount, forKey: "digitBlurAmount") }
    }
    /// 0...1, 0 = no overshoot, 1 = very springy
    @Published public var digitBounce: Double {
        didSet { UserDefaults.standard.set(digitBounce, forKey: "digitBounce") }
    }
    /// 0...2, multiplier on how far digits travel vertically (100% = the style's default distance)
    @Published public var digitTravel: Double {
        didSet { UserDefaults.standard.set(digitTravel, forKey: "digitTravel") }
    }
    /// 0.5...2, multiplier on animation speed
    @Published public var digitSpeed: Double {
        didSet { UserDefaults.standard.set(digitSpeed, forKey: "digitSpeed") }
    }
    /// Changed digits roll one after another (ones first) instead of together
    @Published public var digitCascade: Bool {
        didSet { UserDefaults.standard.set(digitCascade, forKey: "digitCascade") }
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
    
    // Launch at Startup
    @Published public var launchAtStartup: Bool {
        didSet {
            LaunchAtLoginManager.shared.isEnabled = launchAtStartup
        }
    }
    
    // Callbacks for AppKit synchronization
    public var onWindowLevelChanged: ((WindowLevelOption) -> Void)?
    public var onClickThroughChanged: ((Bool) -> Void)?
    public var onCenterRequested: (() -> Void)?
    public var onLayoutChanged: (() -> Void)?
    public var onEditModeChanged: ((Bool) -> Void)?
    
    private init() {
        let defaults = UserDefaults.standard
        
        self.displayMode = WidgetDisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .lockScreen
        self.timeLayout = TimeLayout(rawValue: defaults.string(forKey: "timeLayout") ?? "") ?? .horizontal
        
        let rawVariant = defaults.string(forKey: "glassVariant") ?? ""
        if rawVariant.contains("Regular") || rawVariant.contains("Vibrant") {
            self.glassVariant = .regular
        } else {
            self.glassVariant = .clear
        }
        self.liquidGlassIntensity = defaults.object(forKey: "liquidGlassIntensity") != nil ? defaults.double(forKey: "liquidGlassIntensity") : 0.85
        self.transparency = defaults.object(forKey: "transparency") != nil ? defaults.double(forKey: "transparency") : 0.35
        self.glassOpacity = defaults.object(forKey: "glassOpacity") != nil ? defaults.double(forKey: "glassOpacity") : 0.0
        self.glassMaterial = GlassMaterialOption(rawValue: defaults.string(forKey: "glassMaterial") ?? "") ?? .ultraThin
        self.liquidRefraction = defaults.object(forKey: "liquidRefraction") != nil ? defaults.double(forKey: "liquidRefraction") : 0.85
        self.rimLightIntensity = defaults.object(forKey: "rimLightIntensity") != nil ? defaults.double(forKey: "rimLightIntensity") : 0.90
        self.surfaceSheen = defaults.object(forKey: "surfaceSheen") != nil ? defaults.double(forKey: "surfaceSheen") : 0.60
        
        // Sanitize tint: ensure pure white default so wallpaper shines through cleanly
        let rawTint = defaults.string(forKey: "tintColorHex")
        if rawTint == nil || rawTint == "#C8D4E2" {
            self.tintColorHex = "#FFFFFF"
        } else {
            self.tintColorHex = rawTint ?? "#FFFFFF"
        }
        
        self.tintOpacity = defaults.object(forKey: "tintOpacity") != nil ? defaults.double(forKey: "tintOpacity") : 0.15
        self.cornerRadius = defaults.object(forKey: "cornerRadius") != nil ? defaults.double(forKey: "cornerRadius") : 38.0
        self.glassBorderWidth = defaults.object(forKey: "glassBorderWidth") != nil ? defaults.double(forKey: "glassBorderWidth") : 1.2
        self.shadowIntensity = defaults.object(forKey: "shadowIntensity") != nil ? defaults.double(forKey: "shadowIntensity") : 0.45
        
        self.is24Hour = defaults.bool(forKey: "is24Hour")
        self.showSeconds = defaults.object(forKey: "showSeconds") != nil ? defaults.bool(forKey: "showSeconds") : false
        let rawFont = defaults.string(forKey: "fontDesign")
        if rawFont == nil || rawFont == "SF Pro Rounded" {
            self.fontDesign = .lockScreen
        } else {
            self.fontDesign = ClockFontDesign(rawValue: rawFont ?? "") ?? .lockScreen
        }
        
        // Sanitize weight: lock screen default is Semibold matching native macOS 27 lockscreen
        let rawWeight = defaults.string(forKey: "fontWeight")
        if rawWeight == nil || rawWeight == "Heavy" || rawWeight == "Bold" {
            self.fontWeight = .semibold
        } else {
            self.fontWeight = ClockFontWeight(rawValue: rawWeight ?? "") ?? .semibold
        }
        
        // Saved scale & height ratio persistence
        let storedScale = defaults.double(forKey: "clockScale")
        if storedScale >= 0.45 && storedScale <= 1.85 {
            self.clockScale = storedScale
        } else {
            self.clockScale = 0.85
        }
        
        let storedHeightRatio = defaults.double(forKey: "clockHeightRatio")
        if storedHeightRatio >= 0.65 && storedHeightRatio <= 2.0 {
            self.clockHeightRatio = storedHeightRatio
        } else {
            self.clockHeightRatio = 1.0
        }
        
        self.showDate = defaults.object(forKey: "showDate") != nil ? defaults.bool(forKey: "showDate") : true
        self.showAmPm = defaults.object(forKey: "showAmPm") != nil ? defaults.bool(forKey: "showAmPm") : true
        self.launchAtStartup = LaunchAtLoginManager.shared.isEnabled
        
        self.digitAnimationStyle = DigitAnimationStyle(rawValue: defaults.string(forKey: "digitAnimationStyle") ?? "") ?? .rise
        self.digitBlurEnabled = defaults.object(forKey: "digitBlurEnabled") != nil ? defaults.bool(forKey: "digitBlurEnabled") : true
        self.digitBlurAmount = defaults.object(forKey: "digitBlurAmount") != nil ? defaults.double(forKey: "digitBlurAmount") : 0.5
        self.digitBounce = defaults.object(forKey: "digitBounce") != nil ? defaults.double(forKey: "digitBounce") : 0.5
        self.digitTravel = defaults.object(forKey: "digitTravel") != nil ? defaults.double(forKey: "digitTravel") : 1.0
        self.digitSpeed = defaults.object(forKey: "digitSpeed") != nil ? defaults.double(forKey: "digitSpeed") : 1.0
        self.digitCascade = defaults.object(forKey: "digitCascade") != nil ? defaults.bool(forKey: "digitCascade") : true

        self.windowLevel = .desktop
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
            liquidGlassIntensity = 0.85
            transparency = 0.35
            glassMaterial = .ultraThin
            liquidRefraction = 0.85
            rimLightIntensity = 0.90
            surfaceSheen = 0.60
            tintColorHex = "#FFFFFF"
            tintOpacity = 0.15
            fontWeight = .bold
            fontDesign = .rounded
            shadowIntensity = 0.45
            showSeconds = false
            clockScale = 0.85
            
        case .visionPro:
            displayMode = .card
            liquidGlassIntensity = 0.75
            transparency = 0.35
            glassMaterial = .ultraThin
            liquidRefraction = 0.70
            rimLightIntensity = 0.85
            surfaceSheen = 0.45
            tintColorHex = "#FFFFFF"
            tintOpacity = 0.15
            cornerRadius = 38
            glassBorderWidth = 1.3
            shadowIntensity = 0.50
            
        case .pureCrystal:
            displayMode = .lockScreen
            liquidGlassIntensity = 1.0
            transparency = 0.55
            glassMaterial = .thin
            liquidRefraction = 0.95
            rimLightIntensity = 1.0
            surfaceSheen = 0.80
            tintColorHex = "#FFFFFF"
            tintOpacity = 0.15
            fontWeight = .bold
            shadowIntensity = 0.40
            
        case .deepObsidian:
            displayMode = .card
            liquidGlassIntensity = 0.50
            transparency = 0.25
            glassMaterial = .hud
            liquidRefraction = 0.50
            rimLightIntensity = 0.60
            surfaceSheen = 0.35
            tintColorHex = "#141E28"
            tintOpacity = 0.65
            cornerRadius = 32
            glassBorderWidth = 1.0
            shadowIntensity = 0.60
            
        case .warmSunset:
            displayMode = .lockScreen
            liquidGlassIntensity = 0.85
            transparency = 0.35
            glassMaterial = .ultraThin
            liquidRefraction = 0.80
            rimLightIntensity = 0.90
            surfaceSheen = 0.60
            tintColorHex = "#FDE68A"
            tintOpacity = 0.30
            fontWeight = .bold
            shadowIntensity = 0.45
            
        case .auroraMist:
            displayMode = .lockScreen
            liquidGlassIntensity = 0.90
            transparency = 0.40
            glassMaterial = .thin
            liquidRefraction = 0.85
            rimLightIntensity = 0.95
            surfaceSheen = 0.70
            tintColorHex = "#A7F3D0"
            tintOpacity = 0.25
            fontWeight = .bold
            shadowIntensity = 0.45
        }
    }
    
    public func resetToDefaults() {
        displayMode = .lockScreen
        timeLayout = .horizontal
        liquidGlassIntensity = 0.85
        transparency = 0.35
        glassMaterial = .ultraThin
        liquidRefraction = 0.85
        rimLightIntensity = 0.90
        surfaceSheen = 0.60
        tintColorHex = "#FFFFFF"
        tintOpacity = 0.15
        cornerRadius = 38.0
        glassBorderWidth = 1.2
        shadowIntensity = 0.45
        is24Hour = false
        showSeconds = false
        fontDesign = .rounded
        fontWeight = .bold
        clockScale = 0.85
        showDate = true
        showAmPm = true
        windowLevel = .desktop
        isLocked = false
        clickThrough = false
    }
}
