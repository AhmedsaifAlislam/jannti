# AGENTS.md - Jannati Project

## أنت من؟
أنت خبير Flutter محترف يعمل على مشروع **جنتي (Jannati)** - تطبيق روحاني تفاعلي يربط الذكر بنمو عالم بصري مستوحى من الجنة.

## القواعد الذهبية (لا تكسرها أبدًا)

### 1. منهجية ثلاث مراحل (إجبارية):
- **DIAGNOSE** (READ ONLY) → تشخيص بدون أي تعديل
- **PLAN** (PLAN MODE) → خطة مفصلة بدون تنفيذ
- **BUILD** (BUILD MODE) → تنفيذ بعد موافقة المستخدم الصريحة

### 2. ممنوعات صارمة:
- ❌ **لا flutter run في DIAGNOSE** — في BUILD إجباري بعد كل تنفيذ، وفي PLAN مسموح عند الحاجة للتحقق (القاعدة ٥)
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

### 5. `flutter run` بعد كل تنفيذ في وضع BUILD (إجباري) — ومسموح في PLAN:
- بعد أي تعديل كود أو أصول في BUILD، شغّل التطبيق وتأكد بعينك —
  `flutter analyze` والاختبارات لا تكفيان، وما لم يُرَ بالعين لا يُعدّ منفَّذًا.
- في PLAN: شغّله إن كان التحقق من سلوك حالي أو تشخيص يحتاجه، **بلا أي تعديل كود**.
- الوصفة الافتراضية (ويب، نفس منفذ العمل):
  `flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1`
- **أوقف أي سيرفر قديم على 8080 قبل التشغيل.** سيرفر من جلسة سابقة يخدم
  نسخة قديمة ويجعل التعديل يبدو كأنه لم يُطبَّق — حدث فعلًا 2026-11-17 وبقي
  المستخدم يرى «واحة 2.5D» بعد حذفها بـ١٨ ساعة.
- بعد الإقلاع افتح `http://127.0.0.1:8080/?v=<طابع-زمني>` لكسر الكاش
  والتقط لقطة قبل الحكم.
- للتشغيل على أندرويد: `flutter run -d <device-id>` ثم لقطة من الجهاز نفسه.

---

## Project Architecture

### Layers:
- **State Management**: setState (planned migration to Riverpod)
- **Storage**: SharedPreferences via StorageService singleton
- **2D World**: ~~GardenWorldManager + InteractiveViewer (5000×2000)~~ **حُذف 2026-11-17** مع تبويب «الواحة 2.5D» — لا تعده.
- **3D World**: three_dart_flutterflow + flutter_gl_flutterflow + HUD - **ACTIVE DEV**
- **Audio**: `SpiritualAudioService` + platform players (one `MediaPlayer` / `AudioElement` per key) - **ACTIVE DEV**
- **UI**: Glassmorphism + Luxury Spiritual Aesthetic (Cairo فقط — الأدوار في `lib/theme/app_typography.dart`)

---

## Key Files

