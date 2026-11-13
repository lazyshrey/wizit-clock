import SwiftUI
import AppKit

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
    
    public var id: String { rawValue }
    
    var weight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

// MARK: - Window Level Option
public enum WindowLevelOption: String, CaseIterable, Identifiable, Codable {
    case desktop = "Desktop Level (Behind Windows)"
    case normal = "Normal Window"
    case floating = "Always On Top (Floating)"
    
    public var id: String { rawValue }
}

// MARK: - Pre-designed Glass Presets
public enum GlassPreset: String, CaseIterable, Identifiable {
    case visionPro = "Apple Vision Glass"
    case pureCrystal = "Pure Frosted Crystal"
    case deepObsidian = "Deep Obsidian"
    case warmSunset = "Sunset Amber"
    case auroraMist = "Aurora Indigo"
    case minimalistGhost = "Minimalist Ghost"
    
    public var id: String { rawValue }
}

// MARK: - AppSettings
@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
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
        
        self.transparency = defaults.object(forKey: "transparency") != nil ? defaults.double(forKey: "transparency") : 0.45
        self.glassMaterial = GlassMaterialOption(rawValue: defaults.string(forKey: "glassMaterial") ?? "") ?? .ultraThin
        self.liquidRefraction = defaults.object(forKey: "liquidRefraction") != nil ? defaults.double(forKey: "liquidRefraction") : 0.65
        self.rimLightIntensity = defaults.object(forKey: "rimLightIntensity") != nil ? defaults.double(forKey: "rimLightIntensity") : 0.75
        self.surfaceSheen = defaults.object(forKey: "surfaceSheen") != nil ? defaults.double(forKey: "surfaceSheen") : 0.40
        self.tintColorHex = defaults.string(forKey: "tintColorHex") ?? "#FFFFFF"
        self.tintOpacity = defaults.object(forKey: "tintOpacity") != nil ? defaults.double(forKey: "tintOpacity") : 0.12
        self.cornerRadius = defaults.object(forKey: "cornerRadius") != nil ? defaults.double(forKey: "cornerRadius") : 38.0
        self.glassBorderWidth = defaults.object(forKey: "glassBorderWidth") != nil ? defaults.double(forKey: "glassBorderWidth") : 1.2
        self.shadowIntensity = defaults.object(forKey: "shadowIntensity") != nil ? defaults.double(forKey: "shadowIntensity") : 0.50
        
        self.is24Hour = defaults.bool(forKey: "is24Hour")
        self.showSeconds = defaults.object(forKey: "showSeconds") != nil ? defaults.bool(forKey: "showSeconds") : true
        self.fontDesign = ClockFontDesign(rawValue: defaults.string(forKey: "fontDesign") ?? "") ?? .rounded
        self.fontWeight = ClockFontWeight(rawValue: defaults.string(forKey: "fontWeight") ?? "") ?? .medium
        self.clockScale = defaults.object(forKey: "clockScale") != nil ? defaults.double(forKey: "clockScale") : 1.0
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
        case .visionPro:
            transparency = 0.40
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
            transparency = 0.20
            glassMaterial = .thin
            liquidRefraction = 0.85
            rimLightIntensity = 0.95
            surfaceSheen = 0.60
            tintColorHex = "#E0F2FE"
            tintOpacity = 0.18
            cornerRadius = 42
            glassBorderWidth = 1.5
            shadowIntensity = 0.45
            
        case .deepObsidian:
            transparency = 0.65
            glassMaterial = .hud
            liquidRefraction = 0.50
            rimLightIntensity = 0.40
            surfaceSheen = 0.25
            tintColorHex = "#0F172A"
            tintOpacity = 0.45
            cornerRadius = 34
            glassBorderWidth = 1.0
            shadowIntensity = 0.75
            
        case .warmSunset:
            transparency = 0.35
            glassMaterial = .ultraThin
            liquidRefraction = 0.75
            rimLightIntensity = 0.80
            surfaceSheen = 0.50
            tintColorHex = "#F59E0B"
            tintOpacity = 0.22
            cornerRadius = 40
            glassBorderWidth = 1.4
            shadowIntensity = 0.50
            
        case .auroraMist:
            transparency = 0.38
            glassMaterial = .thick
            liquidRefraction = 0.80
            rimLightIntensity = 0.85
            surfaceSheen = 0.45
            tintColorHex = "#6366F1"
            tintOpacity = 0.25
            cornerRadius = 36
            glassBorderWidth = 1.2
            shadowIntensity = 0.60
            
        case .minimalistGhost:
            transparency = 0.85
            glassMaterial = .ultraThin
            liquidRefraction = 0.30
            rimLightIntensity = 0.35
            surfaceSheen = 0.15
            tintColorHex = "#FFFFFF"
            tintOpacity = 0.05
            cornerRadius = 32
            glassBorderWidth = 0.8
            shadowIntensity = 0.20
        }
    }
    
    public func resetToDefaults() {
        applyPreset(.visionPro)
        is24Hour = false
        showSeconds = true
        fontDesign = .rounded
        fontWeight = .medium
        clockScale = 1.0
        showDate = true
        showAmPm = true
        windowLevel = .desktop
        isLocked = false
        clickThrough = false
    }
}
