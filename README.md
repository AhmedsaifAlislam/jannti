# جنتي (Jannati)

تطبيق Flutter روحاني تفاعلي يربط الأذكار بنمو عالم بصري افتراضي مستوحى من الجنة.

كل تسبيحة أو ذكر يضيف عنصرًا بصريًا (نخيل، أشجار، بيوت، قصور، مساجد، كنوز) في عالم المستخدم الخاص - في 2D و 3D.

---

## ✨ المميزات الحالية

### 2D World (مستقر):
- عالم بانورامي بأبعاد 5000×2000
- توزيع تلقائي للمكافآت
- Zoom & Pan تفاعلي
- خلفية بانورامية جميلة

### 3D World (POC):
- مشهد ثلاثي الأبعاد مع OrbitControls
- نماذج للنخيل، الأشجار، البيوت، القصور، الكنوز
- إضاءة وأرض ومنظور كامل
- حفظ مواضع العناصر تلقائيًا

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
├── 3d/               # GLB models (5 files, CC0)
├── images/           # 2D sprites
└── fonts/            # Amiri + GESSTwo
🎯 Current Status
✅ Stable:
Storage system (SharedPreferences)
2D garden display
Dhikr counter
Bottom navigation
3D scene with procedural models + GLB (color override)
3D ↔ Dhikr Sync (every 10 = 1 model)
Data Persistence (run_dev.bat)
🚧 In Progress:
Tier System + Random Distribution (Session #11)
Stats screen (placeholder currently)
🔒 Frozen:
2D zoom/pan logic (acceptable after 7 optimization phases)
📚 Documentation
AGENTS.md - Coding standards & methodology for AI assistants
PROJECT_STATE.md - Detailed current state
ROADMAP.md - Full feature roadmap & priorities
🛠️ Troubleshooting
Data lost between runs?
Use `scripts\run_dev.bat` for persistent data (creates permanent Chrome profile)
Verify you're using port 8080: flutter run -d chrome --web-port=8080
Open DevTools → Application → Local Storage → http://localhost:8080
Verify keys: dhikr_count_*, rewards_list, rewards_3d
Don't clear unless you want a hard reset
3D scene shows GLB models with solid colors (no textures)?
This is by design. Color override solution is applied in _loadGLB to handle 
embedded textures issue in three_dart_jsm_flutterflow. Models display with 
type-specific colors (green for palms, gold for treasures, etc.) which works 
well visually for the MVP.

Note: There are 6 reward types but only 5 GLB files (no mosque.glb). The mosque type uses the procedural fallback exclusively.

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
Arabic fonts: Amiri & GESSTwo
Built with Flutter & love ❤️
text


---