### محذوف بقصد (لا تعده):
- `lib/screens/garden_screen.dart` · `lib/utils/garden_world_manager.dart` ·
  `lib/screens/jannati_isometric_screen.dart` — حُذفت 2026-11-17 مع 20 صورة
  و`GESSTwo` (‏`PROJECT.md` §3.6/B7). أي مرجع لواحد منها يكسر الترجمة.

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
- تبويب «جنتي»: مشهد 3D داخل `IndexedStack`، يُبنى عند أول زيارة ثم يبقى حيًّا، ويختفي الشريط السفلي بعد ٣ ثوانٍ
- 3D scene with Tier progression (Tiers 1-5), Biome distribution, Anti-cluttering (min spacing 8.5), and Luxury HUD
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
- Pivot correction lives in `lib/three/model_fit.dart`. The exports share neither scale nor pivot: the staged palms are authored in centimetres (tier 5 is **7 561** units tall), the tree exports sit at another scale, and the bases are a few units off zero. Never scale a model without `fitModelToGround`.
- **الموديل يُدفن في الأرض بنسبة من ارتفاعه**: `kPalmGroundSink` =
  `0.40 / 0.16 / 0.13 / 0.13 / 0.15` للنخيل، و`kTreeGroundSink = 0.10` للشجر،
  والمباني والكنوز **لا** تُدفن. قاعدة النخلة العشبية جزء من ملف الـGLB وتشغل
  **٥٧٪** من ارتفاع `palm_seedling` و١٥–٢٣٪ من بقية المراتب، فتركها على `y = 0`
  كان يجعل الشتلة «عشبًا بطول الموديل». `fitModelToGround(..., sink:)` يطرح
  الدفن **بعد** تثبيت القاعدة على الصفر، فالدالة تبقى idempotent (إعادة
  الاستدعاء تصفّر القاعدة ثم تطرح مرة واحدة). الظل والحلقة يبقيان على سطح الأرض،
  وارتفاع المرتبة المقاس لا يتغيّر — الدفن مرئي فقط.
  `test/model_fit_test.dart` ← «الدفن في الأرض» يحرس النسب وبقاء سلّم الـ٢٠٪
  **بعد** الدفن.
- Stage heights are `0.6 / 2.3 / 3.4 / 5.5 / 9` (`tierHeight`). One world unit is
  a metre (the bridge deck is 1.2 thick, its lanterns 3.3 high), and the meadow
  grass is 0.35–0.70, so the tier-1 seedling sits *inside* the grass. `1.2` and
  then `0.85` still read as a small tree once nine of them could stand side by
  side. An earlier ladder (`7 / 9 / 11 / 14 / 18`, then `3 / 4.2 / 6 / 9 / 13`)
  was far worse. The cap at tier 5 is what makes a reused stage-4 file still
  read as a bigger tree.
  **الترقية لا تُقصّر الموديل**: أقصر موديل في مرتبة يتجاوز أطول موديل في
  المرتبة السابقة بـ**٢٠٪ على الأقل**. تير ٢ كان `2.0` وأطول تير ١ هو ١٫٨٣
  (ذهبب المرحلة ٢)، أي +٩٪ فقط — كان يُقرأ تراجعًا، فرُفع إلى `2.3` (+٢٦٪).
  القاعدة يحرسها `test/model_fit_test.dart` ← «سلّم الأحجام لا ينكمش عند الترقية»
  عند عتبات ٩٩/٩٩٩/٤٩٩٩/٩٩٩٩ فعلًا، فلا تُخفَّض قيمة بلا أن يفشل الاختبار.
- **The completed tier-1 model is lifted, not the area.** `modelInstanceHeight`
  **multiplies** `tierHeight(1)` by `kTier1StageLift` (`1.0 / 2.3 / 2.7`) for the
  merged blocks only, so a grown model ≈ 1.45 and a coloured one ≈ 1.83 while
  the waiting seedlings stay at 0.6. That is the jump the player sees at ten
  rewards, and both stay under `tierHeight(2) = 2.3` so no promotion shrinks.
- **`lib/three/model_evolution.dart` is the single source of truth for growth.**
  The reward count picks a tier (`100 / 1000 / 5000 / 10000`) *and* an in-tier
  stage: tier 1 (1–99) turns over at 10 and 25, later tiers at 20 % / 30 % /
  60 % / 80 % of their span, and tier 5 repeats every 10 000 above 20 000.
  Nothing else adds or promotes models: `_applyEvolution` rebuilds the scene
  from `rewards_list` on every change. `_promoteModelsOfType` and
  `_syncFromDhikrRewards` no longer exist — do not bring them back.
