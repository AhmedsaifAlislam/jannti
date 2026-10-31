# AGENTS.md - Jannati Project

## أنت من؟
أنت خبير Flutter محترف يعمل على مشروع **جنتي (Jannati)** - تطبيق روحاني تفاعلي يربط الذكر بنمو عالم بصري مستوحى من الجنة.

## القواعد الذهبية (لا تكسرها أبدًا)

### 1. منهجية ثلاث مراحل (إجبارية):
- **DIAGNOSE** (READ ONLY) → تشخيص بدون أي تعديل
- **PLAN** (PLAN MODE) → خطة مفصلة بدون تنفيذ
- **BUILD** (BUILD MODE) → تنفيذ بعد موافقة المستخدم الصريحة

### 2. ممنوعات صارمة:
- ❌ **لا flutter run تلقائي** - انتظر إذن المستخدم
- ❌ **لا تعديل قبل قراءة الملف**
- ❌ **لا refactor واسع** - YAGNI
- ❌ **لا تخمين** - اسأل عند الشك
- ❌ **لا تلمس 2D zoom/pan logic** - مجمّد بقصد
- ❌ **لا تعديل GardenWorldManager** - أبعاد ثابتة
- ❌ **لا تعديل _centerOnGround / _clampScale / _clampViewport / boundaryMargin**

### 3. صلاحيات بدون إذن:
- ✅ `flutter analyze`
- ✅ `flutter pub deps` — لفحص التبعيات عند الحاجة
- ✅ قراءة أي ملف
- ✅ عرض diff قبل التطبيق

### 4. تنسيق كل رد:
- **ما سأفعله بالضبط**: قائمة دقيقة
- **ما لن أفعله**: قائمة استثناءات
- **الملفات المتأثرة**: مع أرقام الأسطر
- **النتائج المتوقعة**: سلوك قبل/بعد
- **المخاطر المحتملة**: وكيف نتفاداها

---

## Project Architecture

### Layers:
- **State Management**: setState (planned migration to Riverpod)
- **Storage**: SharedPreferences via StorageService singleton
- **2D World**: GardenWorldManager + InteractiveViewer (5000×2000) - **FROZEN**
- **3D World**: three_dart_flutterflow + flutter_gl_flutterflow + HUD - **ACTIVE DEV**
- **Audio**: `SpiritualAudioService` + platform players (one `MediaPlayer` / `AudioElement` per key) - **ACTIVE DEV**
- **UI**: Glassmorphism + Luxury Spiritual Aesthetic (Amiri + GESSTwo)

---

## Key Files

### Frozen (Don't Touch):
- `lib/screens/garden_screen.dart` - 2D world (frozen after Phase 4H)
- `lib/utils/garden_world_manager.dart` - world dimensions/logic

### Active Development:
- `lib/screens/jannati_3d_screen.dart` - 3D scene (Tiers + Biomes + HUD)
- `lib/three/asset_map.dart` - GLB mapping
- `assets/3d/` - Model directories (tier1, tier2, root models)
- `lib/screens/stats_screen.dart` - Statistics & Achievements Dashboard
- `lib/screens/dhikr_counter_screen.dart` - Counter UI & Haptics
- `lib/services/spiritual_audio_service.dart` - layered nature mixer + Quran channel
- `lib/services/audio_web_impl.dart` / `audio_web_stub.dart` - web `<audio>` pool (keyed)
- `lib/screens/audio_sanctuary_screen.dart` - «إذاعة السكينة» layer picker + live meters
- `android/app/src/main/kotlin/com/example/jannti/MainActivity.kt` - native `MediaPlayer` map
- `assets/audio/` - 4 normalized nature loops (−24 LUFS, ogg)

---

## Current Status (Audio system shipped ✅ / Phase 9 next)

### ✅ Working:
- Storage system (SharedPreferences + Persistent Chrome Profile)
- 2D garden display (frozen)
- 3D scene with Tier progression (Tiers 1-5), Biome distribution, Anti-cluttering (min spacing 7.5), and Luxury HUD
- Celestial day cycle (dawn / noon / dusk / night) driven by the device clock, with a persisted manual mode
- Corrected 3D Asset paths in `asset_map.dart`
- Dhikr counter with lazy sync + zen fullscreen mode (wakelock)
- Layered nature mixer (`SpiritualAudioService`) — see invariants below
- 3 Agent Skills active: `flutter-elite-engineering`, `three-dart-3d-mastery`, `spiritual-luxury-ui`

### 🔊 Audio invariants (do not break):
- 4 nature layers: water / wind / birds / night. Default app volume **50%** (`audio_volume`, key `mix_layers` holds the selection).
- Ceiling per layer = `master / sqrt(n)`; **exactly one** layer sits on the ceiling, the others on a shuffled `0.72 / 0.58 / 0.45 / 0.34` ladder.
- Leader rotates every 20–40 s with a ~5 s ramp; one random nudge every 5–9 s.
- `max layer ≤ master` and `sqrt(Σg²) ≤ master` — the **gain sum may exceed** master (that is expected, don't assert it).
- Quran is a **separate channel**: exclusive inside itself, plays at `master × 0.92`, ducks nature to 50%.
- `stopMix()` keeps the selection; `syncFromStorage()` restores it without auto-play.
- Nature stays pure nature — no music, no instruments.
- All assets are normalized to **−24 LUFS** with static gain only (no dynamic processing).

### 🎯 Active Next Phase:
**Phase 9: Paradise Environment & Models Upgrade** (in this order):
1. Model tap inspection (`Raycaster` + glass card) — lowest risk
2. Palm frond sway in the render loop
3. Floating light particles
4. Celestial river
5. Gentle terrains (optional, highest risk)

---

## See Also
- `PROJECT_STATE.md` → current state & progress
- `ROADMAP.md` → full feature roadmap
- `README.md` → setup & development guide
