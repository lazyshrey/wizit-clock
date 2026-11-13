import SwiftUI

public struct LiquidGlassText: View {
    let text: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @ObservedObject var settings: AppSettings
    
    public init(
        _ text: String,
        fontSize: CGFloat = 78,
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
        let textGlyphs = Text(text)
            .font(.system(size: fontSize, weight: weight, design: design))
            .monospacedDigit()
        
        let tint = Color(hex: settings.tintColorHex)
        let scale = fontSize / 80.0
        
        ZStack {
            // 1. Ambient & Contact Drop Shadows (elevation over wallpaper)
            textGlyphs
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.55))
                .blur(radius: 12 * scale)
                .offset(y: 6 * scale)
            
            textGlyphs
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.30))
                .blur(radius: 2.5 * scale)
                .offset(y: 1.2 * scale)
            
            // 2. Liquid Glass Masked Refractive Core
            ZStack {
                // Real-time backdrop blur: wallpaper blurs directly through the liquid glass glyphs!
                VisualEffectBackground(
                    material: settings.glassMaterial.nsMaterial,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .opacity(1.0 - (settings.transparency * 0.65))
                
                // Translucent Liquid Glass Tint
                tint
                    .opacity(settings.tintOpacity * 0.9)
                
                // Liquid Caustic Gradient: Specular top to translucent liquid bottom
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(settings.rimLightIntensity), location: 0.0),
                        .init(color: Color.white.opacity(0.85), location: 0.18),
                        .init(color: Color.white.opacity(0.35 + (1.0 - settings.transparency) * 0.40), location: 0.50),
                        .init(color: tint.opacity(0.35), location: 0.72),
                        .init(color: Color.white.opacity(settings.liquidRefraction * 0.55), location: 0.88),
                        .init(color: Color.white.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Convex Liquid Surface Sheen Glare
                if settings.surfaceSheen > 0.05 {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(settings.surfaceSheen * 0.75),
                            Color.white.opacity(settings.surfaceSheen * 0.20),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: fontSize * 1.4
                    )
                    .blendMode(.plusLighter)
                }
                
                // Liquid lens refraction band across the center of digits
                if settings.liquidRefraction > 0.15 {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.32),
                            .init(color: Color.white.opacity(settings.liquidRefraction * 0.32), location: 0.48),
                            .init(color: .clear, location: 0.66)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.screen)
                }
            }
            .mask(textGlyphs)
            
            // 3. Specular Incident Rim Meniscus
            textGlyphs
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(settings.rimLightIntensity * 0.95), location: 0.0),
                            .init(color: Color.white.opacity(0.18), location: 0.45),
                            .init(color: Color.white.opacity(settings.rimLightIntensity * 0.40), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
        }
    }
}
