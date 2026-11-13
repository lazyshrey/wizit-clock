@preconcurrency import CoreText
import SwiftUI
import AppKit

// MARK: - TextOutlineShape (from ailtonvivaz/GlassText)
public struct TextOutlineShape: Shape {
    public var text: String
    public var ctFont: CTFont
    public var fontSize: CGFloat
    public var heightRatio: CGFloat
    
    public init(text: String, ctFont: CTFont, fontSize: CGFloat, heightRatio: CGFloat = 1.0) {
        self.text = text
        self.ctFont = ctFont
        self.fontSize = fontSize
        self.heightRatio = heightRatio
    }

    public func path(in rect: CGRect) -> Path {
        let str = NSAttributedString(string: text, attributes: [kCTFontAttributeName as NSAttributedString.Key: ctFont])
        let line = CTLineCreateWithAttributedString(str)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return Path() }
        
        let combined = CGMutablePath()
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var glyphs = Array(repeating: CGGlyph(), count: count)
            var positions = Array(repeating: CGPoint.zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            
            for i in 0..<count {
                if let p = CTFontCreatePathForGlyph(ctFont, glyphs[i], nil) {
                    var t = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                    if let shifted = p.copy(using: &t) {
                        combined.addPath(shifted)
                    }
                }
            }
        }
        
        if combined.isEmpty { return Path() }
        
        let bbox = combined.boundingBoxOfPath
        var toOrigin = CGAffineTransform(translationX: -bbox.minX, y: -bbox.minY)
        let norm = combined.copy(using: &toOrigin) ?? combined
        var flip = CGAffineTransform(scaleX: 1, y: -1)
        let flipped = norm.copy(using: &flip) ?? norm
        
        // Apply vertical stretch / height expansion ratio
        var stretchT = CGAffineTransform(scaleX: 1.0, y: heightRatio)
        let stretched = flipped.copy(using: &stretchT) ?? flipped
        let finalBBox = stretched.boundingBoxOfPath
        
        var centerT = CGAffineTransform(
            translationX: rect.midX - finalBBox.midX,
            y: rect.midY - finalBBox.midY
        )
        let finalCG = stretched.copy(using: &centerT) ?? stretched
        return Path(finalCG)
    }
}

// MARK: - LiquidGlassText (100% Pure Transparent Liquid Glass Text)
public struct LiquidGlassText: View {
    let text: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let design: ClockFontDesign
    let heightRatio: Double
    @ObservedObject var settings: AppSettings
    
    public init(
        _ text: String,
        fontSize: CGFloat = 104,
        weight: Font.Weight = .bold,
        design: ClockFontDesign = .rounded,
        heightRatio: Double = 1.0,
        settings: AppSettings = .shared
    ) {
        self.text = text
        self.fontSize = fontSize
        self.weight = weight
        self.design = design
        self.heightRatio = heightRatio
        self.settings = settings
    }
    
