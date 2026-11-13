import SwiftUI

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
    
    public var body: some View {
        let intensity = settings.liquidGlassIntensity
        let trans = settings.transparency
        let scale = fontSize / 104.0
        
        // Clean white tint (wallpaper provides the natural optical color refraction)
        let tintColor: Color = {
            let hex = settings.tintColorHex.uppercased()
            if hex == "#FFFFFF" || hex == "#C8D4E2" {
                return Color.white
            }
            return Color(hex: settings.tintColorHex)
        }()
        
        // Optical Translucency
        let topAlpha = min(1.0, max(0.85, 0.98 - (trans * 0.15)))
        let bottomAlpha = max(0.35, min(0.80, 0.70 - (trans * 0.40) + (intensity * 0.08)))
        
        let textGlyph = Text(text)
            .font(.system(size: fontSize, weight: weight, design: design.design))
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: false))
            .animation(.snappy(duration: 0.55, extraBounce: 0.08), value: text)
        
        ZStack {
            // Layer 1: Ambient Floating 3D Drop Shadow (Elevates glass off desktop wallpaper)
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.38))
                .blur(radius: 12 * scale)
                .offset(y: 5 * scale)
            
            // Layer 2: Tight Occlusion Contact Shadow (Gives crisp letter boundary definition)
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.22))
                .blur(radius: 2.5 * scale)
                .offset(y: 1.5 * scale)
            
            // Layer 3: Pristine Translucent Optical Glass Body
            // Pure vertical optical fade without artificial metallic gray bands
            textGlyph
                .foregroundStyle(
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
            
            // Layer 4: Meniscus Edge Highlight (Light catching the curved glass rim)
            if intensity > 0.05 {
                textGlyph
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.36 * intensity), location: 0.0),
                                .init(color: Color.white.opacity(0.12 * intensity), location: 0.18),
                                .init(color: Color.clear, location: 0.38)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}
