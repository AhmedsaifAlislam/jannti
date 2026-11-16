# جنتي (Jannati)

تطبيق Flutter روحاني تفاعلي يربط الأذكار بنمو عالم بصري افتراضي مستوحى من الجنة.

كل تسبيحة أو ذكر يضيف عنصرًا بصريًا (نخيل، أشجار، بيوت، قصور، مساجد، كنوز) في عالم المستخدم الخاص - في 2D و 3D.

> **للحالة الحالية والخطة والتسليم:** [`PROJECT.md`](PROJECT.md) هو المصدر الوحيد.
> هذا الملف يشرح التشغيل والإعداد فقط.

---

## ✨ المميزات الحالية

### 2D World (مستقر):
- عالم بانورامي بأبعاد 5000×2000
- توزيع تلقائي للمكافآت
- Zoom & Pan تفاعلي
- خلفية بانورامية جميلة

### 3D World (نشط):
- جزيرة `FreeLowPolyForest` كاملة (17 شبكة، 245 نسخة) بجبال وبحيرتين وممرات
- مراحل النخيل والشجر الخمس مرتبطة بالمكافآت (100 / 1000 / 5000 / 10000)
- بطاقة فحص عند لمس الموديل، وجزيئات نور وحياة
- كاميرا حرة مع OrbitControls، وحفظ مواضع العناصر تلقائيًا

### نظام الذكر:
- عدّاد تفاعلي لكل ذكر
- حفظ تلقائي للإحصائيات
- ربط كل ذكر بنوع مكافأة محدد

---

## 🚀 Development Setup

### Prerequisites
- Flutter SDK 3.32+
- Chrome browser
- Windows / macOS / Linux

### Installation
```bash
git clone [private-repo-url]
cd JANNTI
flutter pub get
```

---

## Running for Development

### Recommended (Persistent Data):
```bash
scripts\run_dev.bat
```

This script:
1. Creates a **permanent Chrome profile** at `%LOCALAPPDATA%\chrome-jannati-dev`
2. Starts Flutter as a web server on port 8080
3. Opens Chrome with the persistent profile
4. Your dhikr data (counters, rewards, 3D models) **persists between sessions**

### Quick Test (No Persistence):
```bash
scripts\run_chrome_original.bat
```
**Warning**: Data is LOST when Chrome closes or on next `flutter run`. Uses a temporary Chrome profile.

### Why two scripts?

`flutter run -d chrome` creates a **temporary** Chrome profile that gets deleted when Chrome closes. localStorage lives inside the Chrome profile — so all data disappears.

Using a **permanent Chrome profile** (`--user-data-dir=<path>`) keeps your localStorage data forever, even across app restarts.

### Why fixed port 8080?
`flutter run` uses a random port each time. Browser localStorage is scoped per origin (protocol + host + port), so data from one port is invisible on another. Using `--web-port=8080` keeps the same origin — necessary but not sufficient without a persistent profile.

🏗️ Project Structure
text

lib/
├── main.dart
├── models/           # Data models
├── data/             # Static data (adhkar list)
├── screens/          # UI screens
│   ├── home_screen.dart
│   ├── garden_screen.dart        # 2D world (frozen)
│   ├── jannati_3d_screen.dart    # 3D world (active dev)
│   ├── dhikr_counter_screen.dart
│   └── stats_screen.dart
├── services/         # Business logic
│   └── storage_service.dart
├── utils/            # Helpers
│   ├── garden_world_manager.dart
│   ├── garden_assets.dart
│   └── number_formatter.dart
└── three/            # 3D utilities
    └── asset_map.dart

assets/
├── 3d/               # المُجهَّز فقط: مراحل، جزيرة، جسر، هضبة، أرضيات
├── images/           # 2D sprites
└── fonts/            # Amiri + Cairo

> المصادر الخام (`assets/*.glb`، `assets/اضافي/`) محلية ومستثناة في `.gitignore`.

## 🎯 Current Status

- ✅ التخزين (SharedPreferences)، عالم 2D، عدّاد الذكر، الشريط السفلي
- ✅ عالم 3D: جزيرة FreeLowPolyForest، المراحل 1–5، بطاقة الفحص، الجزيئات
- ✅ نظام النمو: كل 10 مكافآت = نموذج مكتمل، والباقي شتلات
- ✅ الإحصاءات والأوسمة، وإذاعة السكينة (4 طبقات + قرآن)
- ✅ `flutter analyze` نظيف و`flutter test` 87/87
- 🔒 2D zoom/pan مجمّد بقصد بعد Phase 4H

## 📚 Documentation

- [`AGENTS.md`](AGENTS.md) — قواعد العمل والممنوعات وثوابت الكود
- [`PROJECT.md`](PROJECT.md) — الحالة والخطة والتسليم (المصدر الوحيد)
- [`docs/evolution/index.html`](docs/evolution/index.html) — السجل البصري للمراحل الأربع
- [`docs/SPIRITUAL_COMMUNITY_ROADMAP.md`](docs/SPIRITUAL_COMMUNITY_ROADMAP.md) — ميزة المجتمع
- [`docs/IN_APP_UPDATES_GUIDE.md`](docs/IN_APP_UPDATES_GUIDE.md) — دليل التحديث الذاتي
🛠️ Troubleshooting
Data lost between runs?
Use `scripts\run_dev.bat` for persistent data (creates permanent Chrome profile)
Verify you're using port 8080: flutter run -d chrome --web-port=8080
Open DevTools → Application → Local Storage → http://localhost:8080
Verify keys: dhikr_count_*, rewards_list, rewards_3d
Don't clear unless you want a hard reset
3D models appear black or textureless?
- تأكد أن كل GLB له PNG جانبي مُعلَن في `pubspec.yaml` (الصور المدفونة تفشل في محمّل الويب).
- لا تضبط `texture.encoding` على خامات الموديلات؛ `makeTexturesUploadable` يتعمد إسقاطه.
- `metalness` يُصفَّر عند التحميل لأن التصديرات تأتي بـ`metallicFactor: 1.0` بلا خريطة بيئة.
- التفاصيل الكاملة في `AGENTS.md` §«Model invariants».

Black borders around the world in 2D?
Should not happen after Phase 4H. If you see them, check boundaryMargin in garden_screen.dart (should be EdgeInsets.symmetric(horizontal: 20, vertical: 10)).

## 🛠️ Useful Tools for Development

### GLB Inspection
- **modelviewer.dev/editor** - فحص ملفات GLB في المتصفح
  - مفيد لـ: معرفة كم نموذج جوا الـ GLB، فحص الـ textures والـ materials، تجربة الأشكال قبل الاستخدام

### GLB Extraction
- **gltf-pipeline** (Node.js) - استخراج وتعديل GLB programmatically
- **Blender** - فتح GLB ومعالجة يدوية

### Recommended Workflow
1. افتح GLB في modelviewer.dev/editor للفحص
2. لو فيه نماذج متعددة، استخدم gltf-pipeline للفصل
3. ضع النماذج المنفصلة في assets/3d/
4. حدّث asset_map.dart بالـ paths

🤝 Contributing
This is currently a personal/learning project. Methodology used:

DIAGNOSE - Read before editing
PLAN - Show plan before executing
BUILD - Execute with explicit approval
See AGENTS.md for full development standards.

📜 License
TBD - Project under active development.

🙏 Acknowledgments
3D models from Quaternius via Poly Pizza (CC0)
Arabic fonts: Amiri & Cairo
Built with Flutter & love ❤️
text


---