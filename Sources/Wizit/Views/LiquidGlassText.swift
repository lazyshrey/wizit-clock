import SwiftUI

public struct LiquidGlassText: View {
    let text: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @ObservedObject var settings: AppSettings
    
    public init(
        _ text: String,
        fontSize: CGFloat = 76,
        weight: Font.Weight = .heavy,
        design: Font.Design = .rounded,
        settings: AppSettings = .shared
    ) {
        self.text = text
        self.fontSize = fontSize
        self.weight = weight
        self.design = design
        self.settings = settings
    }
    
    public var body: some View {
        let textGlyph = Text(text)
            .font(.system(size: fontSize, weight: weight, design: design))
            .monospacedDigit()
        
        let tint = Color(hex: settings.tintColorHex)
        let scale = fontSize / 76.0
        
        // Transparency: higher transparency = more see-through glass!
        let trans = settings.transparency // 0.0 to 1.0 (default ~0.45)
        let bodyOpacity = max(0.08, (1.0 - trans) * 0.45)
        let rimOpacity = max(0.3, settings.rimLightIntensity)
        
        ZStack {
            // 1. Soft Ambient Depth Shadows behind the glass
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.45))
                .blur(radius: 12 * scale)
                .offset(y: 6 * scale)
            
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.30))
                .blur(radius: 2.5 * scale)
                .offset(y: 1.5 * scale)
            
            // 2. Real Native Ultra-Thin Frosted Glass Material (Samples & blurs wallpaper directly through the letters!)
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(1.0 - (trans * 0.5))
                .mask(textGlyph)
            
            // 3. Liquid Glass Refractive Body (Translucent color tint & liquid gradient)
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(bodyOpacity + 0.35), location: 0.0),
                            .init(color: Color.white.opacity(bodyOpacity + 0.15), location: 0.25),
                            .init(color: tint.opacity(bodyOpacity * 0.7), location: 0.65),
                            .init(color: tint.opacity(bodyOpacity * 0.3), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // 4. Specular Convex Surface Glare (Curved liquid lens sheen)
            if settings.surfaceSheen > 0.05 {
                textGlyph
                    .foregroundStyle(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(settings.surfaceSheen * 0.65),
                                Color.white.opacity(settings.surfaceSheen * 0.15),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: fontSize * 1.3
                        )
                    )
                    .blendMode(.plusLighter)
            }
            
            // 5. Incident Liquid Meniscus / Top Specular Rim (Crisp light catching the curved top edge)
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(rimOpacity * 0.95), location: 0.0),
                            .init(color: Color.white.opacity(0.20), location: 0.12),
                            .init(color: Color.clear, location: 0.35),
                            .init(color: Color.white.opacity(settings.liquidRefraction * 0.25), location: 0.85),
                            .init(color: Color.white.opacity(settings.liquidRefraction * 0.40), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.plusLighter)
            
            // 6. Liquid Glass Caustic Refraction Bevel (Inner light refraction stroke)
            if settings.liquidRefraction > 0.1 {
                textGlyph
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(settings.liquidRefraction * 0.50), location: 0.0),
                                .init(color: Color.clear, location: 0.40),
                                .init(color: Color.white.opacity(settings.liquidRefraction * 0.30), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(x: -0.5 * scale, y: -0.5 * scale)
                    .blendMode(.overlay)
            }
        }
    }
}
