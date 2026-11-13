# Wizit 🪟⏱️
### A Clean, Native macOS Glassmorphic Digital Clock Widget

**Wizit** is a native macOS desktop clock widget crafted in Swift and SwiftUI. Designed specifically for macOS Sonoma, Sequoia, and Apple Silicon, it delivers a realistic **Liquid Glass** aesthetic that blends into your desktop wallpaper with full real-time customization controls.

---

## ✨ Features

- **Liquid Glass Aesthetics**:
  - **Dynamic Backdrop Vibrancy**: Native `NSVisualEffectView` blending into your desktop wallpaper in real-time.
  - **Specular Rim Light**: Top-left incident light bevel simulating light refracting through thick curved glass.
  - **Convex Surface Sheen**: Optical glare layer across the glass face for physical depth.
  - **Multi-Stage Ambient Shadow**: Diffused soft drop-shadow with contact rim to float naturally over any wallpaper.
- **Real-Time Settings Panel**:
  - **Transparency & Blur Material**: Ultra Thin, Thin, Regular, Thick, HUD Dark, and Full Screen.
  - **Liquid Refraction Strength**: Adjust optical caustics and edge refraction bevel.
  - **Specular Rim Highlight**: Control incident illumination intensity.
  - **Glass Tint & Opacity**: Add custom color hues (Ice White, Amber, Deep Obsidian, Indigo, etc.).
  - **Corner Curvature (Squircle)**: Continuous Apple-style rounded rect adjustment.
- **Clock & Typography**:
  - **12-Hour & 24-Hour** modes with AM/PM indicators.
  - **Smooth Seconds Ticker**: Tabular monospaced digits to prevent numbers from twitching as time updates.
  - **Typography Options**: SF Pro Rounded, SF Pro Display, SF Pro Mono, and New York Serif.
  - **Date & Calendar Capsule**: Clean weekday and date pill with calendar icon.
  - **Scale Slider**: Seamlessly scale the clock from 0.7x to 1.6x.
- **Desktop Behavior**:
  - **Desktop Level**: Pins behind all standard windows right on the wallpaper (stays stationary across Spaces/Mission Control).
  - **Snap to Screen Center**: One-click alignment to the screen's visual center.
  - **Drag Anywhere**: Click and drag to reposition anywhere on your desktop.
  - **Lock Position**: Prevent accidental dragging.
  - **Click-Through Mode**: Pass mouse clicks directly to desktop icons beneath.
  - **Menu Bar Companion**: Quick access to presets, settings, and lock toggles via `clock.badge.sparkles`.

---

## 🎨 Curated Glass Presets

| Preset | Description |
| :--- | :--- |
| **Apple Vision Glass** | Signature VisionOS frosted glass with crisp specular rims. |
| **Pure Frosted Crystal** | High-refraction icy highlight bevels with bright reflections. |
| **Deep Obsidian** | Smoked dark glass with subtle perimeter lighting for dark wallpapers. |
| **Sunset Amber** | Warm golden-hour glass cast with luminous rim highlights. |
| **Aurora Indigo** | Deep atmospheric indigo tint with high backdrop vibrancy. |
| **Minimalist Ghost** | Ultra-clean high translucency with a faint sub-pixel edge. |

---

## 🚀 How to Run

### Option 1: Launch the Pre-built App Bundle
```bash
open Wizit.app
```

### Option 2: Run directly via Swift SPM
```bash
swift run
```

### Option 3: Rebuild the standalone `.app`
```bash
./scripts/build_app.sh
```

---

## ⚙️ Quick Controls

- **Right-Click Widget**: Context menu for Settings, Presets, Snap to Center, Lock, and Quit.
- **Hover on Widget**: Click the gear icon in the top-right corner to open Settings.
- **Menu Bar**: Click the clock icon in the top menu bar to change presets, lock position, or open Settings.
