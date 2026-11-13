import SwiftUI

public struct LiquidGlassText: View {
    let text: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @ObservedObject var settings: AppSettings
    
    public init(
        _ text: String,
        fontSize: CGFloat = 104,
        weight: Font.Weight = .bold,
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
        
        let scale = fontSize / 104.0
        let trans = settings.transparency
        
        // Liquid Glass Translucency:
        // Top is crisp luminous white; bottom is soft translucent glass (wallpaper shines through!)
        let topAlpha = min(1.0, max(0.75, 1.0 - (trans * 0.20)))
        let bottomAlpha = max(0.20, 1.0 - (trans * 0.70))
        let tint = Color(hex: settings.tintColorHex)
        
        ZStack {
            // Layer 1: Ambient Depth Shadow (elevates the glass off the desktop wallpaper)
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.40))
                .blur(radius: 10 * scale)
                .offset(y: 5 * scale)
            
            // Layer 2: Tight Occlusion Contact Shadow
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.20))
                .blur(radius: 2 * scale)
                .offset(y: 1.2 * scale)
            
            // Layer 3: Pristine Apple Lock Screen Glass Body
            // Pure vertical optical fade without harsh diagonal metallic slashes
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(topAlpha), location: 0.0),
                            .init(color: Color.white.opacity(topAlpha * 0.94), location: 0.25),
                            .init(color: Color(red: 0.92, green: 0.95, blue: 0.98).opacity(bottomAlpha * 1.2), location: 0.60),
                            .init(color: tint.opacity(bottomAlpha * 0.85), location: 0.85),
                            .init(color: tint.opacity(bottomAlpha * 0.95), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Layer 4: Soft Meniscus Edge Highlight (Subtle light catching the top curve)
            if settings.rimLightIntensity > 0.05 {
                textGlyph
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(settings.rimLightIntensity * 0.45), location: 0.0),
                                .init(color: Color.white.opacity(0.10), location: 0.16),
                                .init(color: Color.clear, location: 0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}
