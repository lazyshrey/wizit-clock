import SwiftUI

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Liquid Glass Surface View
public struct LiquidGlassSurface: View {
    @ObservedObject var settings: AppSettings
    
    public init(settings: AppSettings = .shared) {
        self.settings = settings
    }
    
    public var body: some View {
        let cornerRadius = settings.cornerRadius
        let tintColor = Color(hex: settings.tintColorHex)
        let glassShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        ZStack {
            // 1. Native Frost Blur (NSVisualEffectView sampling background)
            VisualEffectBackground(
                material: settings.glassMaterial.nsMaterial,
                blendingMode: .behindWindow,
                state: .active
            )
            .opacity(1.0 - settings.transparency)
            .clipShape(glassShape)
            
            // 2. Translucent Glass Tint Layer
            tintColor
                .opacity(settings.tintOpacity)
                .clipShape(glassShape)
                .allowsHitTesting(false)
            
            // 3. Liquid Glass Internal Optical Caustic / Light Field
            if settings.liquidRefraction > 0.05 {
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(settings.liquidRefraction * 0.40),
                        tintColor.opacity(settings.liquidRefraction * 0.15),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 280
                )
                .blendMode(.screen)
                .clipShape(glassShape)
                .allowsHitTesting(false)
            }
            
            // 4. Specular Convex Surface Glare / Sheen
            if settings.surfaceSheen > 0.05 {
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(settings.surfaceSheen * 0.35), location: 0.0),
                        .init(color: Color.white.opacity(settings.surfaceSheen * 0.10), location: 0.35),
                        .init(color: Color.clear, location: 0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(glassShape)
                .allowsHitTesting(false)
            }
            
            // 5. Liquid Optical Bevel Inner Inset (Simulates glass refraction depth)
            if settings.liquidRefraction > 0.1 {
                glassShape
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(settings.liquidRefraction * 0.50), location: 0.0),
                                .init(color: Color.clear, location: 0.45),
                                .init(color: Color.white.opacity(settings.liquidRefraction * 0.20), location: 0.85),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
                    .padding(1.0)
                    .allowsHitTesting(false)
            }
            
            // 6. Crisp Incident Specular Rim Border
            glassShape
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(settings.rimLightIntensity * 0.90), location: 0.0),
                            .init(color: Color.white.opacity(settings.rimLightIntensity * 0.40), location: 0.25),
                            .init(color: Color.white.opacity(0.12), location: 0.65),
                            .init(color: Color.white.opacity(settings.rimLightIntensity * 0.30), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: settings.glassBorderWidth
                )
                .allowsHitTesting(false)
        }
        // Multi-tier ambient drop shadow for authentic floating glass depth
        .shadow(
            color: Color.black.opacity(settings.shadowIntensity * 0.25),
            radius: 28,
            x: 0,
            y: 14
        )
        .shadow(
            color: Color.black.opacity(settings.shadowIntensity * 0.12),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}
