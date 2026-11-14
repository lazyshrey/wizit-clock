import SwiftUI

// MARK: - GlyphixGlassText
//
// Per-glyph numeric transition for the liquid glass clock, modelled on GlyphixTextFx
// (inspo/GlyphixTextFx). Every character lives in its own slot. When a character changes, the old
// glyph floats up and away (shrinking, fading) while the new one rises in from below
// (growing and landing with a light bounce), each property on its own spring.
//
// How it stays smooth and doesn't break:
//  - Slots are keyed from the trailing edge, so "9:59" → "10:00" keeps the minutes in place and
//    only fills the leading (empty, zero-width) slot. No slot is ever inserted or removed.
//  - Slot widths are set explicitly and glide with the layout spring, so proportional digits
//    ("1" vs "0") and a growing/shrinking hour never make the row jump.
//  - Glyphs move with standard SwiftUI modifier transitions, so they always settle exactly at rest.
//  - Changed digits cascade like an odometer carry: ones first, then tens, then hours.
struct GlyphixGlassText: View {
    let text: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let heightRatio: Double
    /// Horizontal padding on each side of a ":" glyph
    var colonSpacing: CGFloat = 0
    /// Slots kept even when the text is shorter (leading slots stay empty and take no space).
    /// Lets "9:59" → "10:00" animate the new digit in rather than inserting a new slot.
    var minimumSlots: Int = 0
    /// Extra delay before this run starts, e.g. so stacked hours roll after the minutes
    var baseDelay: TimeInterval = 0
    @ObservedObject var settings: AppSettings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(slots) { slot in
                let isColon = slot.character == ":"
                GlyphixGlassSlot(
                    character: slot.character,
                    fontSize: isColon ? fontSize * 0.90 : fontSize,
                    weight: weight,
                    heightRatio: heightRatio,
                    delay: reduceMotion ? 0 : slot.delay,
                    reduceMotion: reduceMotion,
                    settings: settings
                )
                .padding(.horizontal, isColon ? colonSpacing : 0)
            }
        }
        // Slot widths and positions follow the text with a smooth (non-bouncy) spring.
        // The glyph transitions carry their own timing, so this only drives layout.
        .animation(GlyphixCurve.layout, value: text)
    }

    // MARK: Slots

    private struct Slot: Identifiable {
        /// Position counted from the trailing edge, so existing digits keep their identity
        /// when the text grows or shrinks at the front
        let id: Int
        /// "" for an empty leading slot
        let character: String
        let delay: TimeInterval
    }

    private var slots: [Slot] {
        let characters = text.map(String.init)
        let padding = max(0, minimumSlots - characters.count)
        let padded = Array(repeating: "", count: padding) + characters

        var result: [Slot] = []
        result.reserveCapacity(padded.count)
        // Number of digit slots to the right: the ones digit starts first and the change
        // carries leftward, the way an odometer rolls over
        var carry = 0
        let stagger = GlyphixCurve.stagger(settings)
        for (fromEnd, character) in padded.reversed().enumerated() {
            let delay = baseDelay + Double(carry) * stagger
            result.append(Slot(id: fromEnd, character: character, delay: delay))
            if character != ":" { carry += 1 }
        }
        return result.reversed()
    }
}

// MARK: - Slot

/// One character position. Holds the current glyph; when the character changes the old glyph is
/// removed and the new one inserted, both running the Glyphix transition.
private struct GlyphixGlassSlot: View {
    let character: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let heightRatio: Double
    let delay: TimeInterval
    let reduceMotion: Bool
    @ObservedObject var settings: AppSettings

    var body: some View {
        // Empty slots keep the row's height but take no width
        let size = LiquidGlassText.size(
            of: character.isEmpty ? "0" : character,
            fontSize: fontSize,
            weight: weight,
            design: settings.fontDesign,
            heightRatio: heightRatio
        )

        ZStack {
            if !character.isEmpty {
                LiquidGlassText(
                    character,
                    fontSize: fontSize,
                    weight: weight,
                    design: settings.fontDesign,
                    heightRatio: heightRatio,
                    settings: settings
                )
                // A new character is a new view: the old one runs the removal transition,
                // the new one the insertion transition
                .id(character)
                .transition(transition(glyphHeight: size.height))
            }
        }
        .frame(width: character.isEmpty ? 0 : size.width, height: size.height)
    }

