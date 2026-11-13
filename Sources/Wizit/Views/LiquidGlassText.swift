@preconcurrency import CoreText
import SwiftUI
import AppKit

// MARK: - TextOutlineShape (from ailtonvivaz/GlassText)
public struct TextOutlineShape: Shape {
    public var text: String
    public var ctFont: CTFont
    public var fontSize: CGFloat
    
    public init(text: String, ctFont: CTFont, fontSize: CGFloat) {
        self.text = text
        self.ctFont = ctFont
        self.fontSize = fontSize
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
        let finalBBox = flipped.boundingBoxOfPath
        
        var centerT = CGAffineTransform(
            translationX: rect.midX - finalBBox.midX,
            y: rect.midY - finalBBox.midY
        )
        let finalCG = flipped.copy(using: &centerT) ?? flipped
        return Path(finalCG)
    }
}

// MARK: - LiquidGlassText (100% Pure Transparent Liquid Glass Text)
public struct LiquidGlassText: View {
    let text: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let design: ClockFontDesign
    @ObservedObject var settings: AppSettings
    
    public init(
        _ text: String,
        fontSize: CGFloat = 104,
        weight: Font.Weight = .bold,
        design: ClockFontDesign = .rounded,
        settings: AppSettings = .shared
    ) {
        self.text = text
        self.fontSize = fontSize
        self.weight = weight
        self.design = design
        self.settings = settings
    }
    
    private func resolveCTFont() -> CTFont {
        let appKitWeight: NSFont.Weight
        switch settings.fontWeight {
        case .ultraLight: appKitWeight = .ultraLight
        case .light: appKitWeight = .light
        case .regular: appKitWeight = .regular
        case .medium: appKitWeight = .medium
        case .semibold: appKitWeight = .semibold
        case .bold: appKitWeight = .bold
        case .heavy: appKitWeight = .heavy
        }
        
        let baseFont = NSFont.systemFont(ofSize: fontSize, weight: appKitWeight)
        let fontDesignDesc: NSFontDescriptor.SystemDesign
        switch design {
        case .rounded:
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
        let height = ascent + descent
        return CGSize(width: max(1, ceil(width)), height: max(1, ceil(height)))
    }
    
    public var body: some View {
        let ctFont = resolveCTFont()
        let bounds = calculateBounds(ctFont: ctFont)
        let shape = TextOutlineShape(text: text, ctFont: ctFont, fontSize: fontSize)
        
        let intensity = settings.liquidGlassIntensity
        let scale = fontSize / 104.0
        
        ZStack {
            // Layer 1: Ambient Floating 3D Drop Shadow (Physical separation from wallpaper)
            shape
                .fill(Color.black.opacity(settings.shadowIntensity * 0.40))
                .blur(radius: 12 * scale)
                .offset(y: 5 * scale)
            
            // Layer 2: Tight Occlusion Contact Shadow (Gives crisp definition to letter boundaries)
            shape
                .fill(Color.black.opacity(settings.shadowIntensity * 0.22))
                .blur(radius: 2.5 * scale)
                .offset(y: 1.5 * scale)
            
            // Layer 3: Native Completely Transparent Liquid Glass (ailtonvivaz/GlassText)
            // Lenses and refracts the live desktop wallpaper behind the window
            if #available(macOS 26.0, *) {
                let glass: Glass = (settings.glassVariant == .regular) ? .regular : .clear
                Rectangle()
                    .fill(.clear)
                    .glassEffect(glass, in: shape)
            }
            
            // Layer 4: Razor-Sharp Specular Glass Edge Rim (Fresnel boundary reflection)
            shape
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.92 * intensity), location: 0.0),
                            .init(color: Color.white.opacity(0.55 * intensity), location: 0.35),
                            .init(color: Color.white.opacity(0.25 * intensity), location: 0.70),
                            .init(color: Color.white.opacity(0.60 * intensity), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.3 * scale
                )
            
            // Layer 5: Top Specular Meniscus Light Catch (Curved rim light reflection)
            if intensity > 0.05 {
                shape
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.65 * intensity), location: 0.0),
                                .init(color: Color.white.opacity(0.15 * intensity), location: 0.20),
                                .init(color: Color.clear, location: 0.45)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2.0 * scale
                    )
            }
        }
        .frame(width: bounds.width, height: bounds.height)
    }
}