    private static var adtNumericDescriptors: [String: CTFontDescriptor] = {
        var map: [String: CTFontDescriptor] = [:]
        let url = URL(fileURLWithPath: "/System/Library/Fonts/ADTNumeric.ttc")
        if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] {
            for d in descriptors {
                if let name = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String {
                    map[name] = d
                }
            }
        }
        return map
    }()
    
    private func lockScreenFontName(for weight: NSFont.Weight) -> String {
        switch weight {
        case .ultraLight: return ".SFRoundedNumeric-Ultralight"
        case .thin: return ".SFRoundedNumeric-Thin"
        case .light: return ".SFRoundedNumeric-Light"
        case .regular: return ".SFRoundedNumeric-Regular"
        case .medium: return ".SFRoundedNumeric-Medium"
        case .semibold: return ".SFRoundedNumeric-Semibold"
        case .bold: return ".SFRoundedNumeric-Bold"
        case .heavy: return ".SFRoundedNumeric-Heavy"
        case .black: return ".SFRoundedNumeric-Black"
        default: return ".SFRoundedNumeric-Bold"
        }
    }
    
    private func resolveCTFont() -> CTFont {
        let appKitWeight: NSFont.Weight
        switch weight {
        case .ultraLight: appKitWeight = .ultraLight
        case .thin: appKitWeight = .thin
        case .light: appKitWeight = .light
        case .regular: appKitWeight = .regular
        case .medium: appKitWeight = .medium
        case .semibold: appKitWeight = .semibold
        case .bold: appKitWeight = .bold
        case .heavy: appKitWeight = .heavy
        case .black: appKitWeight = .black
        default: appKitWeight = .bold
        }
        
        if design == .lockScreen {
            let fontName = lockScreenFontName(for: appKitWeight)
            if let descriptor = Self.adtNumericDescriptors[fontName] {
                let font = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)
                let utf16 = Array(text.utf16)
                var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
                if CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count) {
                    return font
                }
            }
            // Fallback for letters / words (e.g. "Sat, Nov 14")
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            if let desc = baseFont.fontDescriptor.withDesign(.rounded) {
                return (NSFont(descriptor: desc, size: fontSize) ?? baseFont) as CTFont
            }
            return baseFont as CTFont
        }
        
        let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
        let fontDesignDesc: NSFontDescriptor.SystemDesign
        switch design {
        case .lockScreen, .rounded:
            fontDesignDesc = .rounded
        case .system:
            fontDesignDesc = .default
        case .monospaced:
            fontDesignDesc = .monospaced
        case .serif:
            fontDesignDesc = .serif
        }
        
        if let descriptor = baseFont.fontDescriptor.withDesign(fontDesignDesc) {
            return (NSFont(descriptor: descriptor, size: fontSize) ?? baseFont) as CTFont
        }
        return baseFont as CTFont
    }
    
    private func calculateBounds(ctFont: CTFont) -> CGSize {
        let str = NSAttributedString(string: text, attributes: [kCTFontAttributeName as NSAttributedString.Key: ctFont])
        let line = CTLineCreateWithAttributedString(str)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let height = (ascent + descent) * CGFloat(heightRatio)
        return CGSize(width: max(1, ceil(width)), height: max(1, ceil(height)))
    }
    
    public var body: some View {
        let ctFont = resolveCTFont()
        let bounds = calculateBounds(ctFont: ctFont)
        let shape = TextOutlineShape(text: text, ctFont: ctFont, fontSize: fontSize, heightRatio: CGFloat(heightRatio))
        
        let intensity = settings.liquidGlassIntensity
        let rimIntensity = settings.rimLightIntensity
        let sheen = settings.surfaceSheen
        let glassOpacity = settings.glassOpacity
        let scale = fontSize / 104.0
        
        let tintColor: Color = {
            let hex = settings.tintColorHex.uppercased()
            if hex == "#FFFFFF" || hex == "#C8D4E2" {
                return Color.white
            }
            return Color(hex: settings.tintColorHex)
        }()
        
        ZStack {
            // Layer 1: Ambient Floating 3D Drop Shadow (Physical separation from wallpaper)
            shape
                .fill(Color.black.opacity(settings.shadowIntensity * 0.42))
                .blur(radius: 12 * scale)
                .offset(y: 5 * scale)
            
            // Layer 2: Tight Occlusion Contact Shadow
            shape
                .fill(Color.black.opacity(settings.shadowIntensity * 0.22))
                .blur(radius: 2.5 * scale)
                .offset(y: 1.5 * scale)
            
            // Layer 3: Native Apple Liquid Glass Shader (ailtonvivaz/GlassText)
            // Lenses and refracts the live desktop wallpaper behind the window
            if #available(macOS 26.0, *) {
                let glass: Glass = (settings.glassVariant == .regular) ? .regular : .clear
                Rectangle()
                    .fill(.clear)
                    .glassEffect(glass, in: shape)
                    .environment(\.controlActiveState, .active)
            }
            
            // Layer 3.5: Translucent Glass Body Opacity / Frost Density
            if glassOpacity > 0.01 {
                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: tintColor.opacity(glassOpacity * 0.90), location: 0.0),
                                .init(color: tintColor.opacity(glassOpacity * 0.70), location: 0.5),
                                .init(color: tintColor.opacity(glassOpacity * 0.85), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            // Layer 4: Delicate Internal Optical Sheen (Subtle crystal body luster)
            if sheen > 0.05 {
                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: tintColor.opacity(0.16 * sheen * intensity), location: 0.0),
                                .init(color: tintColor.opacity(0.03 * sheen * intensity), location: 0.45),
                                .init(color: tintColor.opacity(0.09 * sheen * intensity), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            // Layer 5: Razor-Thin Hairline Specular Edge (Ultra-fine 0.55px micro-bevel, NEVER thick border!)
            if rimIntensity > 0.05 {
                shape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.55 * rimIntensity), location: 0.0),
                                .init(color: Color.white.opacity(0.25 * rimIntensity), location: 0.35),
                                .init(color: Color.white.opacity(0.08 * rimIntensity), location: 0.70),
                                .init(color: Color.white.opacity(0.30 * rimIntensity), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.55 * scale
                    )
            }
        }
        .environment(\.controlActiveState, .active)
        .frame(width: bounds.width, height: bounds.height)
    }
}
