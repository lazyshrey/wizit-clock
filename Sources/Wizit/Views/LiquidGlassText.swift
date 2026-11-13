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
        let intensity = settings.liquidGlassIntensity
        let trans = settings.transparency
        
        // Liquid glass transparency: Top luminous highlight, sheer see-through bottom
        let topAlpha = min(1.0, 0.70 + (intensity * 0.30))
        let bottomAlpha = max(0.10, (1.0 - trans) * 0.45)
        
        ZStack {
            // Layer 1: Ambient Depth Shadow (elevates the liquid glass off the desktop wallpaper)
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.50))
                .blur(radius: 10 * scale)
                .offset(y: 5 * scale)
            
            // Layer 2: Tight Occlusion Contact Shadow
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.30))
                .blur(radius: 2 * scale)
                .offset(y: 1.2 * scale)
            
            // Layer 3: Liquid Glass Translucent Body
            // Luminous white top fading down to a sheer, see-through glass bottom
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(topAlpha), location: 0.0),
                            .init(color: Color.white.opacity(topAlpha * 0.82), location: 0.16),
                            .init(color: Color.white.opacity(bottomAlpha * 1.3), location: 0.42),
                            .init(color: tint.opacity(bottomAlpha * 0.8), location: 0.70),
                            .init(color: Color(red: 0.70, green: 0.82, blue: 0.95).opacity(bottomAlpha * (0.5 + intensity * 0.4)), location: 0.88),
                            .init(color: Color.white.opacity(bottomAlpha * 0.9), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Layer 4: Incident Liquid Meniscus (Top-left curved rim highlight capturing light)
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(intensity * 0.95), location: 0.0),
                            .init(color: Color.white.opacity(intensity * 0.35), location: 0.12),
                            .init(color: Color.clear, location: 0.32),
                            .init(color: Color.white.opacity(intensity * 0.25), location: 0.85),
                            .init(color: Color.white.opacity(intensity * 0.50), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(y: -0.6 * scale)
                .blendMode(.plusLighter)
            
            // Layer 5: Convex Surface Sheen Glare (Curved optical glass reflection)
            if settings.surfaceSheen > 0.05 {
                textGlyph
                    .foregroundStyle(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(settings.surfaceSheen * 0.75),
                                Color.white.opacity(settings.surfaceSheen * 0.20),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: fontSize * 1.1
                        )
                    )
                    .blendMode(.plusLighter)
            }
            
            // Layer 6: Caustic Liquid Refraction Accent
            if intensity > 0.25 {
                textGlyph
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(intensity * 0.45), location: 0.0),
                                .init(color: Color.clear, location: 0.25),
                                .init(color: Color.white.opacity(intensity * 0.35), location: 0.90),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
            }
        }
    }
}
