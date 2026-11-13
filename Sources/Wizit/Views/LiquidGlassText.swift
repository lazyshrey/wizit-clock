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
        
        // Translucency calculation:
        // Higher transparency = wallpaper colors and blue meteor shine clearly through the bottom!
        let trans = settings.transparency
        let topAlpha = max(0.65, 1.0 - (trans * 0.25))
        let bottomAlpha = max(0.15, (1.0 - trans) * 0.55)
        
        ZStack {
            // Layer 1: Ambient Depth Shadow (elevates the glass off the desktop wallpaper)
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.45))
                .blur(radius: 10 * scale)
                .offset(y: 5 * scale)
            
            // Layer 2: Tight Contact Shadow
            textGlyph
                .foregroundStyle(Color.black.opacity(settings.shadowIntensity * 0.25))
                .blur(radius: 2 * scale)
                .offset(y: 1.2 * scale)
            
            // Layer 3: Velvety Liquid Glass Body (Clean, smooth vertical optical falloff)
            // Exactly matching Apple's Lock Screen glass clock:
            // Brilliant white top smoothly fading into translucent tinted glass at the bottom,
            // letting the wallpaper's blue meteor and dark sky shine through!
            textGlyph
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(topAlpha), location: 0.0),
                            .init(color: Color.white.opacity(topAlpha * 0.92), location: 0.25),
                            .init(color: Color(red: 0.90, green: 0.94, blue: 0.98).opacity(bottomAlpha * 1.3), location: 0.55),
                            .init(color: tint.opacity(bottomAlpha * 0.9), location: 0.80),
                            .init(color: Color(red: 0.75, green: 0.85, blue: 0.95).opacity(bottomAlpha), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Layer 4: Soft Top Incident Glare (Subtle light catching the upper curve, NOT harsh chrome!)
            if settings.rimLightIntensity > 0.1 {
                textGlyph
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(settings.rimLightIntensity * 0.45), location: 0.0),
                                .init(color: Color.white.opacity(0.10), location: 0.18),
                                .init(color: Color.clear, location: 0.40)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}
