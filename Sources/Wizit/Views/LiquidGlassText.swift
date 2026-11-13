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
        
        // Dynamic transparency controls
        let trans = settings.transparency
        let bottomAlpha = max(0.20, 1.0 - (trans * 0.75))
        let midAlpha = max(0.35, 1.0 - (trans * 0.45))
        let topAlpha = min(1.0, max(0.70, settings.rimLightIntensity))
        
        ZStack {
            // Layer 1: Deep ambient soft depth shadow (floats the glass off wallpaper)
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.50))
                .blur(radius: 12 * scale)
                .offset(y: 6 * scale)
            
            // Layer 2: Tight contact occlusion shadow
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.35))
                .blur(radius: 2.5 * scale)
                .offset(y: 1.5 * scale)
            
            // Layer 3: Liquid Glass Refraction Body (Multi-stop optical caustic gradient)
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(topAlpha), location: 0.0),
                            .init(color: Color.white.opacity(topAlpha * 0.95), location: 0.12),
                            .init(color: Color(red: 0.92, green: 0.95, blue: 0.98).opacity(midAlpha), location: 0.38),
                            .init(color: tint.opacity(bottomAlpha * 0.85), location: 0.68),
                            .init(color: Color(red: 0.65, green: 0.74, blue: 0.85).opacity(bottomAlpha * 0.70), location: 0.86),
                            .init(color: tint.opacity(bottomAlpha * 0.80), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Layer 4: Convex Surface Sheen Glare (Diagonal specular reflection across the rounded surface)
            if settings.surfaceSheen > 0.05 {
                textGlyph
                    .foregroundStyle(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(settings.surfaceSheen * 0.80),
                                Color.white.opacity(settings.surfaceSheen * 0.25),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: fontSize * 1.3
                        )
                    )
                    .blendMode(.plusLighter)
            }
            
            // Layer 5: Incident Liquid Meniscus / Top Rim Highlight (crisp light reflection on top curve)
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(settings.rimLightIntensity * 0.95), location: 0.0),
                            .init(color: Color.white.opacity(0.30), location: 0.14),
                            .init(color: Color.clear, location: 0.35),
                            .init(color: Color.white.opacity(settings.liquidRefraction * 0.25), location: 0.88),
                            .init(color: Color.white.opacity(settings.liquidRefraction * 0.35), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.plusLighter)
        }
    }
}
