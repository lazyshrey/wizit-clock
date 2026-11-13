import SwiftUI

public struct GlassmorphicText<Content: View>: View {
    @ObservedObject var settings: AppSettings
    private let content: Content
    
    public init(settings: AppSettings = .shared, @ViewBuilder content: () -> Content) {
        self.settings = settings
        self.content = content()
    }
    
    public var body: some View {
        let tintColor = Color(hex: settings.tintColorHex)
        
        ZStack {
            // 1. Ambient soft depth shadows behind glyphs for high legibility
            content
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.50))
                .blur(radius: 12)
                .offset(y: 6)
            
            content
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.30))
                .blur(radius: 3)
                .offset(y: 1.5)
            
            // 2. Liquid Glass Masked Core
            ZStack {
                // Frosted backdrop blur directly through the letters
                VisualEffectBackground(
                    material: settings.glassMaterial.nsMaterial,
                    blendingMode: .behindWindow,
                    state: .active
                )
                .opacity(1.0 - settings.transparency)
                
                // Translucent color tint
                tintColor
                    .opacity(settings.tintOpacity)
                
                // Liquid glass specular fill gradient
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(settings.rimLightIntensity * 0.95), location: 0.0),
                        .init(color: .white.opacity(0.35 + (1.0 - settings.transparency) * 0.45), location: 0.45),
                        .init(color: .white.opacity(settings.liquidRefraction * 0.65), location: 0.82),
                        .init(color: .white.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.screen)
                
                // Diagonal convex glass reflection sheen
                if settings.surfaceSheen > 0.05 {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(settings.surfaceSheen * 0.70),
                            Color.white.opacity(settings.surfaceSheen * 0.20),
                            Color.clear
                        ]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 400
                    )
                    .blendMode(.plusLighter)
                }
            }
            .mask(content)
            
            // 3. Specular edge overlay on the glyphs
            content
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(settings.rimLightIntensity * 0.90), location: 0.0),
                            .init(color: .white.opacity(0.20), location: 0.50),
                            .init(color: .white.opacity(settings.rimLightIntensity * 0.40), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
        }
    }
}