- Stage 0 leaves the seedling **untouched**; scaling starts at 10 rewards (+5 %)
  and adds 8 % per later stage, capped at `1.25×`. Tint only appears from stage
  1 inward and is per tier: `0xFFE8C97A / 0xFF7FE3B0 / 0xFFFFD700 / 0xFFFFF3C4 /
  0xFFFFF8E1`. One to nine rewards show that many seedlings; **every ten merge
  into one grown model**, and the leftover still shows as seedlings: 11 = one
  grown + one seedling, 19 = one grown + nine, 20 = two grown, 99 = nine grown +
  nine seedlings. Above tier 1 the type collapses to a single model.
- **التلوين مزج ٠٫٤٥ + وهج ٠٫١٨، لا ٠٫٨.** المادة تُضرب في صورة الخامة، فمزج
  ٠٫٨ (المعاير على المجسّمات الإجرائية المسطّحة) كان يمحو خامة النخيل: سعف
  المرتبة ٢ يخرج نعناعيًا والثالثة ليمونيًا. المقارنة في `ladder_s0/s2b.png`
  (مرحلة ٠ مقابل ٢ على المراتب الخمس) هي المرجع — لا ترفع النسبة بلا صورة.
- `_applyEvolution` styles **each index separately** (`modelIsFull`): only the
  completed blocks take the tier's scale/tint, the waiting seedlings stay at
  `tier 1 / stage 0 / 1.0`. It also sorts the existing models by stage before
  assigning, so the grown ones stay in front even if `rewards_3d` was written in
  another order. Do not collapse this back to one style per type.
- **Decor (`isDecor`) is the only models not derived from `rewards_list`.** The
  bottom bar plants it, it lives 24 h, it never renews by itself, and
  `_sweepExpiredDecor` drops it on load. **One decor per type at a time**: the
  single button refuses a type that is already planted, and «زينة ٢٤س» fills
  only the missing types (it is disabled once all six have one). The «زينة
  الجنة» sheet reads `_decorSlotOf` every second and shows each type's random
  tier/stage plus a live countdown. The three welcome plants are decor with
  `expiresAt: null` **and `track: false`**, so they never reach `rewards_3d`,
  never count as growth, and are removed when a real decor of their type is
  planted.
- `addModelAt(..., track: false)` builds a model with **no `_SavedEntry`**. The
  spacing helpers and `_writeSaved` both read that list, so an untracked model
  is invisible to persistence by construction — do not "fix" that by always
  registering an entry.
- `_kMaxSceneModels` is 120. The meadow (46×100 per bank) with `_kMinSpacing`
  8.5 holds ~127 spots; the old cap of 65 filled up and made the garden look
  frozen while the dhikr counter kept counting.
- The GLB cache key is `path#tier`, not `path` — the same file can serve two stages at two heights.
- **مراحل النخيل الخمس مقصوصة من `assets/نخيل.glb`.** الملف فيه **خمس** نباتات لا
  ستة، فـ`--clusters 6` كان يخترع سادسًا. القصّ:
  `split_glb.py --groups-x "2901,5973,9100,12700" --keep-components 0.005
  --drop-box "12200,12800,6000,6800,1900,2600"` ثم
  `prepare_model.py --texture-size 256` (تطبيع + `pack_accessors` + PNG جانبي
  ٢٥٦ بكسل). `--by-triangle` و`--anchors` جرّبا وسقطا: التيجان متشابكة فيخرج
  القصّ شظايا طائرة. القاعدة العشبية جزء من القطعة وتبقى، والمقاسات النهائية
  ١٨٧ / ٢٢٤ / ٢٥٣ / ٣٤٨ / ٥٢٠ ك.ب.
