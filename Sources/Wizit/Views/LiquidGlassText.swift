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
        // The outline only depends on text, font and stretch, so it's built once and cached.
        // Rebuilding it through CoreText every time SwiftUI asks is a real cost.
        guard let outline = Self.outline(text: text, font: ctFont, heightRatio: heightRatio) else {
            return Path()
        }
        let bbox = outline.boundingBoxOfPath
        var centerT = CGAffineTransform(
            translationX: rect.midX - bbox.midX,
            y: rect.midY - bbox.midY
        )
        return Path(outline.copy(using: &centerT) ?? outline)
    }
    
    // MARK: Outline cache
    
    private struct CacheKey: Hashable {
        let text: String
        let fontName: String
        let size: CGFloat
        let heightRatio: CGFloat
    }
    
    nonisolated(unsafe) private static var cache: [CacheKey: CGPath] = [:]
    private static let cacheLock = NSLock()
    
    private static func outline(text: String, font: CTFont, heightRatio: CGFloat) -> CGPath? {
        let key = CacheKey(
            text: text,
            fontName: CTFontCopyPostScriptName(font) as String,
            size: CTFontGetSize(font),
            heightRatio: heightRatio
        )
        cacheLock.lock()
        if let cached = cache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()
        
        guard let built = buildOutline(text: text, font: font, heightRatio: heightRatio) else { return nil }
        
        cacheLock.lock()
        // Font/size changes leave stale entries behind; keep the cache small
        if cache.count > 512 { cache.removeAll(keepingCapacity: true) }
        cache[key] = built
        cacheLock.unlock()
        return built
    }
    
    private static func buildOutline(text: String, font ctFont: CTFont, heightRatio: CGFloat) -> CGPath? {
        let str = NSAttributedString(string: text, attributes: [kCTFontAttributeName as NSAttributedString.Key: ctFont])
        let line = CTLineCreateWithAttributedString(str)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return nil }
        
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
        
        if combined.isEmpty { return nil }
        
        let bbox = combined.boundingBoxOfPath
        var toOrigin = CGAffineTransform(translationX: -bbox.minX, y: -bbox.minY)
        let norm = combined.copy(using: &toOrigin) ?? combined
        var flip = CGAffineTransform(scaleX: 1, y: -1)
        let flipped = norm.copy(using: &flip) ?? norm
        
        // Apply vertical stretch / height expansion ratio
        var stretchT = CGAffineTransform(scaleX: 1.0, y: heightRatio)
        return flipped.copy(using: &stretchT) ?? flipped
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
    
    private static func adtFont(for prefix: String, weight: NSFont.Weight, fontSize: CGFloat, text: String) -> CTFont? {
        let weightSuffix: String
        switch weight {
        case .ultraLight: weightSuffix = "Ultralight"
        case .thin: weightSuffix = "Thin"
        case .light: weightSuffix = "Light"
        case .regular: weightSuffix = "Regular"
        case .medium: weightSuffix = "Medium"
        case .semibold: weightSuffix = "Semibold"
        case .bold: weightSuffix = "Bold"
        case .heavy: weightSuffix = "Heavy"
        case .black: weightSuffix = "Black"
        default: weightSuffix = "Semibold"
        }
        
        let candidateNames = [
            "\(prefix)-\(weightSuffix)",
            "\(prefix)-\(weightSuffix)G1",
            "\(prefix)-Regular",
            "\(prefix)-Bold"
        ]
        
        for name in candidateNames {
            if let descriptor = adtNumericDescriptors[name] {
                let font = CTFontCreateWithFontDescriptor(descriptor, fontSize, nil)
                let utf16 = Array(text.utf16)
                var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
                if CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count) {
                    return font
                }
            }
        }
        return nil
    }
    
    private func resolveCTFont() -> CTFont {
        Self.resolveFont(for: text, fontSize: fontSize, weight: weight, design: design)
    }

    /// The font a `LiquidGlassText` with these parameters draws with.
    static func resolveFont(for text: String, fontSize: CGFloat, weight: Font.Weight, design: ClockFontDesign) -> CTFont {
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
        default: appKitWeight = .semibold
        }
        
        switch design {
        case .stencil:
            if let font = adtFont(for: ".SFStencilNumeric", weight: appKitWeight, fontSize: fontSize, text: text) {
                return font
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.default).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .rails:
            if let font = adtFont(for: ".SFRailNumeric", weight: appKitWeight, fontSize: fontSize, text: text) {
                return font
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.default).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .futura:
            let fontName = (appKitWeight >= .bold) ? "Futura-Bold" : "Futura-Medium"
            if let font = NSFont(name: fontName, size: fontSize) ?? NSFont(name: "Futura", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return baseFont as CTFont
            
        case .didot:
            let fontName = (appKitWeight >= .bold) ? "Didot-Bold" : "Didot"
            if let font = NSFont(name: fontName, size: fontSize) ?? NSFont(name: "BodoniSvtyTwoITCTT-Bold", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .din:
            if let font = NSFont(name: "DINAlternate-Bold", size: fontSize) ?? NSFont(name: "DINCondensed-Bold", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight, width: .condensed)
            return baseFont as CTFont
            
        case .bodoni:
            if let font = NSFont(name: "BodoniSvtyTwoITCTT-Bold", size: fontSize) ?? NSFont(name: "Bodoni 72", size: fontSize) ?? NSFont(name: "Didot-Bold", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .typewriter:
            let fontName = (appKitWeight >= .bold) ? "AmericanTypewriter-Bold" : "AmericanTypewriter"
            if let font = NSFont(name: fontName, size: fontSize) ?? NSFont(name: "American Typewriter", size: fontSize) ?? NSFont(name: "Courier", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.monospaced).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .handwritten:
            if let font = NSFont(name: "MarkerFelt-Wide", size: fontSize) ?? NSFont(name: "MarkerFelt-Thin", size: fontSize) ?? NSFont(name: "Noteworthy-Bold", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .copperplate:
            let fontName = (appKitWeight >= .bold) ? "Copperplate-Bold" : "Copperplate"
            if let font = NSFont(name: fontName, size: fontSize) ?? NSFont(name: "Copperplate", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .heavyPoster:
            if let font = NSFont(name: "Impact", size: fontSize) ?? NSFont(name: "AvenirNext-Heavy", size: fontSize) ?? NSFont(name: "Avenir-Heavy", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
            return baseFont as CTFont
            
        case .rounded:
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            if let roundedDesc = baseFont.fontDescriptor.withDesign(.rounded),
               let font = NSFont(descriptor: roundedDesc, size: fontSize) {
                return font as CTFont
            }
            if let font = adtFont(for: ".SFRoundedNumeric", weight: appKitWeight, fontSize: fontSize, text: text) {
                return font
            }
            return baseFont as CTFont
            
        case .slabSerif:
            let slabName = (appKitWeight >= .bold) ? "Rockwell-Bold" : "Rockwell"
            if let font = NSFont(name: slabName, size: fontSize) ?? NSFont(name: "Charter", size: fontSize) ?? NSFont(name: "Georgia", size: fontSize) {
                return font as CTFont
            }
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .serif:
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            if let serifDesc = baseFont.fontDescriptor.withDesign(.serif),
               let font = NSFont(descriptor: serifDesc, size: fontSize) {
                return font as CTFont
            }
            if let font = adtFont(for: ".NewYorkNumeric", weight: appKitWeight, fontSize: fontSize, text: text) {
                return font
            }
            return baseFont as CTFont
            
        case .system:
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.default).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
            
        case .compact:
            let font = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight, width: .condensed)
            return font as CTFont
            
        case .monospaced:
            let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
            return (baseFont.fontDescriptor.withDesign(.monospaced).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? baseFont) as CTFont
        }
    }
    
    private func calculateBounds(ctFont: CTFont) -> CGSize {
        Self.bounds(of: text, font: ctFont, heightRatio: heightRatio)
    }

    /// The frame a `LiquidGlassText` with these parameters occupies.
    static func size(
        of text: String,
        fontSize: CGFloat,
        weight: Font.Weight,
        design: ClockFontDesign,
        heightRatio: Double
    ) -> CGSize {
        let font = resolveFont(for: text, fontSize: fontSize, weight: weight, design: design)
        return bounds(of: text, font: font, heightRatio: heightRatio)
    }

    private static func bounds(of text: String, font ctFont: CTFont, heightRatio: Double) -> CGSize {
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
        let isCustomTint = settings.tintColorHex.uppercased() != "#FFFFFF" && settings.tintColorHex.uppercased() != "#C8D4E2"
        
        ZStack {
            // Shadows (below the glass)
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
            
            // Surface layers (above the glass)
            // Layer 3.2: Optical Color Cast (When custom tint color is selected)
            if isCustomTint {
                shape
                    .fill(tintColor.opacity(0.18 * intensity))
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
            
            // Layer 5: Razor-Thin Hairline Specular Edge (Ultra-fine 0.55px micro-bevel with polished round joins)
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
                        style: StrokeStyle(
                            lineWidth: 0.55 * scale,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        }
        .environment(\.controlActiveState, .active)
        .frame(width: bounds.width, height: bounds.height)
    }
}
