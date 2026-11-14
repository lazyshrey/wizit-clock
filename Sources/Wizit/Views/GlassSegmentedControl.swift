import SwiftUI

// MARK: - Liquid Glass Segmented Control
//
// A capsule of Liquid Glass with a highlight that marks the selected segment, matching the
// system's glass bars (e.g. Xcode's navigator selector on macOS 26+).
//
// • Click a segment: the highlight slides over to it.
// • Drag: the highlight lifts into a glass lens that follows the pointer, then snaps to the
//   nearest segment and selects it on release.
//
// Falls back to a material capsule and lens on older macOS.

struct GlassSegment<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var icon: String?

    var id: Value { value }
}

struct GlassSegmentedControl<Value: Hashable>: View {
    enum Style {
        /// Round icon buttons (tab bar)
        case icons
        /// Compact text capsules (inline pickers)
        case text
    }

    @Binding var selection: Value
    let segments: [GlassSegment<Value>]
    var style: Style = .text

    /// Segment frames in the control's coordinate space, keyed by index
    @State private var frames: [Int: CGRect] = [:]
    /// Lens center while dragging; nil when resting
    @State private var lensX: CGFloat?
    @State private var hovered: Int?

    private let space = "GlassSegmentedControl"
    private let settle = Animation.spring(response: 0.38, dampingFraction: 0.78)
    private let follow = Animation.interactiveSpring(response: 0.16, dampingFraction: 0.86)

    var body: some View {
        HStack(spacing: style == .icons ? 4 : 2) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                segmentLabel(segment, index: index)
            }
        }
        .coordinateSpace(name: space)
        .onPreferenceChange(SegmentFramesKey.self) { frames = $0 }
        // Resting highlight sits under the labels
        .background(alignment: .topLeading) {
            if let rect = highlightRect {
                Capsule()
                    .fill(SegmentPalette.selection)
                    .overlay(Capsule().strokeBorder(SegmentPalette.selectionRim, lineWidth: 0.5))
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .opacity(lensX == nil ? 1 : 0)
            }
        }
        // Glass lens floats above the labels while dragging
        .overlay(alignment: .topLeading) {
            if let rect = highlightRect, lensX != nil {
                GlassLens()
                    .frame(width: rect.width, height: rect.height)
                    .scaleEffect(1.22)
                    .offset(x: rect.minX, y: rect.minY)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Capsule())
        .gesture(dragGesture)
        .padding(style == .icons ? 5 : 3)
        .modifier(GlassCapsuleBackground())
        .accessibilityElement(children: .contain)
    }

    // MARK: Segments

    private func segmentLabel(_ segment: GlassSegment<Value>, index: Int) -> some View {
        let isActive = index == activeIndex
        let isHovered = hovered == index && !isActive && lensX == nil

        return label(for: segment, isActive: isActive)
            .background {
                if isHovered {
                    Capsule().fill(SegmentPalette.hover)
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SegmentFramesKey.self,
                        value: [index: proxy.frame(in: .named(space))]
                    )
                }
            )
            .contentShape(Capsule())
            .help(segment.title)
            .onHover { inside in
                withAnimation(.easeOut(duration: 0.12)) {
                    if inside { hovered = index } else if hovered == index { hovered = nil }
                }
            }
            .accessibilityElement()
            .accessibilityLabel(segment.title)
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { select(index, animation: settle) }
    }

    @ViewBuilder
    private func label(for segment: GlassSegment<Value>, isActive: Bool) -> some View {
        switch style {
        case .icons:
            Image(systemName: segment.icon ?? "circle")
                .font(.system(size: 15, weight: .medium))
                .symbolVariant(isActive ? .fill : .none)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .frame(width: 36, height: 36)
        case .text:
            Text(segment.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(height: 26)
        }
    }

    // MARK: Geometry

    private var selectedIndex: Int? {
        segments.firstIndex { $0.value == selection }
    }

    /// The segment that reads as selected: the one under the lens while dragging.
    private var activeIndex: Int? {
        if let lensX { return nearestIndex(to: lensX) }
        return selectedIndex
    }

    private var highlightRect: CGRect? {
        guard let selectedIndex, let base = frames[selectedIndex] else { return nil }
        guard let lensX else { return base }
        // While dragging, the lens takes the width of the segment it's over
        let width = nearestIndex(to: lensX).flatMap { frames[$0]?.width } ?? base.width
        return CGRect(x: lensX - width / 2, y: base.minY, width: width, height: base.height)
    }

    private func nearestIndex(to x: CGFloat) -> Int? {
        frames.min { abs($0.value.midX - x) < abs($1.value.midX - x) }?.key
    }

    private func clampedLensX(_ x: CGFloat) -> CGFloat {
        let mids = frames.values.map(\.midX)
        guard let lo = mids.min(), let hi = mids.max() else { return x }
        return min(max(x, lo), hi)
    }

    // MARK: Interaction

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { value in
                // Below a few points of movement this is still a click
                guard lensX != nil || abs(value.translation.width) > 3 else { return }
                if lensX == nil {
                    // Lift the lens from where the highlight currently is
                    let start = selectedIndex.flatMap { frames[$0]?.midX } ?? value.startLocation.x
                    withAnimation(settle) { lensX = start }
                }
                withAnimation(follow) { lensX = clampedLensX(value.location.x) }
            }
            .onEnded { value in
                if let lensX {
                    let target = nearestIndex(to: lensX)
                    withAnimation(settle) {
                        self.lensX = nil
                        if let target { selection = segments[target].value }
                    }
                } else if let tapped = frames.first(where: { $0.value.contains(value.location) })?.key
                            ?? nearestIndex(to: value.location.x) {
                    select(tapped, animation: .snappy(duration: 0.32, extraBounce: 0.06))
                }
            }
    }

    private func select(_ index: Int, animation: Animation) {
        guard segments.indices.contains(index), segments[index].value != selection else { return }
        withAnimation(animation) { selection = segments[index].value }
    }
}

// MARK: - Pieces

private struct SegmentFramesKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The lifted lens shown while dragging: clear, refractive glass.
private struct GlassLens: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.clear.interactive(), in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
    }
}

private struct GlassCapsuleBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}

private enum SegmentPalette {
    static let selection = adaptive(light: NSColor.black.withAlphaComponent(0.08), dark: NSColor.white.withAlphaComponent(0.16))
    static let selectionRim = adaptive(light: NSColor.black.withAlphaComponent(0.06), dark: NSColor.white.withAlphaComponent(0.12))
    static let hover = adaptive(light: NSColor.black.withAlphaComponent(0.04), dark: NSColor.white.withAlphaComponent(0.06))

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}