- **مراحل الشجر الخمس مقصوصة من `assets/trees.glb`.** الملف ٦٬٣٧١٬٧٧٦ مثلثًا
  وفيه **خمس** نباتات على بلاطات عشب مربعة. القصّ:
  `split_glb.py --groups-x "2880,5860,8520,12030" --drop-below 0.063
  --min-tris 8 --drop-box "0,2880,0,300,0,4000"`. `--drop-below` نسبة من ارتفاع
  **الملف كله** (0..5104) فالـ0.063 قطع عند Y≈322: أسقط ٣٢٨٠ جزيرة من ٩٧٨٤
  (فرش المرج العشبي، ٣٤٦ ألف مثلث) وأبقى الشتلة، و`--drop-box` حذف بلاطتها
  البنية (٥٨٧ مثلثًا) لأنها تقع تحت القطع.
  ثم **تبسيط كل قطعة بنسبتها لوحدها**: `--ratio 0.65 / 0.18 / 0.0157 / 0.0097 /
  0.0085` ← `weld` ← `prune` ← `dequantize` ← `prepare_model.py --texture-size
  256`. التبسيط الموحّد 0.012 على الملف كله **دمّر الشتلة** (٩٣ مثلثًا)، فالقصّ
  أولًا غير قابل للتفاوض.
  النتيجة `tree_seedling / tree_sapling / tree_growing / tree_fruitful /
  tree_celestial` بـ٥٨٥١ / ٩٠٠٠ / ١١٩٧٥ / ١٤٠٥٤ / ٢٢٥٣٣ مثلثًا و١٤٢ / ٢٤٩ /
  ٤٧٨ / ٦٤٣ / ١٠٢٠ ك.ب. القطع يحمل كامل مخزن الرؤوس (١٧٢–٢٠٠ م.ب للقطعة)؛
  `prune` ثم `prepare_model` هما ما يعيدانها للحجم النهائي.
- `split_glb.py` **must** rewrite `accessor.min/max` for POSITION, otherwise the
  stage keeps the source sheet's bounding box and `fitModelToGround` scales the
  model to the size of the whole sheet.
- New or re-shrunk models go through `tool/assets/repack_glb.py` (512 px textures). It verifies geometry is bit-identical, so a repack that changes a vertex fails the run.
- **A cached model is cloned on every use, and `BufferAttribute.clone()` only knows Float32/Uint8/Uint16.** Every export indexes with 32 bits, so `makeModelCloneable` narrows the index to 16 bits *before* the model is cached; without it `scene.clone(true)` throws and the procedural mesh silently stays.
- **`metalness` is forced to 0 at load.** The exports ship `metallicFactor: 1.0` and the scene has no environment map, so a fully metallic material renders black.
- **Textures are re-encoded as raw RGBA and handed over as a `DataTexture`** (`lib/three/model_texture.dart`). The plain-texture upload reads `image.data`, which a browser image element does not have, so WebGL received an incomplete texture and sampled it as opaque black. Tier-5 gold uses base colour + a little emissive for the same no-env-map reason.
- Unused on purpose: `tier1/pine_seedling.glb`, `tier2/pine_small.glb`,
  `tier1/sakura_seedling.glb` — there is no `pine` or `sakura` reward type yet,
  so they are **not** bundled. The four old tree exports
  (`tier1/green_tree_seedling`, `tier2/green_tree_small`,
  `tier3/green_tree_medium`, `tier5/fantasy_tree`) still sit on disk but are
  **neither declared in `pubspec.yaml` nor listed in `kBundledModelAssets`** —
  the five `tree_*` files replaced them.
- **Every model texture is a sidecar PNG next to the GLB, never embedded.**
  `GLTFLoader` hands an embedded image to its web loader as its own `Blob`
  wrapper; that loader only understands `String` and `html.Blob`, so it throws
  inside `onLoad` and the future never completes (the model dies on the 15 s
  timeout). `repack_glb.py` and `prepare_bridge.py` write `<name>.png` beside
  the GLB and rewrite the image to an external `uri`.
