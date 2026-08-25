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

---

## Current Status (Phase 8 - COMPLETE ✅)

### ✅ Working:
- Storage system (SharedPreferences + Persistent Chrome Profile)
- 2D garden display (frozen)
- 3D scene with Tier progression (Tiers 1-5), Biome distribution, Anti-cluttering (min spacing 7.5), and Luxury HUD
- Corrected 3D Asset paths in `asset_map.dart`
- Dhikr counter with lazy sync
- 3 Agent Skills active: `flutter-elite-engineering`, `three-dart-3d-mastery`, `spiritual-luxury-ui`

### 🎯 Active Next Phase:
**Phase 9: Paradise Environment & Models Upgrade**:
- Celestial River / Water stream
- Floating Light Particles
- Gentle Terrains & Hills
- Model tap inspection & richer model variety

---

## See Also
- `PROJECT_STATE.md` → current state & progress
- `ROADMAP.md` → full feature roadmap
- `README.md` → setup & development guide
