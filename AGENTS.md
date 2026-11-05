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
- **UI**: Glassmorphism + Luxury Spiritual Aesthetic (Amiri + Cairo)

---

## Key Files

### Frozen (Don't Touch):
- `lib/screens/garden_screen.dart` - 2D world (frozen after Phase 4H)
- `lib/utils/garden_world_manager.dart` - world dimensions/logic

### Active Development:
- `lib/screens/jannati_3d_screen.dart` - 3D scene (Tiers + Biomes + HUD)
- `lib/three/asset_map.dart` - GLB mapping + staged-model table
- `lib/three/model_fit.dart` - per-tier height and pivot correction
- `tool/assets/repack_glb.py` - GLB repack/downscale pipeline
- `assets/3d/` - Model directories (tier1…tier5, root models)
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
- Every layer is a **playlist of ~60 s segments** (wind keeps its 100 s original, night its 45 s one) that crossfade into the next over **6 s**; slot 0 uses the layer id as its player key, slot 1 uses `id#1`.
- Crossfade envelope: incoming = `base × p`, outgoing = `base × (1 − p)` → their sum is exactly the layer gain, so `max ≤ master` still holds at every instant.
- Ceiling per layer = `master / sqrt(n)`; **exactly one** layer sits on the ceiling, the others on a shuffled `0.72 / 0.58 / 0.45 / 0.34` ladder.
- Leader rotates every 20–40 s with a ~5 s ramp; one random nudge every 5–9 s.
- `max layer ≤ master` and `sqrt(Σg²) ≤ master` — the **gain sum may exceed** master (that is expected, don't assert it).
- Quran is a **separate channel**: exclusive inside itself, plays at `master × 0.92`, ducks nature to 50%.
- `stopMix()` keeps the selection; `syncFromStorage()` restores it without auto-play.
- Nature stays pure nature — no music, no instruments.
- All assets are normalized to **−24 LUFS** with static gain only (no dynamic processing).

### 🗿 Model invariants (do not break):
- `pubspec.yaml` lists every staged GLB **by hand**: a directory entry in Flutter is **not** recursive, so `assets/3d/` only bundles the five root models. That is why the tier folders never reached the APK before.
- `kBundledModelAssets` in `lib/three/asset_map.dart` mirrors those entries; `test/asset_map_test.dart` fails when the two drift apart.
- Only `palmTree` and `tree` have staged lineages. Buildings (house / palace / mosque / treasure) keep their procedural meshes on purpose — the GLB house and palace are lower fidelity than what the scene draws.
- Pivot correction lives in `lib/three/model_fit.dart`. The exports do not share a pivot: `palm_medium` reaches **y = −2.58** before scaling. Never scale a model without `fitModelToGround`.
- Stage heights are `7 / 9 / 11 / 14 / 18` (`tierHeight`); the cap at tier 5 is what makes a reused stage-4 file still read as a bigger tree.
- The GLB cache key is `path#tier`, not `path` — the same file can serve two stages at two heights.
- New or re-shrunk models go through `tool/assets/repack_glb.py` (512 px textures). It verifies geometry is bit-identical, so a repack that changes a vertex fails the run.
- **A cached model is cloned on every use, and `BufferAttribute.clone()` only knows Float32/Uint8/Uint16.** Every export indexes with 32 bits, so `makeModelCloneable` narrows the index to 16 bits *before* the model is cached; without it `scene.clone(true)` throws and the procedural mesh silently stays.
- **`metalness` is forced to 0 at load.** The exports ship `metallicFactor: 1.0` and the scene has no environment map, so a fully metallic material renders black.
- **Textures are re-encoded as raw RGBA and handed over as a `DataTexture`** (`lib/three/model_texture.dart`). The plain-texture upload reads `image.data`, which a browser image element does not have, so WebGL received an incomplete texture and sampled it as opaque black. Tier-5 gold uses base colour + a little emissive for the same no-env-map reason.
- Unused on purpose: `tier1/pine_seedling.glb`, `tier2/pine_small.glb`, `tier1/sakura_seedling.glb` — there is no `pine` or `sakura` reward type yet, so they are **not** bundled.

### 🎯 Active Next Phase:
**Phase 9: Paradise Environment & Models Upgrade** (in this order):
1. Model tap inspection (`Raycaster` + glass card) — lowest risk
2. Palm frond sway in the render loop
3. Floating light particles
4. Celestial river
5. Gentle terrains (optional, highest risk)

### 📦 Repo invariants (after the 2026-11-01 history rewrite):
- The public repo no longer carries the tier-models zip, `.blend` sources or `lib/3d/`.
  `AssetDownloadService.remoteZipUrl` points at the **`models-v1` Release asset** — that
  Release must never be deleted, or the download button breaks in already-installed apps.
- Fonts are **Cairo (OFL 1.1)** + Amiri. `GESSTwo` survives only as an alias to the same
  Cairo files for the frozen 2D screen. Never add a commercial font back to the repo.
- **Never commit a keystore / `key.properties`** — releases are still signed with debug keys.
- Details and archive locations: `PROJECT_STATE.md` §7.

---

## See Also
- `PROJECT_STATE.md` → current state & progress
- `ROADMAP.md` → full feature roadmap
- `README.md` → setup & development guide