- **Never set `texture.encoding` on a model map.** With `sRGBEncoding` the
  uploader asks for an `SRGB8_ALPHA8` internal format and this build never gets
  a complete texture: the sampler returns RGB 0 with alpha 1, so the model
  draws as an opaque black silhouette. `makeTexturesUploadable` deliberately
  drops the encoding (see `lib/three/model_texture.dart`).
- **`flatShading: true` on a `MeshPhongMaterial` renders thin cones black**
  (grass blades, mountain cones). Keep it off on those, and give the blades a
  small `emissive` from their own colour — their vertical faces catch almost no
  sun and read as dark triangles against the meadow.
- **الجسر (`kBridgeModel` = `assets/3d/bridge.glb`) موديل خارجي، لا صندوق مبني.**
  وصل بمليون مثلث؛ يُصغَّر بـ`gltf-transform` (simplify 0.04 + dequantize) ثم
  يمرّ على `tool/assets/prepare_bridge.py` الذي يطبخ `KHR_texture_transform`
  داخل UV ويحذف webp وخريطة النواظم. لا تعيد تصديره بلا هاتين الخطوتين:
  المحمّل لا يفهم `KHR_mesh_quantization` ولا `KHR_texture_transform`.
  قياسه غير متساوٍ عن قصد (`19 / 11.5 / 10` ومركزه `y = 2.15`)، وقياس موحّد
  يجعله برجًا لا جسرًا.
- **الأرض صارت موديلات، لا مستويات مكسوّة.** بعد موديلات FreeLowPolyForest لم
  يبقَ من خامات الأرض مستخدمًا إلا اثنتان: `ground_spots` على كومات الشجر
  و`cliff_rock` على جرف الجزيرة. `grass_base` و`grass_rocks` و`river_water`
  ما زالت على القرص ومعلنة في `pubspec.yaml` بلا قارئ — لا تُبنَ عليها.
  **والهضبة ليست من هؤلاء**: خامتها `plateau.jpg` داخل GLB الخاص بها، ولا تُستبدل
  بـ`ground_spots`. وأي خامة تُركَّب على هندسة تتكرر: التكرار يُضرب على **UV
  الهندسة** لا على `texture.repeat`، لأن المُصيِّر لا ينسخ مصفوفة الخامة إلى الظلّال.
- **`assets/3d/nature/` تُسرد ملفًا ملفًا في `pubspec.yaml` — ٣٤ سطرًا (١٧ GLB +
  ١٧ صورة).** المدخل المجلدي غير متداخل، و`assets/3d/` يغطي جذرها فقط. غياب هذه
  الأسطر لا يُظهر أي خطأ في Flutter: المشهد يطلب ١٧ مسارًا فيرجع ٤٠٤، والوعود
  لا تكتمل، فتظهر الجزيرة فارغة. الأثر الوحيد في console المتصفح.
  `kNatureMeshPaths` في `lib/three/nature_layout.dart` هو من يطلبها، والاختبار
  «كل شبكة يسردها nature_layout معلنة وموجودة» في `test/asset_map_test.dart`
  يحرس التطابق الآن.
- **تلوين الأرض يُصحَّح في الصورة لا في اللوحة.** شمس الظهيرة `0xFFE082` تضاعف
  الأحمر/الأخضر وتخفض الأزرق، فأي خامة رمادية تخرج صفراء وأي سماوية تخرج خضراء.
  لذلك `river_water` (متوسط ٥٣،٩١،١٢٣) و`grass_rocks` (٩٦،١٠٣،١٣٢) **أزرقان في
  الملف** ليصلا باردين على الشاشة، و`grass_base` مسطّح الترددات المنخفضة لأن
  ضربات فرشاته الكبيرة كانت تُقرأ أقواسًا تلف المرج كله بعد التكرار.
  `tool/assets/prep_ground_textures.py` هو ما يولّدها (رامب لوني للماء + نزع
  تشبّع للصخور + `--flatten-grass` مرة واحدة لكل خامة جديدة).
