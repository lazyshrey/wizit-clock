import SwiftUI

public struct GlassmorphicText<Content: View>: View {
    @ObservedObject var settings: AppSettings
    private let content: Content
    
    public init(settings: AppSettings = .shared, @ViewBuilder content: () -> Content) {
        self.settings = settings
        self.content = content()
    }
    
    public var body: some View {
        let tint = Color(hex: settings.tintColorHex)
        // Transparency slider smoothly controls how much wallpaper color shines through the bottom of the numbers
        let bottomOpacity = max(0.15, 1.0 - (settings.transparency * 0.70))
        let topOpacity = min(1.0, max(0.6, settings.rimLightIntensity))
        let midOpacity = min(1.0, 0.92 + (1.0 - settings.transparency) * 0.08)
        
        let liquidGlassGradient = LinearGradient(
            stops: [
                .init(color: Color.white.opacity(topOpacity), location: 0.0),
                .init(color: Color.white.opacity(midOpacity), location: 0.35),
                .init(color: tint.opacity(bottomOpacity * 0.95), location: 0.75),
                .init(color: tint.opacity(bottomOpacity * 0.75), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        content
            .foregroundStyle(liquidGlassGradient)
            // Multi-stage Apple Lock Screen depth drop shadow
            .shadow(
                color: Color.black.opacity(settings.shadowIntensity * 0.45),
                radius: 12 * settings.clockScale,
                x: 0,
                y: 6 * settings.clockScale
            )
            .shadow(
                color: Color.black.opacity(settings.shadowIntensity * 0.25),
                radius: 3 * settings.clockScale,
                x: 0,
                y: 1.5 * settings.clockScale
            )
    }
}
