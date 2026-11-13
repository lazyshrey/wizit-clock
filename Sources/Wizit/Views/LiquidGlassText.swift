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

// MARK: - LiquidGlassText (Native SwiftUI Liquid Glass Text Effect)
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
        let trans = settings.transparency
        let scale = fontSize / 104.0
        
        // Clean white tint (wallpaper provides natural optical refraction)
        let tintColor: Color = {
            let hex = settings.tintColorHex.uppercased()
            if hex == "#FFFFFF" || hex == "#C8D4E2" {
                return Color.white
            }
            return Color(hex: settings.tintColorHex)
        }()
        
        let topAlpha = min(1.0, max(0.85, 0.98 - (trans * 0.15)))
        let bottomAlpha = max(0.35, min(0.80, 0.70 - (trans * 0.40) + (intensity * 0.08)))
        
        ZStack {
            // Layer 1: Ambient Floating 3D Drop Shadow (Elevates glass off desktop wallpaper)
            shape
                .fill(Color.black.opacity(settings.shadowIntensity * 0.40))
                .blur(radius: 12 * scale)
                .offset(y: 5 * scale)
            
            // Layer 2: Tight Occlusion Contact Shadow
            shape
                .fill(Color.black.opacity(settings.shadowIntensity * 0.22))
                .blur(radius: 2.5 * scale)
                .offset(y: 1.5 * scale)
            
            // Layer 3: Native Apple Liquid Glass Shader (ailtonvivaz/GlassText)
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular.tint(tintColor.opacity(0.15)), in: shape)
            }
            
            // Layer 4: Translucent Frosted Glass Optical Body
            shape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(topAlpha), location: 0.0),
                            .init(color: Color.white.opacity(topAlpha * 0.96), location: 0.28),
                            .init(color: tintColor.opacity(bottomAlpha * 1.05), location: 0.68),
                            .init(color: tintColor.opacity(bottomAlpha), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Layer 5: Specular Glass Edge Rim (Fresnel reflection)
            shape
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.95 * intensity), location: 0.0),
                            .init(color: Color.white.opacity(0.65 * intensity), location: 0.40),
                            .init(color: Color.white.opacity(0.45 * intensity), location: 0.75),
                            .init(color: Color.white.opacity(0.60 * intensity), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.2 * scale
                )
            
            // Layer 6: Top Meniscus Highlight (Light catching upper curved glass rim)
            if intensity > 0.05 {
                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.35 * intensity), location: 0.0),
                                .init(color: Color.white.opacity(0.12 * intensity), location: 0.20),
                                .init(color: Color.clear, location: 0.42)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .frame(width: bounds.width, height: bounds.height)
    }
}