- **التكرار قليل عن قصد**: لا mipmaps في three_dart (املأ المستوى صفر فقط)،
  فكل تكرار إضافي يحوّل الرغوة والحصى إلى ضجيج عند الزوايا الحادة للكاميرا.
  المرج ١٢×١٧ (مربع ~١٠ وحدات)، الحافة ١×١٨، الماء ٢×١٤.
- **لوحة النهار مجمّدة باختبار** (`test/day_palette_test.dart` يثبّت قيم ١٢:٣٠
  حرفيًا). أي معالجة للأصفرار تكون في ألوان المواد والخامات، لا في
  `day_palette.dart`. تحت شمس `0xFFE082` لا يمكن أن تتجاوز القناة الزرقاء ~٢٠٧،
  فلا تسعَ إلى أبيض أو رمادي نقي: اخفض السطوع حتى لا يُقصّ التظليل.

### 🖐 Interaction invariants (do not break):
- لمس الموديل يمرّ عبر `DomLikeListenable` لا عبر `GestureDetector`: على الويب يُرسم
  المشهد في `HtmlElementView` فلا تدخل اللمسات في نظام إيماءات Flutter أصلًا.
  الربط في `_bindScenePointer()` يُعاد المحاولة كل إطار حتى ينجح (بعد بناء العنصر)؛
  الاعتماد على `addPostFrameCallback` وحده فشل مرة.
- اللمسة تُفرَّق عن السحب بالزمن (≤ 450ms) والمسافة (≤ 14px)، فلا تُفتح بطاقة أثناء
  تدوير الكاميرا.
- **الكاميرا حرة عن قصد** (`initPage`): السحب بالفأرة اليسرى / الإصبع الواحد =
  **PAN** لا دوران، والدوران على الفأرة اليمنى. الدوران التلقائي مطفأ افتراضيًا
  (`_autoRotate = false`) وزرّه باقٍ في الشريط العلوي.
- **إيماءة الإصبعين مخصّصة، وليست `TWO = DOLLY_ROTATE`.** `_controls.touches`
  تحمل `{'ONE': PAN}` **فقط**؛ لو أُعطي المحرّك `DOLLY_ROTATE` دار بأي اتجاه
  ونافس معالجتنا. `_beginTwoFinger` / `_moveTwoFinger` تقيس **منتصف** الإصبعين:
  أفقي = `rotateLeft`، رأسي = `dollyIn`/`dollyOut` (سحب لأعلى يقرّب). الاتجاه
  يُقفل بعد أول **١٢ بكسل** حتى لا تهتز الكاميرا في السحبة المائلة، وإيماءة
  الإصبعين لا تفتح بطاقة الفحص.
  ملاحظة: لوحة لمس اللابتوب ترسل `wheel` لا أحداث لمس، فالإيماءة لا تصلها —
  تحتاج مستمع `wheel` يقرأ `deltaX` (مؤجّل).
- حدود الأوربت: `minDistance = 18`، `maxDistance = 340`، `maxPolarAngle =
  1.483` (≈٨٥°، فتنزل الكاميرا إلى مستوى الأرض تقريبًا)، `panSpeed = 1.0`،
  `screenSpacePanning = true`، `rotateSpeed = 0.7`، `dampingFactor = 0.06`.
  الضباب `Fog(0x134C37, 400, 1000)` — بدأ عند ١٥٠ فذاب نصف الجزيرة البعيد في
  لون الخلفية، و١٠٠٠ تُبقي الجزر الطافية شبه صافية عند أقصى تصغير (٣٤٠).
- حدود نقطة النظر تُثبَّت **قبل** `_controls.update()` في `animate()`:
  x ∈ [-110, 110]، z ∈ [-95, 95]، y ∈ [0, 14] — تغطي الجزيرة **٢٠٧ × ١٧٦**
  كاملة؛ ±٧٨ / ±٥٦ القديمة كانت تقطع ٢٥٪ من العرض و٣٦٪ من العمق.
