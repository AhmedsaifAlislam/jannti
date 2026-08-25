---
name: flutter-elite-engineering
description: Expert Flutter & Dart engineering skill for building 60/120 FPS high-performance apps, pixel-perfect reactive UI, advanced animations, custom canvas painters, and bulletproof state & resource management.
---

# Flutter & Dart Elite Engineering Standard

## 1. Core Directives
- **Performance First (60/120 FPS Guarantee)**: Zero jank, zero unnecessary widget rebuilds.
- **Micro-interactions & Physics**: Fluid spring physics, custom cubic-bezier curves (`Curves.easeOutCubic`, `Curves.elasticOut`), and animated builders.
- **Resource & Memory Safety**: Every `AnimationController`, `TextEditingController`, `StreamSubscription`, and 3D plugin context MUST be safely disposed in `dispose()`.
- **Stateless/Stateful Discipline**: Extract subtrees into small, dedicated `const` widgets or `ValueListenableBuilder` to isolate rebuilds.

## 2. Advanced Animation & Rendering Rules
- **RepaintBoundary**: Wrap complex static or canvas-rendered widgets in `RepaintBoundary` to prevent global repaints during animations.
- **Implicit & Explicit Animations**:
  - Use `AnimatedContainer`, `AnimatedScale`, `AnimatedOpacity` with `Curves.easeOutBack` or `Curves.easeInOutCubic` for UI state changes.
  - Use `AnimationController` with `TickerProviderStateMixin` for continuous atmospheric pulses, loops, and particle effects.
- **Haptic & Sensory Feedback**:
  - Call `HapticFeedback.lightImpact()` on tap/increment.
  - Call `HapticFeedback.mediumImpact()` on milestone completions (e.g. 33, 100 dhikr).

## 3. Clean Flutter Code Patterns
- Use semantic color constants and cohesive design tokens.
- Prefer `LayoutBuilder` / `MediaQuery` safe clamp bounds instead of hardcoded screen dimensions.
- Use `Directionality(textDirection: TextDirection.rtl)` with care around symmetric icon/text layouts.
- Null-safety first: Defensive decoding on any JSON/storage payloads (`as num?` -> `toDouble()`).