    private func transition(glyphHeight: CGFloat) -> AnyTransition {
        let style = settings.digitAnimationStyle
        if style == .off {
            return .identity
        }
        if reduceMotion {
            return AnyTransition.opacity.animation(.easeInOut(duration: 0.25))
        }

        let height = max(glyphHeight, 2)
        // Rounded radii: fractional blur radii are noticeably more expensive to render
        let blurOn = settings.digitBlurEnabled && settings.digitBlurAmount > 0.01
        let appearBlur = blurOn ? (settings.digitBlurAmount * height * 0.12).rounded() : 0
        let disappearBlur = blurOn ? (settings.digitBlurAmount * height * 0.15).rounded() : 0

        // Vertical distance a digit travels, scaled by the "Travel" setting
        let travel = CGFloat(min(max(settings.digitTravel, 0), 2))

        let enterState: GlyphRoll
        let exitState: GlyphRoll
        switch style {
        case .rise:
            // Rises in from below, growing; floats up and away, shrinking
            enterState = GlyphRoll(offset: height / 3 * travel, scale: GlyphixCurve.smallestScale, opacity: 0, blur: appearBlur, blurEnabled: blurOn)
            exitState = GlyphRoll(offset: -height / 3 * travel, scale: GlyphixCurve.smallestScale, opacity: 0, blur: disappearBlur, blurEnabled: blurOn)
        case .roll:
            // Odometer: straight up at full size
            enterState = GlyphRoll(offset: height * 0.7 * travel, scale: 1, opacity: 0, blur: appearBlur, blurEnabled: blurOn)
            exitState = GlyphRoll(offset: -height * 0.7 * travel, scale: 1, opacity: 0, blur: disappearBlur, blurEnabled: blurOn)
        case .pop, .off:
            // In place: new digit grows in, old one swells and fades
            enterState = GlyphRoll(offset: 0, scale: 0.5, opacity: 0, blur: appearBlur, blurEnabled: blurOn)
            exitState = GlyphRoll(offset: 0, scale: 1.35, opacity: 0, blur: disappearBlur, blurEnabled: blurOn)
        }
        let rest = GlyphRoll(offset: 0, scale: 1, opacity: 1, blur: 0, blurEnabled: blurOn)
        let speed = max(settings.digitSpeed, 0.1)

        // Plain modifier transitions: SwiftUI interpolates the built-in effects itself and always
        // lands on the identity state, even if the transition is interrupted or merged with
        // another update, so a digit can never be left part-way through its move.
        return .asymmetric(
            insertion: .modifier(active: enterState, identity: rest)
                .animation(GlyphixCurve.enter(settings).delay(delay / speed)),
            removal: .modifier(active: exitState, identity: rest)
                .animation(GlyphixCurve.exit(settings).delay(delay / speed))
        )
    }
}

// MARK: - Motion

enum GlyphixCurve {
    /// Incoming glyph. Bounce and speed come from settings (defaults land with a light bounce).
    @MainActor
    static func enter(_ settings: AppSettings) -> Animation {
        let bounce = min(max(settings.digitBounce, 0), 1)
        return .spring(
            response: 0.46 / max(settings.digitSpeed, 0.1),
            dampingFraction: 1 - 0.55 * bounce
        )
    }

    /// Outgoing glyph. Smooth, no overshoot, slightly quicker so it clears the slot first.
    @MainActor
    static func exit(_ settings: AppSettings) -> Animation {
        .spring(response: 0.36 / max(settings.digitSpeed, 0.1), dampingFraction: 1.0)
    }

    /// Delay between neighbouring digits when several change together
    @MainActor
    static func stagger(_ settings: AppSettings) -> TimeInterval {
        settings.digitCascade && settings.digitAnimationStyle != .off ? 0.06 : 0
    }

    /// Scale a glyph starts at when appearing and shrinks to when leaving (Rise style)
    static let smallestScale: CGFloat = 0.4
    /// Slot width/position changes
    static let layout: Animation = .smooth(duration: 0.5)
}

/// Scale, vertical travel, fade and optional blur for one glyph.
/// `blurEnabled` is the same for the active and identity states, so the view structure never
/// changes mid-transition; when it's off no blur filter is applied at all.
struct GlyphRoll: ViewModifier {
    let offset: CGFloat
    let scale: CGFloat
    let opacity: Double
    let blur: CGFloat
    let blurEnabled: Bool

    func body(content: Content) -> some View {
        let moved = content
            .scaleEffect(scale)
            .offset(y: offset)
            .opacity(opacity)
        if blurEnabled {
            moved.blur(radius: blur)
        } else {
            moved
        }
    }
}