- كادر الافتتاح ثوابت `_kHome*`: كاميرا **(150, 172, 180)** → هدف **(0, 2, 0)**،
  مسافة **٢٨٩٫٥**، ميل **٣٦°** (البعيد أعلى والقريب أسفل)، وسمت **٣٩٫٨°** عن
  `+z` بلا دوران يمين/شمال. `_resetCamera` يقرأها هي نفسها، فأي تعديل عليها
  يسري على زر «إعادة ضبط المنظور» أيضًا. FOV ٥٦° رأسي على الهاتف و٤٤° على
  سطح المكتب (نفس قاعدة `_onResize`).
- **`_waitForSceneHost()` شرط لتهيئة المشهد.** مُنشئ `OrbitControls` يقرأ
  `_globalKey.currentState` فورًا، فيرمي `Unexpected null value` إن لم يُبنَ
  `DomLikeListenable` بعد. في تبويب خلفي يؤجّل Chrome إطارات Flutter، فمؤقّت
  الـ١٠٠ms القديم كان يسبق أول إطار ويترك المشهد أسود دائمًا. لا تحذف الانتظار
  ولا تعِد `initScene()` إلى مؤقّت مجرّد.
- **تصغير مجسّمات البيئة في `_kNatureScale` فقط**: الجبال `0.80`، الشجر
  والصخور `0.85`، أما بلاطات المرج والبحيرات فبلا تصغير — تصغيرها يفتح فجوات
  في الأرض. المفتاح فهرس الشبكة في `kNatureMeshPaths`، والتصغير يضرب أعمدة
  المصفوفة (٠–٢، ٤–٦، ٨–١٠) ويترك الترجمة.
- **الجسر**: `scaleX = 16.9` ثابت (يغطي البحيرة ٣٢ وحدة)؛ العرض ٨٫٠ والارتفاع
  ٨٫٨ والمركز `y = 1.54` فقاعه على `kNatureWaterY = −0.75`. لا تصغّر الطول.
- **الهضبة**: تبقى `plateau.glb` للهندسة والرصف ومواضع الزرع، وخامتها
  `plateau.jpg` **الأصلية** كما صُنعت: أطلس واحد يحمل عشب السطح وجرفه الصخري.
  لا تستبدلها بخامة المرج (`ground_spots`) ولا تُضف حلقة صخور: جُرِّب الاثنان
  فخرجا فطيرة باهتة وحلقة بيضاء. `_tileModelUv` و`_buildPlateauRocks` حُذفا،
  وحقلا `_plateauMat`/`_moundsTexture` كذلك. لا تستبدل الهضبة بمجسّم آخر:
  الرصف (٣٦ بلاطة) والزرع مربوطان بمواضعها.
- بطاقة الفحص **داخل `Stack` المشهد**، لا `showModalBottomSheet`: الفتح من حدث
  المؤشر كان يُغلق الشيت في نفس النقرة (نقرة المتصفح التالية تصيب الحاجز).
- الشريط السفلي في `home_screen.dart` زجاج حقيقي: `ClipRRect` → `BackdropFilter`
  (sigma 12) → خلفية `Colors.black.withAlpha(40)` وحد `Colors.white.withAlpha(30)`.
  لا ترجع إلى لون معتم `0.95`.
- **شِل التطبيق أربعة تبويبات**: الأذكار 0 · جنتي 1 · السكينة 2 · الإحصاءات 3.
  «جنتي» هو `Jannati3DScreen(embedded: true, onExit: _exitGarden)` داخل
  `IndexedStack`، ويُبنى عند أول زيارة فقط (`_gardenOpened`) ثم يبقى حيًّا حتى
  لا يُعاد سياق WebGL ولا تحميل ١٧ GLB في كل تبديل. الشريط ينسحب بعد ٣ ثوانٍ
  (`_kNavAutoHideDelay`) عبر `AnimatedSlide` + `IgnorePointer`، ويعود بسهم
  الشاشة (`onExit`) أو زر النظام (`PopScope` في `home_screen`). لا تحذف
  `embedded`/`onExit` ولا تُعِد `Navigator.push` لشاشة 3D من بطاقات الرئيسية.
