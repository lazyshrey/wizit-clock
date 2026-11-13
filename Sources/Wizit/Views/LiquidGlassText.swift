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
        
        // Transparency controls:
        // When transparency is high, the bottom of the numbers becomes very sheer (0.15),
        // letting the wallpaper's blue meteor line and dark sky shine directly through!
        let trans = settings.transparency
        let topAlpha = max(0.55, 1.0 - (trans * 0.35))
        let bottomAlpha = max(0.12, (1.0 - trans) * 0.50)
        let rimIntensity = settings.rimLightIntensity
        
        ZStack {
            // 1. Soft Ambient Depth Shadow (elevates the glass off the desktop wallpaper)
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.50))
                .blur(radius: 10 * scale)
                .offset(y: 5 * scale)
            
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.30))
                .blur(radius: 2 * scale)
                .offset(y: 1.2 * scale)
            
            // 2. Translucent Liquid Glass Body (No .mask() to avoid AppKit compositing bugs)
            // Luminous white top fading down to a sheer, see-through glass bottom
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(topAlpha), location: 0.0),
                            .init(color: Color.white.opacity(topAlpha * 0.85), location: 0.18),
                            .init(color: Color.white.opacity(bottomAlpha * 1.4), location: 0.45),
                            .init(color: tint.opacity(bottomAlpha * 0.9), location: 0.72),
                            .init(color: Color.white.opacity(bottomAlpha), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // 3. Incident Liquid Meniscus (Top-left curved rim highlight capturing incident light)
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(rimIntensity * 0.85), location: 0.0),
                            .init(color: Color.white.opacity(0.18), location: 0.14),
                            .init(color: Color.clear, location: 0.35),
                            .init(color: Color.white.opacity(settings.liquidRefraction * 0.20), location: 0.85),
                            .init(color: Color.white.opacity(settings.liquidRefraction * 0.35), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(y: -0.6 * scale)
                .blendMode(.plusLighter)
            
            // 4. Convex Surface Sheen Glare (Curved optical glass reflection)
            if settings.surfaceSheen > 0.05 {
                textGlyph
                    .foregroundStyle(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(settings.surfaceSheen * 0.70),
                                Color.white.opacity(settings.surfaceSheen * 0.15),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: fontSize * 1.1
                        )
                    )
                    .blendMode(.plusLighter)
            }
        }
    }
}
