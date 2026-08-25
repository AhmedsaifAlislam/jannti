---
name: spiritual-luxury-ui
description: Design system and UX guidelines for luxury spiritual & Islamic mindfulness apps. Covers Sacred geometry, emerald & gold palettes, Arabic typography hierarchy, meditative cadence, glassmorphic elevation, and haptic feedback.
---

# Spiritual Luxury UI/UX Design System (Jannati Standard)

## 1. Aesthetic DNA & Color Palette
- **Sacred Emerald & Deep Nocturne**:
  - Background Canvas: `#071B12` to `#0D2818` (deep celestial forest/night).
  - Glass Card Base: `#0D2818` with `0.8 - 0.9` opacity + `BackdropFilter` or soft borders.
- **Divine Gold Accents**:
  - Primary Gold: `#FFD700` / `#F9A825` (radiance, badges, key headers).
  - Gold Hairlines: `#FFD700` with `0.15 - 0.3` opacity for delicate card borders.
  - Emerald Glows: `#2E7D32` to `#4CAF50` for growth, life, and natural elements.

## 2. Arabic Typography Mastery
- **Quranic & Sacred Adhkar**: Always use `fontFamily: 'Amiri'` with generous line height (`1.5 - 1.8`) and bold weights for sacred texts and numerical values.
- **UI Elements, Labels & Subtitles**: Use `fontFamily: 'GESSTwo'` (weights: Light 300, Medium 500, Bold 700) for UI navigation, subtitles, and buttons.
- **Numerals**: Always format numbers to Arabic digits (`NumberFormatter.toArabic(n)`) in religious contexts or use bold stylized golden counters.

## 3. Glassmorphism & Double-Bezel Architecture
- **Layered Elevation**: Cards should have a subtle outer ring (`Border.all(color: Color(0xFFFFD700).withValues(alpha: 0.15), width: 1)`), generous rounded corners (`BorderRadius.circular(20)`), and deep soft shadows (`BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: Offset(0, 4))`).
- **Interactive Feedback**:
  - Button presses must give sensory tactile feedback (`HapticFeedback.lightImpact()`).
  - Progress counters should pulse gracefully upon completion of cycles (33, 100).

## 4. Meditative Rhythm & Respectful Tone
- Copywriting must be spiritually uplifting, peaceful, and respectful.
- Animations should be calm and fluid (easing curves with 300-600ms durations, avoiding rapid or distracting flashes).