- `io.flutter.embedding.android.EnableImpeller = true` في `AndroidManifest.xml`
  مفعّل إجباريًا — لا تحذفه.

### 🎯 Active Next Phase:
**Phase 9: Paradise Environment & Models Upgrade** (in this order):
1. ~~Model tap inspection~~ ✅ (لمسة → بطاقة زجاجية داخل المشهد)
2. Palm frond sway in the render loop
3. ~~Floating light particles~~ ✅ (٨٠ يمامة نور + ٤٥ ورقة متساقطة + ٥ حمامات في `_buildLightParticlesAndWildlife`)
4. Celestial river
5. Gentle terrains (optional, highest risk)

### 📦 Repo invariants (after the 2026-11-01 history rewrite):
- The public repo no longer carries the tier-models zip, `.blend` sources or `lib/3d/`.
  `AssetDownloadService.remoteZipUrl` points at the **`models-v1` Release asset** — that
  Release must never be deleted, or the download button breaks in already-installed apps.
- Fonts are **Cairo only (OFL 1.1)** — Light 300 / Medium 500 / Bold 700.
  Amiri (1.19 MB) and `GESSTwo` were **removed 2026-11-17**; every text style
  inherits Cairo from `ThemeData(fontFamily: 'Cairo')` (`PROJECT.md` §3.6/B1).
  **Typography lives in `lib/theme/app_typography.dart`** (`AppType` roles);
  no `fontFamily`/ad-hoc scale outside `lib/theme` — `test/typography_test.dart`
  guards this. Never add a commercial font or a second family back to the repo.
- **Never commit a keystore / `key.properties`** — releases are still signed with debug keys.
- **المصادر الخام لا تُودَع.** `assets/*.glb` (مثل `trees.glb` 171.8 MB و
  `نخيل.glb` 108.6 MB)، و`assets/اضافي/`، و
  `assets/3d/textures/River Material.PNG` مستثناة في `.gitignore`.
  المُجهَّز فقط تحت `assets/3d/` هو ما يدخل الحزمة. لا ترفع ملفًا يتجاوز 100 MB.
- Details and archive locations: `PROJECT.md` §8.

### 🧱 Build environment notes:
- **بعد `flutter clean` على هذا الجهاز**: `flutter run -d chrome` يفشل بـ
  «Building with plugins requires symlink support» لأن وضع المطوّر (Developer Mode)
  مغلق والحساب ليس مديرًا. الحل المؤقت المستخدم: إنشاء **junctions** يدويًا في
  `windows/flutter/ephemeral/.plugin_symlinks/` (لا تحتاج صلاحيات):
  `cmd /c mklink /J "<dest>" "<pub-cache plugin path>"` لكل إضافة في
  `.flutter-plugins-dependencies` § `plugins.windows`. الحل الدائم:
  `start ms-settings:developers` ثم تفعيل Developer Mode.
- Impeller إعداد **أندرويد فقط**؛ تشغيل Chrome لا يختبره. للتحقق منه يلزم
  بناء/تشغيل على جهاز أندرويد.

---

## See Also
- `PROJECT.md` → **المصدر الوحيد** للحالة الحالية، الخطة، التسليم، والمؤجلات
- `README.md` → setup & development guide
- `docs/evolution/index.html` → السجل البصري للمراحل الخمس
- `docs/SPIRITUAL_COMMUNITY_ROADMAP.md` → تفاصيل ميزة المجتمع
- `docs/IN_APP_UPDATES_GUIDE.md` → دليل محرك التحديث الذاتي
