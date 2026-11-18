import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl_flutterflow/flutter_gl.dart';
import 'package:three_dart_flutterflow/three_dart.dart' as three;
import 'package:three_dart_jsm_flutterflow/three_dart_jsm.dart' as three_jsm;

import '../models/reward.dart';
import '../models/reward_type.dart';
import '../services/spiritual_audio_service.dart';
import '../services/storage_service.dart';
import '../three/asset_map.dart';
import '../three/day_palette.dart';
import '../three/ground_texture.dart';
import '../three/model_evolution.dart';
import '../three/model_fit.dart';
import '../three/model_texture.dart';
import '../three/nature_layout.dart';
import '../utils/garden_assets.dart';
import '../utils/number_formatter.dart';

class _AnimatedModel {
  final three.Object3D mesh;
  final int bornAt;
  final RewardType type;
  int tier;

  /// ٠ = الموديل الأساسي، ١ = تكبير، ٢ = تكبير + لون.
  int stage;

  /// التكبير الإضافي فوق ارتفاع التير (١٫٠٥ … ١٫٢٥).
  double scaleMultiplier;

  /// لون المرحلة الثانية، أو null للمظهر الطبيعي.
  int? tint;

  /// اللون المطبّق فعلًا على [modelChild]، حتى لا نكرّر المزج عند تغيّر
  /// التكبير وحده.
  int? appliedTint;

  /// زينة مؤقتة: تُوسم بحلقة ذهبية وتُحذف عند انتهاء [expiresAt].
  final bool isDecor;
  final int? expiresAt;

  /// الطفل الذي يحمل الموديل نفسه (إجرائي ثم GLB). للمجموعة أطفال آخرون
  /// (الظل وكومة التراب)، فنحتاج مرجعًا مباشرًا لنعرف ما نستبدله عند الترقية.
  three.Object3D? modelChild;

  /// هل [modelChild] نسخة GLB حقيقية؟ نعرفها لنُعيد ضبط المقاس بدل إعادة البناء.
  bool glbActive = false;
  int glbTier = 0;

  /// مراجع الزينة الأرضية، لتُعاد مقاساتها مع نمو المرحلة.
  three.Object3D? shadowChild;
  three.Object3D? moundChild;
  three.Object3D? decorRing;

  /// رقم يتغيّر مع كل إعادة تصميم، فيُلغي تحميل GLB القديم.
  int revision = 0;

  /// سجل الحفظ المقابل لهذا الموديل (null للنماذج العرضية).
  _SavedEntry? entry;

  _AnimatedModel(
    this.mesh,
    this.bornAt,
    this.type, {
    this.tier = 1,
    this.stage = 0,
    this.scaleMultiplier = 1.0,
    this.tint,
    this.isDecor = false,
    this.expiresAt,
  });
}

/// وميض ذهبي قصير يُطلق عند ارتقاء نوع من المكافآت إلى مرحلة أعلى.
/// الجزيئات تشترك في مادة واحدة، فتخفت كلها معًا — وهي كل ما نحتاجه هنا.
class _GoldBurst {
  final three.Group group;
  final List<three.Vector3> velocities;
  final three.MeshBasicMaterial material;
  final int bornAt;
  _GoldBurst(this.group, this.velocities, this.material, this.bornAt);
}

class _SavedEntry {
  final RewardType type;
  final double x;
  final double y;
  final double z;
  int tier;
  int stage;
  final bool isDecor;
  final int? expiresAt;

  _SavedEntry(
    this.type,
    this.x,
    this.y,
    this.z, {
    this.tier = 1,
    this.stage = 0,
    this.isDecor = false,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'x': x,
    'y': y,
    'z': z,
    'tier': tier,
    'stage': stage,
    if (isDecor) 'decor': true,
    if (expiresAt != null) 'expiresAt': expiresAt,
  };

  static _SavedEntry fromJson(Map<String, dynamic> m) => _SavedEntry(
    RewardType.values.byName(m['type'] as String),
    (m['x'] as num).toDouble(),
    (m['y'] as num).toDouble(),
    (m['z'] as num).toDouble(),
    tier: (m['tier'] as num?)?.toInt() ?? 1,
    stage: (m['stage'] as num?)?.toInt() ?? 0,
    isDecor: m['decor'] == true,
    expiresAt: (m['expiresAt'] as num?)?.toInt(),
  );
}

class Jannati3DScreen extends StatefulWidget {
  const Jannati3DScreen({super.key, this.embedded = false, this.onExit});

  /// عند التضمين تُعرض الشاشة كتبويب داخل [HomeScreen] بدل مسار مستقل:
  /// لا `Scaffold` ثانٍ ولا `Navigator.pop`، والخروج يعود للرئيسية عبر [onExit].
  final bool embedded;

  /// زر الرجوع في الشريط العلوي عند التضمين. يُتجاهل في المسار المستقل.
  final VoidCallback? onExit;

  @override
  State<Jannati3DScreen> createState() => _Jannati3DScreenState();
}

class _Jannati3DScreenState extends State<Jannati3DScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  late FlutterGlPlugin _three3dRender;
  three.WebGLRenderer? _renderer;
  double _width = 800;
  double _height = 600;
  Size? _screenSize;
  late three.Scene _scene;
  late three.Camera _camera;
  final double _dpr = 1.0;
  bool _disposed = false;
  bool _loaded = false;

  /// حاجب أول إقلاع (B3): المشهد لا يُكشف قبل اكتمال أصوله.
  bool _sceneReady = false;
  int _assetsTotal = 0;
  int _assetsDone = 0;
  bool _platformInitStarted = false; // guard: prevent double initPlatformState
  // الدوران التلقائي كان يلفّ المشهد حول نقطة واحدة رغم المستخدم؛ صار مطفأً
  // افتراضيًا ويبقى زرّه في الشريط العلوي لمن يريده.
  bool _autoRotate = false;
  bool _soundEnabled = true;
  RewardType? _selectedFilter;

  /// كادر الافتتاح: منظور ثلاثي الأرباع من الجنوب الشرقي يجعل الجزيرة تُقرأ
  /// جزيرةً لا بقعة عشب — الحافة البعيدة والفراغ فوقها داخل الكادر.
  ///
  /// القياس محسوب لا مُقدَّر. الجزيرة الآن **٢٠٧ × ١٧٦** وحدة (نصف أبعاد
  /// ١٠٣٫٥ / ٨٧٫٩)، لا ٢٨٠×١٨٠ المستوية:
  ///   • (58,50,62) مسافة ٨٥  → الكاميرا **داخل** حلقة الجبال (نصف قطرها
  ///     ~٧٠–٨٠)، فسدّت الجدران الأرضية الأفق. هذه لقطة ما قبل الإصلاح.
  ///   • (170,130,200) مسافة ٢٩٤ وزاوية **٢٦°** → الجزيرة كاملة، لكن السطح
  ///     يُرى جانبيًا فتنضغط الممرات والبحيرتان في شريط رقيق.
  ///   • الآن (150,172,180) مسافة **٢٨٩٫٥** وزاوية **٣٦°**: نفس الاتجاه
  ///     (سمت ٣٩٫٨° عن +z) وارتفاع كادر رأسي ٣٠٧ وحدات (2·d·tan28°)، فتدخل
  ///     الجزيرة كاملة ويظهر سطحها مائلًا نحو الكاميرا — الممرات والبحيرتان
  ///     والرصف تُقرأ بلا تكبير.
  /// `_resetCamera` يقرأ هذه القيم نفسها، فأي تعديل يسري على الزر أيضًا.
  static const double _kHomeX = 150;
  static const double _kHomeY = 172;
  static const double _kHomeZ = 180;
  static const double _kHomeTargetX = 0;
  static const double _kHomeTargetY = 2;
  static const double _kHomeTargetZ = 0;

  /// حدود نقطة النظر — تمنع الضياع في الضباب أو الصعود إلى السحب بالسحب
  /// الطولي، مع إبقاء كامل الجنة (x ±103.5، z ±87.9) في المتناول. كانت
  /// ±٧٨ / ±٥٦ تقطع ٢٥٪ من عرض الجزيرة و٣٦٪ من عمقها فلا تصل إلى الحافة أبدًا.
  static const double _kPanMinX = -110;
  static const double _kPanMaxX = 110;
  static const double _kPanMinZ = -95;
  static const double _kPanMaxZ = 95;
  static const double _kPanMinY = 0;
  static const double _kPanMaxY = 14;

  // تحليق الكاميرا إلى الغرسة الجديدة: يُشغَّل من زر الغرس فقط، وعندما تقع
  // الغرسة خارج الكادر الآمن. نُزيح الهدف والكاميرا بنفس المقدار فتبقى
  // المسافة والاتجاه كما هما، ويتغيّر موقع النظر وحده.
  static const int _kFlyMs = 900;
  three.Vector3? _flyTarget;
  three.Vector3? _flyOriginTarget;
  three.Vector3? _flyCameraFrom;
  int _flyStartMs = 0;
  bool get _isFlying => _flyTarget != null;

  // ignore: unused_field
  late three.WebGLRenderTarget _renderTarget;
  dynamic _sourceTexture;
  final GlobalKey<three_jsm.DomLikeListenableState> _globalKey =
      GlobalKey<three_jsm.DomLikeListenableState>();
  late three_jsm.OrbitControls _controls;
  final List<_AnimatedModel> _animatedModels = [];
  final List<_SavedEntry> _savedEntries = [];
  final List<_GoldBurst> _goldBursts = [];

  /// عدد مكافآت كل نوع من `rewards_list` — المصدر الوحيد لمرحلة الموديل.
  final Map<RewardType, int> _earnedByType = {};

  /// الزينة التي أُضيفت في هذه الجلسة، للتراجع بالضغط العادي.
  final List<_AnimatedModel> _sessionDecor = [];

  /// عمر الزينة: ٢٤ ساعة، لا تتجدد إلا بضغط المستخدم بعد انتهائها.
  static const Duration _kDecorLifetime = Duration(hours: 24);
  Timer? _decorTicker;

  /// لمسة المشهد تُقرأ من أحداث [DomLikeListenable] لا من GestureDetector:
  /// على الويب يرسم المشهد داخل HtmlElementView، فلا تدخل اللمسات في نظام
  /// إيماءات Flutter أصلًا. الأحداث التي تُحرّك الكاميرا هي نفسها التي تصل
  /// إلينا هنا، فنتفرّق بين اللمسة والسحبة بالمسافة والزمن.
  bool _scenePointerBound = false;
  Offset? _sceneTapDown;
  int _sceneTapDownMs = 0;

  /// مواضع الأصابع النشطة على المشهد. `DomLikeListenable` يرسل كل إصبع كحدث
  /// مستقل، فنحتفظ بها هنا لنعرف متى صار الإصبعان معًا ونقيس حركتهما.
  final Map<int, Offset> _scenePointers = <int, Offset>{};
  Offset? _twoFingerMid;
  Offset _twoFingerAccum = Offset.zero;
  int _twoFingerMode = _kTwoFingerUndecided;
  bool _twoFingerTouched = false;

  /// إيماءة الإصبعين: يمين/شمال = دوران، أعلى/أسفل = تقريب وإبعاد.
  static const int _kTwoFingerUndecided = 0;
  static const int _kTwoFingerRotate = 1;
  static const int _kTwoFingerZoom = 2;

  /// الموديل المفحوص حاليًا (لمسة على شجرة تفتح بطاقته الزجاجية).
  RewardType? _inspectedType;
  int _inspectedTier = 1;
  int _inspectedStage = 0;
  bool _inspectedIsDecor = false;
  int? _inspectedExpiresAt;
  final Map<String, three.Object3D> _glbCache = {};
  // Staged models are swapped in one at a time. The GLTF loader shares the GL
  // context with the render loop, so a burst of concurrent parses stalls the
  // first frames of the scene.
  Future<void> _glbQueue = Future<void>.value();

  // Environment & Atmosphere Elements
  final List<three.Group> _clouds = [];
  final three.Group _particlesGroup = three.Group();
  final List<double> _particleInitialY = [];
  final List<double> _particleSpeeds = [];
  final three.Group _birdsGroup = three.Group();
  final three.Group _fallingLeavesGroup = three.Group();
  final List<three.Vector3> _leafVelocities = [];
  int _frameCount = 0;

  // 🌅 إضاءة اليوم (تلقائي حسب ساعة الجهاز / فجر / ظهيرة / ليل)
  DayLightMode _lightMode = DayLightMode.auto;
  double _starBaseOpacity = 0.0;
  three.Fog? _fog;
  three.Color? _bgColor;

  // 🎞️ انسياب التبديل اليدوي: من اللوحة المعروضة الآن إلى اللوحة الهدف.
  final Stopwatch _clock = Stopwatch();
  PhaseSpec? _appliedSpec;
  PhaseSpec? _tweenFrom;
  PhaseSpec? _tweenTo;
  double _tweenStartMs = 0.0;
  final double _tweenMs = kManualTransitionSeconds * 1000.0;

  // اسم الفترة على الزر: يُحدَّث عند تغيّرها فقط.
  Timer? _periodTicker;
  int _lastPeriodIndex = -1;

  three.Mesh? _skyMesh;
  three.MeshBasicMaterial? _skyMat;
  three.Group? _sunGroup;
  three.MeshBasicMaterial? _sunCoreMat;
  three.MeshBasicMaterial? _sunCoronaMat;
  three.MeshPhongMaterial? _cloudMat;
  three.AmbientLight? _ambientLight;
  three.DirectionalLight? _sunLight;
  three.DirectionalLight? _fillLight;

  /// ضوءا ارتداد من السحاب إلى قاعدة الجزيرة. نصف الجرف يواجه عكس الشمس في
  /// أي زاوية كاميرا تقريبًا، فبالإضاءة المحيطة وحدها يخرج أسودَ مصمتًا. ضوء
  /// واحد يترك الجهة المقابلة سوداء، فاثنان من جهتين متقابلتين يغطيان المحيط.
  three.DirectionalLight? _underLight;
  three.DirectionalLight? _underLightB;
  three.Points? _starPoints;
  three.PointsMaterial? _starMat;
  three.Points? _starHalo;
  three.PointsMaterial? _starHaloMat;

  // 🌿 مواد الأرض. تُبنى المواد فورًا بلون مصمت (تحل محلّها الخامة عند
  // وصولها) كي لا يتأخر أول إطار على فكّ ترميز الصور.  مرج الجزيرة وبلاطاته
  // تأتي بخاماتها داخل ملفات الـGLB، فلم يبقَ هنا إلا ما تبنيه الشيفرة.
  three.MeshPhongMaterial? _moundMat;
  // شبكة الأمان: الأسطوانة والقرص يبقيان ظاهرين حتى يصل موديل الهضبة،
  // فيُخفيان معًا. لو فشل التحميل تبقى الهضبة كما كانت بدل أن تختفي.
  three.Mesh? _plateauBluffMesh;
  three.Mesh? _plateauTopMesh;
  // جرف الجزيرة الطافية: تُحمَّل خامته مع خامات الأرض في نفس الدفعة.
  three.MeshPhongMaterial? _cliffMat;
  bool _groundTexturesRequested = false;

  final Random _rng = Random(42);

  static const double _kGroundW = 280.0;
  static const double _kGroundD = 180.0;
  static const double _kMinSpacing = 8.5;

  // ---- حدود الزرع على جزيرة الطبيعة ----
  /// مستطيل الزرع داخل الجزيرة. المرج المبلَّط يمتد x ≈ −٧٨..٨٥ و z ≈ −٥٢..٨٣،
  /// فالمستطيل يقصّ الحواف المتعرّجة ويترك هامشًا قبل الفراغ. المساحة الصالحة
  /// ٧٦٢٩ م² ≈ **٩٢ موضعًا** بتباعد ٨٫٥، مقابل ٥٢ على الأرض القديمة
  /// (٤٣٥٦ م²) — التوسيع ضروري كي لا يمتلئ المرج قبل منتصف سلّم النمو.
  static const double _kPlantMinX = -76.0;
  static const double _kPlantMaxX = 82.0;
  static const double _kPlantMinZ = -48.0;
  static const double _kPlantMaxZ = 76.0;

  /// هامش الإبعاد عن شاطئ البحيرة وعن سفح الجبل: داخله يغرق الموديل في الماء
  /// أو في الصخر.
  static const double _kPlantClearance = 1.0;

  // الهضبة (القصور والمساجد). على أرض الجزيرة الجديدة لا متسع لهضبة
  // ٤٢٫٩ × ٣٠٫٤: أكبر جيب خالٍ من الجبال والبحيرات نصف قطره ~١٥. صُغّرت إلى
  // **٣٠ × ٢١٫٢** — نسبة الموديل الطبيعية (١٫٨٨ : ١٫٣٣) — في (٢٤، ٢٢)،
  // والخلوص المقيس عن أقرب سفح جبل ٥٫٨ وحدة. المقياس يبقى **موحّدًا على
  // المحاور الثلاثة** فلا تمطيط يشدّ التكستشر.
  // الارتفاع ٢٫٨٥ = ٤٫٠٨ × (٣٠ ÷ ٤٢٫٩)، وسطح المشي هو سطح الأرض لا رؤوس
  // الخصلات (سطح الموديل ٢٫٩٧ عند هذا العرض).
  static const double _kPlateauX = 24.0;
  static const double _kPlateauZ = 22.0;
  static const double _kPlateauRadiusX = 15.0;
  static const double _kPlateauRadiusZ = 10.6;
  static const double _kPlateauHeight = 2.85;

  /// نصف قطر فناء الرصف البيضاوي على سطح الهضبة (٥٤٪ / ٤٩٪ من نصف قطرها).
  /// يُقرأ من مكانين: `_buildPlateauPaving` ترصف داخله، و`_buildGrassTufts`
  /// تُفرّغه من العشب — الخصلات كانت تخترق البلاط كأشواك خضراء. ثابت واحد
  /// يمنع انحراف الاثنين عن بعضهما.
  static const double _kPavingRadiusX = 8.0;
  static const double _kPavingRadiusZ = 5.2;

  /// سقف عدد الموديلات في المشهد. كان ٦٥ فامتلأ الزرع اليدوي المشهد وتوقّف
  /// قبل أن يرى اللاعب مرحلة النماء الثانية، ثم ١٢٠ على الأرض القديمة. جزيرة
  /// الطبيعة تستوعب ~٩٢ موضعًا (٧٦٢٩ م² بتباعد ٨٫٥)، فـ٩٢ هو أقصى ما يُملأ
  /// بلا تكدّس حقيقي؛ وما زاد عنه يُحفظ في `rewards_3d` ويظهر بعد الترقية أو
  /// التقليم.
  static const int _kMaxSceneModels = 92;

  @override
  void initState() {
    super.initState();
    final int savedMode = _storage.getDayLightMode();
    _lightMode = (savedMode >= 0 && savedMode < DayLightMode.values.length)
        ? DayLightMode.values[savedMode]
        : DayLightMode.auto;
    _clock.start();
    _lastPeriodIndex = periodIndexAtHour(_currentHour());

    // اسم الفترة على الزر يبقى محدّثًا (إعادة بناء عند تغيّرها فقط).
    _periodTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final int p = periodIndexAtHour(_currentHour());
      if (p != _lastPeriodIndex) {
        _lastPeriodIndex = p;
        setState(() {});
      }
    });

    // الزينة تنتهي بعد ٢٤ ساعة، ولا تُعاد تلقائيًا. الفحص الدوري يزيل
    // المنتهي أثناء التشغيل ويكتب الحالة مرة واحدة فقط عند وجود تغيير.
    _decorTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sweepExpiredDecor(),
    );

    _loadSaved();
  }

  /// الوقت الحالي ككسر ساعة (14.5 = الثانية والنصف بعد الظهر).
  double _currentHour() {
    final DateTime now = DateTime.now();
    return now.hour + now.minute / 60.0 + now.second / 3600.0;
  }

  /// اللوحة التي يجب أن يكون عليها المشهد الآن.
  PhaseSpec _targetSpec() => specForMode(_lightMode, _currentHour());

  // =========================================================================
  // 🌿 ارتفاع الأرض — مصدر الحقيقة الوحيد
  // =========================================================================

  /// مركز البحيرة الوسطى (التي يعبرها الجسر).
  ///
  /// تُقرأ من `kNatureLakes` المُولَّدة لا من أرقام مكتوبة هنا: المركز ونصف
  /// القطر يأتيان من نفس مصفوفة الموديل في المشهد الأصلي.
  List<double> get _centralLake => kNatureLakes[1];

  /// هل تقع النقطة داخل دائرة بحيرة؟ [margin] يوسّع نصف القطر.
  ///
  /// [shore] = true يستخدم **حدّ الشاطئ** (المرتفع بنحو ١٫٢ فوق المرج) بدل
  /// حدّ الماء، وهو ما تقرأه قواعد الزرع: الموديل على الشاطئ يغرق في الحجر.
  bool _isInLake(double x, double z, {double margin = 0.0, bool shore = true}) {
    for (final lake in kNatureLakes) {
      final dx = x - lake[0];
      final dz = z - lake[1];
      final r = (shore ? lake[3] : lake[2]) + margin;
      if (dx * dx + dz * dz < r * r) return true;
    }
    return false;
  }

  /// هل تقع النقطة على سفح جبل؟ الأثر مُقاس من هندسة الموديل نفسه.
  bool _isOnMountain(double x, double z, {double margin = 0.0}) {
    for (final mountain in kNatureMountains) {
      final dx = x - mountain[0];
      final dz = z - mountain[1];
      final r = mountain[2] + margin;
      if (dx * dx + dz * dz < r * r) return true;
    }
    return false;
  }

  /// هل تصلح ([x]، [z]) ليقف عليها موديل؟ داخل مستطيل الزرع، على المرج لا
  /// في بحيرة ولا على سفح جبل.
  bool _isPlantable(double x, double z) {
    if (x < _kPlantMinX || x > _kPlantMaxX) return false;
    if (z < _kPlantMinZ || z > _kPlantMaxZ) return false;
    if (_isInLake(x, z, margin: _kPlantClearance)) return false;
    return !_isOnMountain(x, z, margin: _kPlantClearance);
  }

  /// ما يقف عليه اللاعب/الموديل: الهضبة إن كان داخلها، وإلا سطح المرج.
  ///
  /// أرض الجزيرة مضلّعة لا مستوية: بلاطات المرج ألواح بسماكة ٢٫٨ وأسطحها
  /// تتذبذب ±٠٫٢ حول الصفر. سطح المشي يبقى **الصفر** لأن كل موديل يُغرس
  /// بقاعدته عليه، والدفن البسيط يخفي الفرق؛ أي تعديل هنا يرفع الجزيرة كلها.
  double _calculateGroundElevation(double x, double z) {
    final dx = (x - _kPlateauX) / _kPlateauRadiusX;
    final dz = (z - _kPlateauZ) / _kPlateauRadiusZ;
    if (dx * dx + dz * dz < 1.0) {
      return _kPlateauHeight;
    }
    return 0.0;
  }

  /// أقرب بقعة صالحة للزرع من ([x]، [z]) — تُستخدم عند تحميل مواضع قديمة
  /// صارت داخل بحيرة أو جبل بعد تبديل الأرض.
  List<double> _relocateToPlantable(double x, double z) {
    if (_isPlantable(x, z)) return <double>[x, z];
    for (var r = 2.0; r <= 120.0; r += 2.0) {
      for (var i = 0; i < 24; i++) {
        final a = i / 24 * pi * 2;
        final nx = x + r * cos(a);
        final nz = z + r * sin(a);
        if (_isPlantable(nx, nz)) return <double>[nx, nz];
      }
    }
    // وسط المرج الشمالي مفتوح دائمًا: احتياط أخير بلا بحث.
    return <double>[0.0, 24.0];
  }

  void _loadSaved() {
    final raw = _storage.getRewards3D();
    final now = DateTime.now().millisecondsSinceEpoch;
    _savedEntries.clear();
    bool needsSave = false;
    for (final r in raw) {
      final entry = _SavedEntry.fromJson(r);

      // الزينة المنتهية لا تعود بعد إعادة الفتح: الدورة لا تتجدد تلقائيًا.
      if (entry.isDecor && entry.expiresAt != null && entry.expiresAt! <= now) {
        needsSave = true;
        continue;
      }

      double sx = entry.x;
      double sz = entry.z;

      // 1. أي موضع صار في بحيرة أو على سفح جبل أو خارج مستطيل الزرع بعد
      // تبديل الأرض يُنقل إلى أقرب بقعة صالحة، والحفظ يحدث مرة واحدة.
      if (!_isPlantable(sx, sz)) {
        final spot = _relocateToPlantable(sx, sz);
        sx = spot[0];
        sz = spot[1];
        needsSave = true;
      }

      // 3. Dynamic Hill Elevation Clamping
      final double sy = _calculateGroundElevation(sx, sz);
      if ((sy - entry.y).abs() > 0.1) {
        needsSave = true;
      }

      _savedEntries.add(
        _SavedEntry(
          entry.type,
          sx,
          sy,
          sz,
          tier: entry.tier,
          stage: entry.stage,
          isDecor: entry.isDecor,
          expiresAt: entry.expiresAt,
        ),
      );
    }
    if (needsSave) {
      _writeSaved();
      debugPrint('🧹 Cleaned up 3D rewards (expired decor / hills)');
    }
    debugPrint('📂 Loaded ${_savedEntries.length} 3D entries from storage');
  }

  /// يطبّق سلّم التطور على المشهد: ١–٩ نسخ من الفسلة، وعند ١٠ تندمج في
  /// نموذج واحد أكبر قليلًا، ثم يبقى لكل نوع نموذج واحد تتغيّر مرحلته.
  ///
  /// الزينة لا تدخل في الحساب: هي نماذج إضافية لها مسارها المؤقت.
  void _applyEvolution({bool notify = true}) {
    final rewards = _storage.getAllRewards();
    final byType = <RewardType, int>{};
    for (final r in rewards) {
      byType[r.type] = (byType[r.type] ?? 0) + 1;
    }

    var changed = false;

    for (final type in RewardType.values) {
      final earned = byType[type] ?? 0;
      final previous = _earnedByType[type] ?? 0;
      _earnedByType[type] = earned;

      final tier = modelTierForCount(earned);
      final stage = modelStageForCount(earned);
      final multiplier = modelScaleMultiplier(earned);
      final tint = modelTintForCount(earned);
      final target = modelDisplayCount(earned);

      // النماذج المكتملة أولًا، ثم الشتلات المنتظرة للدمج. الترتيب ضروري لأن
      // الشتلات تُضاف في آخر القائمة، والفرز بالمرحلة يضمن أن الفهرس الأول
      // يخص النموذج المكتمل حتى لو عاد ترتيب الحفظ مختلفًا.
      final existing =
          _animatedModels.where((m) => m.type == type && !m.isDecor).toList()
            ..sort((a, b) => b.stage.compareTo(a.stage));

      // 1. حدّث النماذج القائمة في مكانها.
      final fixed = existing.length < target ? existing.length : target;
      for (var i = 0; i < fixed; i++) {
        final m = existing[i];
        final isFull = modelIsFull(earned, i);
        // الشتلة الفردية تبقى كما هي: بلا تكبير ولا تلوين، مهما كانت المرحلة.
        final mTier = isFull ? tier : 1;
        final mStage = isFull ? stage : 0;
        final mMultiplier = isFull ? multiplier : 1.0;
        final mTint = isFull ? tint : null;
        final styleChanged =
            m.tier != mTier ||
            m.stage != mStage ||
            (m.scaleMultiplier - mMultiplier).abs() > 0.0001 ||
            m.tint != mTint;
        m.tier = mTier;
        m.stage = mStage;
        m.scaleMultiplier = mMultiplier;
        m.tint = mTint;
        if (styleChanged) {
          _restyleModel(m);
          changed = true;
        }
        if (m.entry != null) {
          m.entry!.tier = mTier;
          m.entry!.stage = mStage;
        }
      }

      // 2. احذف الزائد: الشتلات التسع تندمج في النموذج الجديد عند العتبة.
      for (var i = existing.length - 1; i >= target; i--) {
        _removeModel(existing[i]);
        changed = true;
      }

      // 3. أضف الناقص، لكل موضع حجمه: مكتمل أو شتلة فردية.
      for (var i = existing.length; i < target; i++) {
        final isFull = modelIsFull(earned, i);
        final pos = addModelAt(
          type: type,
          tier: isFull ? tier : 1,
          stage: isFull ? stage : 0,
          scaleMultiplier: isFull ? multiplier : 1.0,
          tint: isFull ? tint : null,
          persist: false,
          ignoreCap: true,
        );
        if (pos == null) break;
        changed = true;
      }

      // وميض ذهبي عند ارتقاء النوع — لا في أول تحميل.
      if (previous > 0 &&
          earned > previous &&
          modelTierForCount(earned) > modelTierForCount(previous)) {
        _AnimatedModel? anchor;
        for (final m in _animatedModels) {
          if (m.type == type && !m.isDecor) anchor = m;
        }
        if (anchor != null) _spawnGoldBurst(anchor.mesh.position);
      }
    }

    if (changed) {
      _writeSaved();
      debugPrint('🌱 Evolution applied · ${rewards.length} rewards');
    }
    if (notify && mounted) setState(() {});
  }

  /// يحذف موديلًا من المشهد ومن سجل الحفظ معًا.
  void _removeModel(_AnimatedModel model) {
    _scene.remove(model.mesh);
    _animatedModels.remove(model);
    _sessionDecor.remove(model);
    if (model.entry != null) _savedEntries.remove(model.entry);
  }

  void _writeSaved() {
    _storage.saveRewards3D(_savedEntries.map((e) => e.toJson()).toList());
  }

  /// الزينة الحقيقية المسجّلة لنوع ما (لها `expiresAt`). ترجع null إذا لم تُغرس
  /// بعد. الزينة الترحيبية (`expiresAt: null`) لا تُحسب زينة نشطة.
  _AnimatedModel? _activeDecorOf(RewardType type) {
    for (final m in _animatedModels) {
      if (m.isDecor && m.type == type && m.expiresAt != null) return m;
    }
    return null;
  }

  bool _decorActiveFor(RewardType type) => _activeDecorOf(type) != null;

  /// اكتملت الدورة حين تكون الأنواع الستة كلها مزروعة. غرس نوع واحد لا يمنع
  /// غرس الأنواع الأخرى، لكن النوع الواحد لا يُكرَّر قبل انتهاء ٢٤ ساعته.
  bool get _decorCycleActive => RewardType.values.every(_decorActiveFor);

  /// أطول مدة متبقية في الزينة الحالية (للعرض على الزر).
  Duration get _decorRemaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    var maxMs = 0;
    for (final m in _animatedModels) {
      final at = m.expiresAt;
      if (!m.isDecor || at == null) continue;
      final left = at - now;
      if (left > maxMs) maxMs = left;
    }
    return Duration(milliseconds: maxMs);
  }

  /// يزيل الزينة المنتهية أثناء التشغيل. لا يولّد بديلًا: التجديد قرار المستخدم.
  void _sweepExpiredDecor() {
    if (!_loaded || _disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = _animatedModels
        .where((m) => m.isDecor && m.expiresAt != null && m.expiresAt! <= now)
        .toList();
    for (final m in expired) {
      _removeModel(m);
    }
    if (expired.isNotEmpty) {
      _writeSaved();
      debugPrint('🍂 ${expired.length} decor models expired');
    }
    // تحديث العدّاد والعد التنازلي على الزر.
    if (mounted && (expired.isNotEmpty || _decorCycleActive)) setState(() {});
  }

  void initSize(BuildContext context) {
    if (_screenSize != null) return;
    final mqd = MediaQuery.of(context);
    _screenSize = mqd.size;
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    if (_platformInitStarted) return; // guard: skip if already initializing
    _platformInitStarted = true;
    _width = _screenSize!.width;
    _height = _screenSize!.height;

    _three3dRender = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": _width.toInt(),
      "height": _height.toInt(),
      "dpr": _dpr,
    };

    await _three3dRender.initialize(options: options);
    setState(() {});

    Future.delayed(const Duration(milliseconds: 100), () async {
      await _three3dRender.prepareContext();
      if (!await _waitForSceneHost()) return;
      initScene();
    });
  }

  /// لا يُنشأ المشهد قبل أن يكون [DomLikeListenable] في الشجرة.
  ///
  /// مُنشئ `OrbitControls` يقرأ `_globalKey.currentState` فورًا
  /// (`domElement` getter) ويرمي `Unexpected null value` إن لم يُبنَ العنصر
  /// بعد. في علامة تبويب خلفية يؤجّل Chrome إطارات Flutter، فيسبق مؤقّت
  /// الـ100ms أول إطار ويبقى المشهد أسود إلى الأبد. ننتظر العنصر بدل الانهيار.
  Future<bool> _waitForSceneHost() async {
    for (var i = 0; i < 100; i++) {
      if (_disposed) return false;
      if (_globalKey.currentState != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('⚠️ scene host never mounted');
    return false;
  }

  void _onResize(double newW, double newH) {
    if (newW <= 0 || newH <= 0) return;
    if ((_width - newW).abs() < 1 && (_height - newH).abs() < 1) return;
    _width = newW;
    _height = newH;
    if (_renderer != null && _camera is three.PerspectiveCamera) {
      final pCam = _camera as three.PerspectiveCamera;
      pCam.aspect = newW / newH;
      if (newW < newH) {
        pCam.fov = 56.0;
      } else {
        pCam.fov = 44.0;
      }
      pCam.updateProjectionMatrix();
      _renderer!.setSize(newW, newH, false);
      _controls.update();
    }
  }

  // =========================================================================
  // 🌅 1. RICH EMERALD ATMOSPHERE & GOLDEN SUN
  // =========================================================================

  void _buildAtmosphere() {
    // 1. Celestial Emerald Sky Dome
    //    fog: false — حتى تظهر سماء الليل الكحلية بوضوح (الضباب يخصّ الأرض فقط)
    final skyGeo = three.SphereGeometry(380, 24, 16);
    _skyMat = three.MeshBasicMaterial({
      "color": 0x1A543E,
      "side": three.BackSide,
      "fog": false,
    });
    _skyMesh = three.Mesh(skyGeo, _skyMat!);
    _scene.add(_skyMesh!);

    // 2. Radiant Golden Sun (يتغيّر موضعه ولونه مع طور الإضاءة)
    _sunGroup = three.Group();
    _sunGroup!.position.set(50, 90, -90);

    _sunCoreMat = three.MeshBasicMaterial({"color": 0xFFFDF0});
    _sunGroup!.add(three.Mesh(three.SphereGeometry(16, 16, 16), _sunCoreMat!));

    _sunCoronaMat = three.MeshBasicMaterial({
      "color": 0xFFE082,
      "transparent": true,
      "opacity": 0.5,
    });
    _sunGroup!.add(
      three.Mesh(three.SphereGeometry(32, 16, 16), _sunCoronaMat!),
    );
    _scene.add(_sunGroup!);

    // قرص الشمس كرة نصف قطرها ١٦ على بعد ~٢٠٠ وحدة من كاميرا الافتتاح: قطره
    // ٩° أي خمسة أضعاف حجمه في أي مشهد مرجعي، وكان يملأ ربع الشاشة ويُقصّ
    // عند الحافة العليا. التصغير لا يغيّر لونه ولا موضعه من لوحة النهار، فهو
    // تصحيح حجم زاوي فقط.
    _sunGroup!.scale.set(0.5, 0.5, 0.5);

    // 3. Floating Stylized Clouds
    _clouds.clear();
    _cloudMat = three.MeshPhongMaterial({
      "color": 0xFFFAF0,
      "emissive": 0x1A3A28,
      "shininess": 30,
      "transparent": true,
      "opacity": 0.88,
      "flatShading": true,
    });

    // سحب القاعدة تُرى من فوق عند أقصى تصغير، والكرة المسطّحة المتعددة
    // الأوجه تُقرأ صخرةً بيضاء لا سحابة. مادة ناعمة شبه شفافة بلا كتابة
    // عمق تجعل تراكب الكرات ضبابًا متصلًا.
    final mistMat = three.MeshPhongMaterial({
      "color": 0xFFFAF0,
      "emissive": 0x2A4A38,
      "shininess": 6,
      "transparent": true,
      "opacity": 0.32,
      "depthWrite": false,
      "flatShading": false,
    });

    final cloudPositions = [
      three.Vector3(-240, 118, -120),
      three.Vector3(-70, 132, 210),
      three.Vector3(150, 124, -220),
      three.Vector3(250, 112, 90),
      three.Vector3(-20, 138, -70),
      // سحب القاعدة: تحجب النهاية المدبّبة للجرف من الزوايا المنخفضة (وأفق
      // الكاميرا يسمح بالنزول إلى ~٨٥°)، وتُكمل إحساس الطفو. ارتفاعها تحت
      // الصفر لأن الجزيرة نفسها بين ٠ و‎-٥٦.
      three.Vector3(-158, -22, 34),
      three.Vector3(24, -30, -156),
      three.Vector3(176, -26, -36),
      three.Vector3(-44, -36, 148),
      three.Vector3(104, -40, 18),
    ];

    for (final cPos in cloudPositions) {
      final cloud = three.Group();
      cloud.position.copy(cPos);
      final isMist = cPos.y < 0;
      if (isMist) cloud.scale.set(1.4, 1.3, 1.4);

      final puffSizes = [9.0, 14.0, 10.0, 8.0];
      final puffOffsets = [
        three.Vector3(-9, 0, 0),
        three.Vector3(0, 3, 0),
        three.Vector3(9, -1, 0),
        three.Vector3(0, -1, 5),
      ];

      for (int p = 0; p < puffSizes.length; p++) {
        // الضباب يُرى من فوق على مسافة قريبة، فكرة بـ٧×٦ قطعة تخرج سداسية
        // واضحة الزوايا. ١٦×١٢ تعطي حافة ناعمة، وعددها ٢٠ جسمًا فقط.
        final puffGeo = isMist
            ? three.SphereGeometry(puffSizes[p], 16, 12)
            : three.SphereGeometry(puffSizes[p], 7, 6);
        final puff = three.Mesh(puffGeo, isMist ? mistMat : _cloudMat!);
        puff.position.copy(puffOffsets[p]);
        puff.scale.set(1.4, 0.7, 1.0);
        cloud.add(puff);
      }

      _clouds.add(cloud);
      _scene.add(cloud);
    }

    // 4. Starfield (يظهر في طور الليل الزمردي فقط)
    _buildStarField();
  }

  /// ✨ حقل النجوم — طبقتان فقط (Points) لتفادي إثقال WebGL بمئات الأجسام.
  /// كل الأرقام تُقرأ من [starField] في `three/day_palette.dart`.
  void _buildStarField() {
    final int starCount = starField.count;
    final List<double> positions = [];
    for (int i = 0; i < starCount; i++) {
      final double theta = _rng.nextDouble() * pi * 2;
      // النجوم مكثّفة نحو الأفق لأن السماء المرئية شريط ضيّق أعلى المشهد
      final double phi = pi * (0.20 + _rng.nextDouble() * 0.30);
      final double r = 300.0 + _rng.nextDouble() * 60.0;
      positions.add(r * sin(phi) * cos(theta));
      positions.add(r * cos(phi) + 20.0);
      positions.add(r * sin(phi) * sin(theta));
    }

    // هندسة واحدة تُشارَك بين الطبقتين (بلا تكرار في الذاكرة)
    final starGeo = three.BufferGeometry();
    starGeo.setAttribute(
      'position',
      three.Float32BufferAttribute(Float32Array.from(positions), 3),
    );

    // الطبقة 1: نجوم حادّة — fog: false حتى لا تبتلعها ضبابية المشهد البعيدة
    _starMat = three.PointsMaterial({
      "color": 0xFFFFFF,
      "size": starField.size,
      "sizeAttenuation": true,
      "transparent": true,
      "opacity": 0.0,
      "fog": false,
      "depthWrite": false,
      "blending": three.AdditiveBlending,
    });
    _starPoints = three.Points(starGeo, _starMat!);
    _starPoints!.frustumCulled = false;
    _scene.add(_starPoints!);

    // الطبقة 2: هالة ناعمة حول كل نجمة (توهّج) بمزج إضافي
    _starHaloMat = three.PointsMaterial({
      "color": starField.haloColor,
      "size": starField.haloSize,
      "sizeAttenuation": true,
      "transparent": true,
      "opacity": 0.0,
      "fog": false,
      "depthWrite": false,
      "blending": three.AdditiveBlending,
    });
    _starHalo = three.Points(starGeo, _starHaloMat!);
    _starHalo!.frustumCulled = false;
    _scene.add(_starHalo!);
  }

  /// 🎨 يطبّق لوحة إضاءة على المشهد بتعديل القيم **في مكانها** (بلا تخصيص ذاكرة).
  /// الكلفة ~صفر: لا حذف/إضافة أضواء، ولا لمس لشجرة المشهد، ولا إعادة بناء شيدر.
  void _applySpec(PhaseSpec spec) {
    _appliedSpec = spec;

    // قبة السماء (بلا ضباب) + أبخرة الأفق
    _bgColor?.setHex(spec.skyColor);
    _fog?.color.setHex(spec.fogColor);
    _skyMat?.color.setHex(spec.skyColor);

    // الإضاءة
    _ambientLight?.color?.setHex(spec.ambient);
    _ambientLight?.intensity = spec.ambientIntensity;
    _sunLight?.color?.setHex(spec.sun);
    _sunLight?.intensity = spec.sunIntensity;
    _sunLight?.position.set(
      spec.lightPos[0],
      spec.lightPos[1],
      spec.lightPos[2],
    );
    _fillLight?.color?.setHex(spec.fill);
    _fillLight?.intensity = spec.fillIntensity;
    // ارتداد القاعدة يبقى ظاهرًا في الليل أيضًا، لكنه يخفت مع الإضاءة العامة.
    final double underIntensity = 0.45 + 0.55 * spec.ambientIntensity;
    _underLight?.intensity = underIntensity;
    _underLightB?.intensity = underIntensity;

    // الشمس/القمر المرئي
    _sunGroup?.position.set(spec.sunPos[0], spec.sunPos[1], spec.sunPos[2]);
    _sunCoreMat?.color.setHex(spec.core);
    _sunCoronaMat?.color.setHex(spec.corona);

    // السحاب
    _cloudMat?.color.setHex(spec.cloud);

    // النجوم: طبقة حادّة + هالة توهّج
    _starBaseOpacity = spec.starOpacity;
    _starMat?.opacity = spec.starOpacity;
    _starHaloMat?.opacity = spec.starOpacity * starField.haloOpacityRatio;
    final bool starsOn = spec.starOpacity > 0.01;
    _starPoints?.visible = starsOn;
    _starHalo?.visible = starsOn;
  }

  /// 🎞️ يبدأ انسيابًا سريعًا من اللوحة المعروضة الآن إلى اللوحة الهدف.
  void _startTransitionTo(PhaseSpec target) {
    _tweenFrom = _appliedSpec ?? target;
    _tweenTo = target;
    _tweenStartMs = _clock.elapsedMilliseconds.toDouble();
  }

  /// 🎞️ يتابع انسياب التبديل اليدوي (يُنادى كل إطار ما دام الانسياب جاريًا).
  void _advanceTransition() {
    final PhaseSpec? from = _tweenFrom;
    final PhaseSpec? to = _tweenTo;
    if (from == null || to == null) return;

    final double raw = (_clock.elapsedMilliseconds - _tweenStartMs) / _tweenMs;
    final double t = raw < 0.0 ? 0.0 : (raw > 1.0 ? 1.0 : raw);

    if (t >= 1.0) {
      _applySpec(to);
      _tweenTo = null;
      _tweenFrom = null;
      return;
    }
    _applySpec(lerpSpec(from, to, _easeInOut(t)));
  }

  /// تنعيم الحركة: هادئة في البداية والنهاية، أسرع في المنتصف.
  double _easeInOut(double t) =>
      t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;

  /// 🔁 يدوّر وضع الإضاءة: تلقائي ← فجر ← ظهيرة ← ليل ← تلقائي ...
  /// التبديل يتم بانسياب سريع ([kManualTransitionSeconds]) لا بقفزة.
  void _cycleLightMode() {
    setState(() {
      _lightMode = DayLightMode
          .values[(_lightMode.index + 1) % DayLightMode.values.length];
    });
    _storage.setDayLightMode(_lightMode.index);
    _startTransitionTo(_targetSpec());
  }

  // =========================================================================
  // 🌿 2. SCULPTED HIGH-CONTRAST TERRAIN & FINE VOLUMETRIC MEADOW
  // =========================================================================

  // ملاحظة محفوظة عن three_dart: `texture.repeat` لا يعمل — الظلّال يعرّف
  // `uvTransform` لكن المُصيِّر لا ينسخ مصفوفة الخامة إليه، فتظهر الخامة بمقياس
  // ١:١. تكرار الخامة يُضرب على إحداثيات UV للهندسة نفسها. الأرض الحالية تأتي
  // بتكرارها محسوبًا داخل المولّد، فلا حاجة لدالة تكرار هنا.

  /// الجزيرة كاملة من مشهد `PP_FreeLowPolyForest_v3.0`.
  ///
  /// القوالب السبعة عشر تُحمَّل **مرة واحدة**، ثم كل صف في [kNatureInstances]
  /// يُنتج نسخة بمصفوفته — ٢٤٥ نسخة، ٢٧٩ ألف مثلث. لو سُطّحت الأصول في ملف
  /// واحد لصار الحجم ٤٥–٧٢ م.ب؛ النسخ تشترك في الهندسة والخامة فتبقى ~٢ م.ب.
  ///
  /// المصفوفات **عمودية** (ترتيب glTF)، فتُنسخ في `Matrix4.elements` مباشرةً
  /// بلا تبديل. والنسخة تُطبَّع بمصفوفة العالم الكاملة: كل التحويلات (الدوران
  /// والمقياس الموحّد ١٫٢٥٧٧٥ أو ١٫٥٥٢٢٤) محسوبة في المولّد، فلا حساب هنا.
  ///
  /// المواد معالَجة مثل موديلات الجزر الطافية: وجهان (المرج سطح مفتوح يُرى من
  /// تحت عند أقصى تصغير)، ومعدن صفر (لا خريطة بيئة في المشهد فيسودّ)، ووهج
  /// رمادي محايد لا أخضر.
  /// تصغير مجسّمات البيئة وحدها — لا بلاطات الأرض ولا البحيرات — كي تبقى
  /// الجنة فسيحة: الجبال ٠٫٨٠، الشجر والصخور ٠٫٨٥. تصغير البلاطة يفتح فجوة
  /// في المرج، لأن الأرض مرصوفة بها بلا تراكب.
  ///
  /// المفتاح هو فهرس الشبكة في `kNatureMeshPaths`. التصغير يضرب الأعمدة
  /// الثلاثة للمصفوفة (٠–٢، ٤–٦، ٨–١٠) ويترك عمود الترجمة (١٢–١٤) كما هو،
  /// فتنكمش الشجرة حول جذعها ولا تتحرك من موضعها. أصول هذه المجسّمات عند
  /// القاعدة (min.y = 0 في كل ملف)، فلا تطفو ولا تُدفن بعد التصغير.
  static const Map<int, double> _kNatureScale = {
    0: 0.85, // birch_a
    1: 0.85, // birch_b
    2: 0.80, // mountain_a
    3: 0.80, // mountain_b
    11: 0.85, // rock_moss_a
    12: 0.85, // rock_moss_b
    13: 0.85, // rock_pile_a
    14: 0.85, // rock_pile_b
    15: 0.85, // tree_a
    16: 0.85, // tree_b
  };

  Future<void> _buildNatureIsland(three.Group parent) async {
    final rowsByMesh = <int, List<List<double>>>{};
    for (final row in kNatureInstances) {
      rowsByMesh.putIfAbsent(row[0].toInt(), () => <List<double>>[]).add(row);
    }

    for (var i = 0; i < kNatureMeshPaths.length; i++) {
      final rows = rowsByMesh[i];
      if (rows == null || rows.isEmpty) continue;
      final path = kNatureMeshPaths[i];
      try {
        final gltf = await three_jsm.GLTFLoader()
            .loadAsync(path)
            .timeout(const Duration(seconds: 30));
        if (_disposed) return;
        final scene = gltf?['scene'];
        if (scene == null) {
          debugPrint('⚠️ nature island scene is null: $path');
          continue;
        }
        scene.traverse((child) {
          if (child is three.Mesh) {
            final materials = child.material is List
                ? child.material as List
                : [child.material];
            for (final mat in materials) {
              if (mat == null) continue;
              mat.side = three.DoubleSide;
              mat.metalness = 0.0;
              mat.emissive?.setHex(0x0C0C0C);
              mat.needsUpdate = true;
            }
          }
        });
        makeTexturesUploadable(scene);
        // المؤشرات ٣٢-بت في كل تصدير، و`clone` لا يعرف إلا ١٦-بت: التضييق
        // يجب أن يسبق التخزين وإلا رمى أول نسخة.
        makeModelCloneable(scene);

        for (final row in rows) {
          final matrix = three.Matrix4();
          final elements = matrix.elements;
          for (var k = 0; k < 16; k++) {
            elements[k] = row[k + 1];
          }
          final squeeze = _kNatureScale[i] ?? 1.0;
          if (squeeze != 1.0) {
            for (final k in const [0, 1, 2, 4, 5, 6, 8, 9, 10]) {
              elements[k] = elements[k] * squeeze;
            }
          }
          final copy = scene.clone(true);
          copy.applyMatrix4(matrix);
          parent.add(copy);
        }
        debugPrint('🏝 nature ${rows.length}× $path');
      } catch (e) {
        debugPrint('⚠️ nature island failed: $path $e');
      }
    }
    debugPrint('🏝 nature island ready (${kNatureInstances.length} copies)');
  }

  /// يسجّل أصلًا غير متزامنًا في حاجب أول إقلاع (B3).
  ///
  /// كل بناء يزيد العدّاد قبل أن يبدأ وينقص عند اكتماله — نجاحًا أو فشلًا —
  /// فلا يُكشف المشهد قبل آخر شبكة. `catchError` يمنع خطأ أصل واحد من إسقاط
  /// العدّاد، والمهلة الزمنية في [initPage] شبكة أمان أخيرة.
  void _trackAsset(Future<void> work) {
    _assetsTotal++;
    unawaited(
      work
          .catchError((Object e) {
            debugPrint('⚠️ scene asset failed: $e');
          })
          .whenComplete(() {
            if (_disposed) return;
            _assetsDone++;
            if (_assetsDone >= _assetsTotal) {
              _markSceneReady();
            } else if (mounted) {
              setState(() {});
            }
          }),
    );
  }

  void _markSceneReady() {
    if (_sceneReady || _disposed) return;
    _sceneReady = true;
    debugPrint('✅ scene ready ($_assetsDone/$_assetsTotal)');
    if (mounted) setState(() {});
  }

  void _buildSculptedTerrain() {
    final terrainGroup = three.Group();

    // الجزيرة كاملة — جبال، بحيرتان، ممرات، مرج — من مشهد
    // `PP_FreeLowPolyForest_v3.0`. تحلّ محل الأرض المسطّحة والنهر المحفور:
    // الماء هنا بحيرتان مغلقتان، والمرج بلاطات مصمَّمة لا شبكة مولَّدة.
    _trackAsset(_buildNatureIsland(terrainGroup));

    // كومة التراب تحت الشجرة: مادة واحدة يشترك فيها كل النماذج، فتُنشأ هنا كي
    // تلتقط خامة الطحلب عند وصولها بدل أن تُنشأ متأخرًا بلا خامة.
    _moundMat = three.MeshPhongMaterial({
      "color": 0x7C8A64,
      "emissive": 0x0B1208,
      "shininess": 6,
      "flatShading": false,
    });

    // Elevated East Bluff for Mosque / Palaces
    // التلّ نفسه صخرة داكنة، وسطحه المرج: قرص منفصل فوق الأسطوانة. تكرار
    // الخامة على وجهَي الأسطوانة بمعامل واحد مستحيل عمليًا — الوجه الجانبي
    // محيطه ~١٩٠ وحدة والغطاء عرضه ٧٣ — فتظهر عصابات على أحدهما. فصل السطح
    // يسمح لكل منهما بتكراره الصحيح.
    final palacePlateauMat = three.MeshPhongMaterial({
      "color": 0x2A6B44,
      "emissive": 0x061A0E,
      "specular": 0x1E3A28,
      "shininess": 10,
      "flatShading": false,
    });
    final palaceBluffGeo = three.CylinderGeometry(28, 33, _kPlateauHeight, 20);
    palaceBluffGeo.computeVertexNormals();
    final palaceBluff = three.Mesh(palaceBluffGeo, palacePlateauMat);
    palaceBluff.position.set(_kPlateauX, _kPlateauHeight / 2, _kPlateauZ);
    // الأسطوانة دائرية والمطلوب بيضاوي: كل محور يُقاس على نصف قطره الأصلي.
    palaceBluff.scale.set(
      _kPlateauRadiusX / 33.0,
      1.0,
      _kPlateauRadiusZ / 33.0,
    );
    _plateauBluffMesh = palaceBluff;
    terrainGroup.add(palaceBluff);

    // سطح الهضبة الاحتياطي: قرص مصمت بلون العشب، يظهر فقط إن فشل تحميل
    // موديل الهضبة (وإلا `_plateauTopMesh.visible = false`). لا خامة عليه،
    // فتكرار UV لا معنى له.
    final plateauTopMat = three.MeshPhongMaterial({
      "color": 0x5E9C6E,
      "emissive": 0x081A10,
      "specular": 0x243024,
      "shininess": 8,
      "flatShading": false,
    });
    final plateauTopGeo = three.CircleGeometry(radius: 28, segments: 40);
    final plateauTop = three.Mesh(plateauTopGeo, plateauTopMat);
    plateauTop.rotation.x = -three.Math.pi / 2;
    plateauTop.position.set(_kPlateauX, _kPlateauHeight + 0.02, _kPlateauZ);
    plateauTop.scale.set(_kPlateauRadiusX / 28.0, _kPlateauRadiusZ / 28.0, 1);
    _plateauTopMesh = plateauTop;
    terrainGroup.add(plateauTop);

    // بقع الطحلب والتراب لم تبقَ: المرج الآن بلاطات مرسومة فيها الحصى
    // والأعشاب نفسها، فقرص داكن فوقها يُقرأ وصمة لا تنوّعًا. مادة الكومة
    // وحدها باقية لأن نماذج الشجر الإجرائية تضعها تحت جذعها.

    _scene.add(terrainGroup);
    _buildIslandShell(terrainGroup);
    _buildNaturePackIslands(terrainGroup);
    _trackAsset(_buildPlateauModel());
    // الرصف يُبنى مستقلًا عن تحميل موديل الهضبة: ارتفاعه ثابت ٢٫٧٦ وسطح
    // الموديل المقيس يقع بين ٢٫٧٥ و٢٫٩٧ في هذا النطاق، فلو تأخّر التحميل
    // أو فشل يبقى الرصف في مكانه الصحيح على القرص الاحتياطي.
    _trackAsset(_buildPlateauPaving(terrainGroup));

    // 3. Fine Volumetric Grass Tufts & Flowers
    _buildMeadowFlora();

    // 4. Crystalline Geode Rock Formations on the Meadow
    _buildCrystalGeodes();

    // 5. الجسر والزنابق: الماء الآن بحيرتان داخل الجزيرة، فالجسر يعبر الوسطى
    // والزنابق تطفو على سطحيهما.
    _trackAsset(_buildStoneBridge());
    _buildWaterLilies();

    // 6. خامات الجرف والكومة: تُحمَّل بعد بناء المواد فلا يتأخر أول إطار.
    _trackAsset(_loadGroundTextures());
  }

  // =========================================================================
  // 🏝 2ب. الجزيرة الطافية — جرف صخري تحت المرج وجزر صغيرة حولها
  // =========================================================================

  /// مركز محيط الجزيرة: نقطة الارتكاز التي تنكمش حولها حلقات الجرف.
  ///
  /// المحيط نفسه مُستخرج من مثلثات المرج والجبال والشواطئ في `nature_layout`،
  /// فهو يطابق حدّ الأرض الفعلي لا مستطيلًا حولها. الشكل الناتج عضوي غير منتظم،
  /// والانكماش حول المركز يبقيه كذلك في كل حلقة.
  List<double> get _outlineCenter {
    var sx = 0.0;
    var sz = 0.0;
    for (final p in kNatureOutline) {
      sx += p[0];
      sz += p[1];
    }
    return <double>[sx / kNatureOutline.length, sz / kNatureOutline.length];
  }

  /// محيط الجزيرة بعد سحبه للخارج ([scale] > 1) أو للداخل (< 1) حول مركزه.
  List<double> _scaledOutline(double scale) {
    final c = _outlineCenter;
    final out = <double>[];
    for (final p in kNatureOutline) {
      out
        ..add(c[0] + (p[0] - c[0]) * scale)
        ..add(c[1] + (p[1] - c[1]) * scale);
    }
    return out;
  }

  /// جدار الجزيرة: حلقات متراصّة تبدأ عند حدّ الأرض وتضيق إلى نقطة.
  ///
  /// [profile] صفوف `[y, معامل الانكماش]`. الحلقة الأولى عند حدّ المرج نفسه
  /// بلا زيادة تُذكر (٠٫٤ وحدة): أي فراغ بمحاذاة الحافة يُرى منه ما تحت الجزيرة،
  /// ثم حلقة **بارزة ٣٪** تهبط ٢٥ سم فقط فتُقرأ من فوق كإطار حجري حول العشب،
  /// وبعدها تغور القشرة للداخل حتى نقطة على عمق ٥٧.
  ///
  /// [tile] طول ضلع المربع الذي تغطيه نسخة واحدة من الخامة (٢٦ وحدة)، فتكرار
  /// الـUV يُحسب من المحيط الفعلي لا من مساحة المستطيل المحيط به.
  three.Mesh _islandShellMesh({
    required List<List<double>> profile,
    required double tile,
    required three.Material material,
  }) {
    final samples = kNatureOutline.length;
    final center = _outlineCenter;
    final positions = <double>[];
    final uvs = <double>[];
    final indices = <int>[];

    final first = _scaledOutline(profile.first[1]);
    var perimeter = 0.0;
    var avgRadius = 0.0;
    for (var i = 0; i < samples; i++) {
      final j = (i + 1) % samples;
      final dx = first[j * 2] - first[i * 2];
      final dz = first[j * 2 + 1] - first[i * 2 + 1];
      perimeter += sqrt(dx * dx + dz * dz);
      final rx = first[i * 2] - center[0];
      final rz = first[i * 2 + 1] - center[1];
      avgRadius += sqrt(rx * rx + rz * rz);
    }
    avgRadius /= samples;
    final uRepeat = max(1.0, (perimeter / tile).roundToDouble());

    var v = 0.0;
    for (var ring = 0; ring < profile.length; ring++) {
      final p = profile[ring];
      if (ring > 0) {
        final prev = profile[ring - 1];
        final dy = prev[0] - p[0];
        final shrink = (prev[1] - p[1]) * avgRadius;
        v += sqrt(dy * dy + shrink * shrink) / tile;
      }

      final contour = _scaledOutline(p[1]);
      // تمويج يظهر مع العمق فقط: الحلقة العليا يجب أن تبقى مطابقة لحدّ الأرض،
      // وما تحتها يصير صخرًا غير منتظم بدل مخروط رياضي أملس.
      final depth = -p[0];
      final wobble = depth <= 4 ? 0.0 : min(0.055, (depth - 4) * 0.0035);

      for (var i = 0; i < samples; i++) {
        var x = contour[i * 2];
        var z = contour[i * 2 + 1];
        if (wobble > 0) {
          final theta = atan2(z - center[1], x - center[0]);
          final w =
              1.0 +
              wobble *
                  (0.7 * sin(3.0 * theta + 0.6) + 0.3 * sin(7.0 * theta + 2.2));
          x = center[0] + (x - center[0]) * w;
          z = center[1] + (z - center[1]) * w;
        }
        positions.addAll([x, p[0], z]);
        uvs.addAll([i / samples * uRepeat, v]);
      }
    }

    for (var ring = 0; ring < profile.length - 1; ring++) {
      for (var i = 0; i < samples; i++) {
        final next = (i + 1) % samples;
        final a = ring * samples + i;
        final b = ring * samples + next;
        final c = (ring + 1) * samples + i;
        final d = (ring + 1) * samples + next;
        // (a,b,c) و(b,d,c): الناظم إلى الخارج. الترتيب المعتاد (a,c,b) يقلبها
        // إلى الداخل فيُقصّ الجرف كله ويظهر المشهد بلا قاعدة.
        indices.addAll([a, b, c, b, d, c]);
      }
    }

    // قمة مدبّبة أسفل آخر حلقة. حلقة صغيرة + مروحة أفضل من ١٢٨ نقطة متطابقة:
    // المثلثات المتطابقة مساحتها صفر فلا تُرسم، ونواظمها تصبح (0,0,0).
    final lastRing = (profile.length - 1) * samples;
    final centerIndex = positions.length ~/ 3;
    positions.addAll([center[0], profile.last[0] - 1.6, center[1]]);
    uvs.addAll([0.0, v + 1.6 / tile]);
    for (var i = 0; i < samples; i++) {
      indices.addAll([centerIndex, lastRing + i, lastRing + (i + 1) % samples]);
    }

    final geometry = three.BufferGeometry();
    geometry.setAttribute(
      'position',
      three.Float32BufferAttribute(Float32Array.from(positions), 3),
    );
    geometry.setAttribute(
      'uv',
      three.Float32BufferAttribute(Float32Array.from(uvs), 2),
    );
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    return three.Mesh(geometry, material);
  }

  /// مادة الجرف، تُنشأ مرة واحدة ويستعملها الجرف وسيقان الجبال.
  ///
  /// اللون في الخامة لا في المادة: المادة بيضاء، والخامة باردة، وشمس الظهيرة
  /// تحذف نصف الأزرق فيخرج الصخر رماديًا دافئًا لا أصفر. `emissive` خفيف لأن
  /// وجه الجرف يواجه عكس الشمس دائمًا.
  three.MeshPhongMaterial _cliffMaterial() {
    return _cliffMat ??= three.MeshPhongMaterial({
      "color": 0xFFFFFF,
      "emissive": 0x141A22,
      "specular": 0x1C2026,
      "shininess": 5,
      "flatShading": false,
    });
  }

  /// الجرف الذي يحوّل الأرض المسطحة إلى قطعة مقتطعة من جبل.
  ///
  /// القاعدة عند المرج ٢٨٠×١٨٠، وأول حلقة مطابقة لحدّه بالضبط (بلا زيادة: أي
  /// فراغ بمحاذاة الحافة يُرى منه ما تحت الجزيرة)، ثم **حافة صخرية بارزة**
  /// تتوسّع ٤٫٥ وحدة للخارج وتهبط ٠٫٣٥ فقط، فتُرى من فوق كإطار حجري حول العشب.
  /// هذه الحافة هي ما يجعل الشكل يُقرأ جزيرةً من زاوية اللاعب: القشرة نفسها
  /// تهبط للداخل ولا تُرى من أعلى، وقضيب الكاميرا لا ينزل تحت مستوى العشب.
  /// بعدها تغور القشرة للداخل حتى نقطة على عمق ٥٦.
  void _buildIslandShell(three.Group parent) {
    // [y, معامل الانكماش حول مركز المحيط]
    final profile = <List<double>>[
      [-0.30, 1.004], // حدّ الأرض نفسه، خارجًا ٠٫٤ وحدة كي لا يتزاحم السطحان
      [-0.55, 1.030], // حافة صخرية بارزة تُرى من فوق كإطار حجري
      [-2.20, 1.028],
      [-5.20, 1.000],
      [-10.0, 0.970],
      [-16.0, 0.920],
      [-24.0, 0.830],
      [-33.0, 0.700],
      [-42.0, 0.520],
      [-49.0, 0.320],
      [-54.0, 0.130],
      [-57.0, 0.020],
    ];

    parent.add(
      _islandShellMesh(
        profile: profile,
        tile: 26.0,
        material: _cliffMaterial(),
      ),
    );
  }

  /// يثبّت موديلًا من حزمة الطبيعة بعد تحميله.
  ///
  /// [baseAligned] يضع **قاعدة** الموديل عند [y] بدل مركزه: الجبال المحيطية
  /// تُغرس في الأفق فتقف على قاعدتها، والجزر الطافية تُعلَّق حول مركزها.
  ///
  /// كل موديلات الحزمة تحمل خامتين مسطّحتين من `prep_nature_pack_glb.py`
  /// (طحلب علوي وصخر جانبي) بلا أي خريطة، فلا تحتاج `makeTexturesUploadable`
  /// أكثر من تمريرة آمنة.
  void _placeNatureModel({
    required three.Group parent,
    required String path,
    required double x,
    required double y,
    required double z,
    required double scale,
    double tiltX = 0,
    double tiltZ = 0,
    double spin = 0,
    bool baseAligned = false,
  }) {
    three_jsm.GLTFLoader()
        .loadAsync(path)
        .timeout(const Duration(seconds: 30))
        .then((gltf) {
          if (_disposed) return;
          final scene = gltf?['scene'];
          if (scene == null) {
            debugPrint('⚠️ nature scene is null: $path');
            return;
          }
          scene.traverse((child) {
            if (child is three.Mesh) {
              final materials = child.material is List
                  ? child.material as List
                  : [child.material];
              for (final mat in materials) {
                if (mat == null) continue;
                // الجزر تُرى من تحتها عند أقصى تصغير، ولوح المرج سطح مفتوح
                // لا صندوق: بدون الوجهين يختفي نصفها.
                mat.side = three.DoubleSide;
                mat.metalness = 0.0;
                // الوهج **رمادي محايد** لا أخضر: نفس السطر على خامة الصخر
                // كان يصبغ الجبل كله بالأخضر ويمحو الفرق بين الطحلب والصخر.
                mat.emissive?.setHex(0x0C0C0C);
                mat.needsUpdate = true;
              }
            }
          });
          makeTexturesUploadable(scene);

          final box = three.Box3().setFromObject(scene);
          final center = box.getCenter(three.Vector3());
          if (!center.x.isFinite || !center.y.isFinite) {
            debugPrint('⚠️ nature model has no volume: $path');
            return;
          }

          // الحاوية تحمل النقطة المحسوبة: أصل الجبل عند قاعدته المدفونة
          // (−٨٫٦) وأصل المرج عند سطحه، فالتثبيت بالإحداثيات المحلية كان
          // سيُظهر كل قطعة على ارتفاع مختلف.
          final holder = three.Group();
          scene.position.set(
            -center.x,
            baseAligned ? -box.min.y : -center.y,
            -center.z,
          );
          holder.add(scene);
          holder.position.set(x, y, z);
          holder.rotation.set(tiltX, spin, tiltZ);
          holder.scale.set(scale, scale, scale);
          parent.add(holder);
        })
        .catchError((Object e) {
          debugPrint('⚠️ nature model failed: $path $e');
        });
  }

  /// أرخبيل صغير طافٍ يسار الجزيرة الأم (حزمة FreeLowPolyNaturePack v3.0).
  ///
  /// قطع ديكور ثابتة، **لا** تمرّ عبر `addModelAt`: لا تستهلك
  /// `_kMaxSceneModels`، ولا تخضع لـ`_kMinSpacing`، ولا تُحفظ في
  /// `rewards_list` — تُبنى مرة واحدة مع بقية التضاريس.
  ///
  /// المواضع محسوبة إسقاطيًا على كادر الافتتاح `(170,130,200)` لا مُقدَّرة.
  /// الشريط العلوي الزجاجي يحتل ndc y فوق ٠٫٦٤ تقريبًا، فأي جزيرة هناك تختفي
  /// تحته — ولهذا كل القطع في **الفراغ الأيسر** (ndc x −0.76..−0.45،
  /// y ٠٫٣٣–٠٫٥٣) حيث السماء مفتوحة فعلًا، لا في «خلفية» الكادر.
  void _buildNaturePackIslands(three.Group parent) {
    const islets =
        <
          ({
            String path,
            double x,
            double y,
            double z,
            double scale,
            double tiltX,
            double tiltZ,
            double spin,
          })
        >[
          // جبل طحلبي هو أكبر القطع وأقربها إلى الكادر.
          (
            path: 'assets/3d/floating_moss_1.glb',
            x: -280,
            y: 18,
            z: -10,
            scale: 1.0,
            tiltX: 0.05,
            tiltZ: -0.10,
            spin: 0.7,
          ),
          // لوح مرج بعيد بين الجبلين، مائل ١٠° كي لا يطابق الأفق.
          (
            path: 'assets/3d/floating_meadow_1.glb',
            x: -200,
            y: 12,
            z: -60,
            scale: 1.3,
            tiltX: -0.10,
            tiltZ: 0.07,
            spin: 1.9,
          ),
          // جبل ثانٍ أقرب وأصغر: يعطي العمق الثلاثي للأرخبيل.
          (
            path: 'assets/3d/floating_moss_2.glb',
            x: -150,
            y: 24,
            z: 45,
            scale: 0.8,
            tiltX: 0.08,
            tiltZ: 0.06,
            spin: 2.6,
          ),
        ];

    for (final spot in islets) {
      _placeNatureModel(
        parent: parent,
        path: spot.path,
        x: spot.x,
        y: spot.y,
        z: spot.z,
        scale: spot.scale,
        tiltX: spot.tiltX,
        tiltZ: spot.tiltZ,
        spin: spot.spin,
      );
    }
  }

  /// يحمّل خامات الأرض التي ما زالت تبنيها الشيفرة.
  ///
  /// مرج الجزيرة وبلاطاته وبحيراته تأتي بخاماتها داخل ملفات الـGLB، فلم يبقَ
  /// هنا إلا **جرف الجزيرة** (قشرة الصخر تحت المرج) و**كومة التراب** التي تضعها
  /// نماذج الشجر الإجرائية تحت جذعها.
  Future<void> _loadGroundTextures() async {
    if (_groundTexturesRequested) return;
    _groundTexturesRequested = true;

    final mounds = await loadGroundTexture(kGroundSpotTexture, mirrored: true);
    final cliff = await loadGroundTexture(kCliffRockTexture);

    if (!mounted) return;

    if (mounds != null) {
      _moundMat
        ?..map = mounds
        ..needsUpdate = true;
    }
    if (cliff != null) {
      // لا تفتيح هنا: الخامة نفسها باردة عمدًا (متوسط ٩٨،١٠٥،١٢٥) كي تخرج
      // رمادية دافئة تحت شمس 0xFFE082 بدل جدار أصفر.
      _cliffMat
        ?..map = cliff
        ..needsUpdate = true;
    }

    debugPrint('🌿 ground textures ready');
  }

  void _buildMeadowFlora() {
    final grassColors = [0x2E7D32, 0x388E3C, 0x43A047, 0x4CAF50, 0x66BB6A];
    final flowerWhite = three.MeshBasicMaterial({"color": 0xFFFFFF});
    final flowerGold = three.MeshBasicMaterial({"color": 0xFFD54F});
    final flowerPink = three.MeshBasicMaterial({"color": 0xF48FB1});

    // ٢٨٠ خصلة على كامل مرج الجزيرة (وليس على ضفّتي نهر). كل موضع يُرفض
    // إن وقع في بحيرة أو على سفح جبل أو داخل فناء الرصف. سقف المحاولات
    // يمنع حلقة لا تنتهي لو ضاقت المساحة الصالحة.
    var placed = 0;
    var attempts = 0;
    while (placed < 280 && attempts < 4000) {
      attempts++;
      final x = _kPlantMinX + _rng.nextDouble() * (_kPlantMaxX - _kPlantMinX);
      final z = _kPlantMinZ + _rng.nextDouble() * (_kPlantMaxZ - _kPlantMinZ);
      if (!_isPlantable(x, z)) continue;
      final i = placed;
      final groundY = _calculateGroundElevation(x, z);

      // لا عشب داخل فناء الرصف: البلاط يعلو الأرض ٠٫٢ فقط، فخصلة واحدة
      // تحته تعبر سطحه وتُقرأ شوكة خضراء وسط الحجر. الهامش ١٫٠٦ يترك شريط
      // عشب رفيع على الحدّ بدل حافة مقصوصة بالسكين.
      final pdx = (x - _kPlateauX) / _kPavingRadiusX;
      final pdz = (z - _kPlateauZ) / _kPavingRadiusZ;
      if (pdx * pdx + pdz * pdz < 1.06) continue;

      placed++;
      final tuftGroup = three.Group();
      // ٥ سم في الأرض: أسطح بلاطات المرج تتذبذب ±٠٫٢، والخصلة المعلّقة
      // ٢٠ سم فوق البلاطة تُقرأ شفرة طائرة.
      tuftGroup.position.set(x, groundY - 0.05, z);

      final gMat = three.MeshPhongMaterial({
        "color": grassColors[i % grassColors.length],
        "shininess": 24,
        "flatShading": false,
        // خصلات العشب مخاريط رأسية: أوجهها الجانبية تُقابل شمسًا في وسط السماء
        // فتردّ ضوءًا قليلًا وتُقرأ مثلثة سوداء في المرج. إضاءة ذاتية خفيفة من
        // لونها هي نفسها تمنع ذلك من غير أن تفقد شكلها.
        "emissive": 0x1E5A28,
      });

      // 3 to 4 delicate, fine grass blades
      final bladeCount = 3 + (i % 2);
      for (int b = 0; b < bladeCount; b++) {
        final bAngle =
            (b / bladeCount) * three.Math.pi * 2 + _rng.nextDouble() * 0.3;
        final bHeight =
            0.35 + _rng.nextDouble() * 0.35; // Finer, realistic lawn scale
        final blade = three.Mesh(three.ConeGeometry(0.08, bHeight, 4), gMat);
        blade.position.set(
          0.12 * sin(bAngle),
          bHeight * 0.45,
          0.12 * cos(bAngle),
        );
        blade.rotation.z = sin(bAngle) * 0.28;
        blade.rotation.x = cos(bAngle) * 0.28;
        tuftGroup.add(blade);
      }

      // Delicate Meadow Blossoms
      if (i % 4 == 0) {
        final fMat = (i % 8 == 0)
            ? flowerPink
            : (i % 12 == 0 ? flowerGold : flowerWhite);
        final blossom = three.Mesh(three.SphereGeometry(0.12, 4, 4), fMat);
        blossom.position.set(
          (_rng.nextDouble() - 0.5) * 0.35,
          0.35 + _rng.nextDouble() * 0.25,
          (_rng.nextDouble() - 0.5) * 0.35,
        );
        tuftGroup.add(blossom);
      }

      _scene.add(tuftGroup);
    }
  }

  void _buildCrystalGeodes() {
    final geodeRockMat = three.MeshPhongMaterial({
      "color": 0x125437,
      "emissive": 0x062416,
      "specular": 0x33B880,
      "shininess": 60,
      "flatShading": true,
    });

    final crystalPurple = three.MeshPhongMaterial({
      "color": 0xBA68C8,
      "emissive": 0x4A148C,
      "specular": 0xFFFFFF,
      "shininess": 100,
    });

    final crystalCyan = three.MeshPhongMaterial({
      "color": 0x80DEEA,
      "emissive": 0x006064,
      "specular": 0xFFFFFF,
      "shininess": 100,
    });

    // أربعة أصداف موزّعة على المرج حول البحيرتين. الموضع الرابع كان (19، 28)
    // داخل هضبة القصور الجديدة، فنُقل إلى غرب البحيرة الشمالية.
    final geodePositions = [
      three.Vector3(-18.5, 0.2, 16.0),
      three.Vector3(22.0, 0.2, -16.0),
      three.Vector3(-19.0, 0.2, -26.0),
      three.Vector3(-14.0, 0.2, 36.0),
    ];

    for (int g = 0; g < geodePositions.length; g++) {
      final gPos = geodePositions[g];
      final geodeGroup = three.Group();
      geodeGroup.position.copy(gPos);

      final rock = three.Mesh(three.DodecahedronGeometry(2.2), geodeRockMat);
      rock.scale.set(1.4, 0.65, 1.2);
      geodeGroup.add(rock);

      final cMat = g % 2 == 0 ? crystalPurple : crystalCyan;
      for (int c = 0; c < 8; c++) {
        final angle = (c / 8) * three.Math.pi * 2;
        final h = 1.0 + _rng.nextDouble() * 1.1;
        final spike = three.Mesh(three.ConeGeometry(0.25, h, 6), cMat);
        spike.position.set(
          0.55 * sin(angle),
          0.85 + h * 0.45,
          0.55 * cos(angle),
        );
        spike.rotation.z = sin(angle) * 0.35;
        spike.rotation.x = cos(angle) * 0.35;
        geodeGroup.add(spike);
      }

      _scene.add(geodeGroup);
    }
  }

  /// هضبة القصور: موديل الجزيرة العشبية بدل الأسطوانة المسطّحة.
  ///
  /// **بمقاس موحّد واحد** على المحاور الثلاثة. الموديل ١٫٨٨ × ٠٫١٩ × ١٫٣٣
  /// (نسبة ١٫٤١)، فتكبيره بـ`42.9 ÷ 1.88` يعطي ٤٢٫٩ × ٤٫٣٤ × ٣٠٫٤ تلقائيًا:
  /// الشكل كما صُمِّم، والتكستشر لا يُمطّ ولا تتحول حصى الجرف إلى خطوط.
  /// الأسطوانة والقرص العشبي يبقيان شبكة أمان حتى يصل الموديل ثم يُخفيان معًا.
  /// **لا تُستبدل خامتها**: `plateau.jpg` تحمل عشب السطح وجرفه الصخري في أطلس
  /// واحد، واستبدالها بخامة المرج (`ground_spots`) كان يمحو الجرف ويحوّل
  /// الهضبة إلى فطيرة باهتة. تكرار UV ×3 كان لمصلحة تلك الخامة لا لهذا الأطلس.
  Future<void> _buildPlateauModel() {
    const targetWidth = _kPlateauRadiusX * 2;

    return three_jsm.GLTFLoader()
        .loadAsync(kPlateauModel)
        .timeout(const Duration(seconds: 30))
        .then((gltf) {
          if (_disposed) return;
          final scene = gltf?["scene"];
          if (scene == null) {
            debugPrint('⚠️ plateau scene is null');
            return;
          }
          scene.traverse((child) {
            if (child is three.Mesh) {
              final materials = child.material is List
                  ? child.material as List
                  : [child.material];
              for (final mat in materials) {
                if (mat == null) continue;
                mat.side = three.DoubleSide;
                // الموديل يصل بخريطة معدن، والخامة بلا خريطة بيئة تسودّ.
                mat.metalness = 0.0;
                // الخامة تحمل اللون النهائي بنفسها: العشب فيها مضروب بـ0x2F8A4E
                // (لون المرج) والحجر بقي رمليًا. أي لون هنا يُصوِّر الحجر
                // أخضر — وهو ما كان يمحو الجرف ويجعل الهضبة فطيرة عشب.
                mat.color.setHex(0xFFFFFF);
                mat.emissive?.setHex(0x0E2416);
                mat.needsUpdate = true;
              }
            }
          });
          makeTexturesUploadable(scene);
          // نُبقي خامة `plateau.jpg` كما صُنعت: عشب السطح وجرفه الصخري في
          // أطلس واحد. أي خامة واحدة تُركَّب على المجسّم كله تمحو التمييز
          // وتجعل الجرف طحلبًا باهتًا.

          final box = three.Box3().setFromObject(scene);
          final size = box.getSize(three.Vector3());
          if (size.x.abs() < 0.001 ||
              size.y.abs() < 0.001 ||
              size.z.abs() < 0.001) {
            debugPrint('⚠️ plateau has no volume');
            return;
          }
          // مقياس واحد لكل المحاور: أي فرق بينها يشدّ التكستشر.
          final uniform = targetWidth / size.x.abs();
          scene.scale.set(uniform, uniform, uniform);
          scene.updateMatrixWorld(true);
          final fitted = three.Box3().setFromObject(scene);
          final cx = (fitted.min.x + fitted.max.x) / 2;
          final cz = (fitted.min.z + fitted.max.z) / 2;
          if (!cx.isFinite || !cz.isFinite || !fitted.min.y.isFinite) return;
          scene.position.set(_kPlateauX - cx, -fitted.min.y, _kPlateauZ - cz);
          _scene.add(scene);

          // الشبكة الاحتياطية تنسحب الآن. القرص العشبي كان يغطي الأسطوانة
          // المصمتة؛ سطح الموديل عشبي أصلًا، فإبقاؤه يعني قرصًا يطفو فوق
          // التضاريس أو يتقاطع معها.
          _plateauBluffMesh?.visible = false;
          _plateauTopMesh?.visible = false;
          debugPrint('🏔️ plateau model added');
        })
        .catchError((Object e) {
          debugPrint('⚠️ plateau model failed: $e');
        });
  }

  /// رصف فناء الهضبة: بلاط حجري من حزمة الطبيعة حول مركزها.
  ///
  /// البلاطة الأصلية ~٠٫٥ × ٠٫٠٧ × ٠٫٤٤ متر (بلاطة حديقة صغيرة)، فتُكبَّر ×٣٫٩
  /// لتصير ~١٫٩٥ × ١٫٧٢ مع سماكة ٠٫٢. الشبكة ١٦×١٣ بخطوة ٢٫٠ × ١٫٧٩ تترك
  /// **مفصل ٠٫٠٥** بين البلاطات: المفصل ٠٫٣ جرّب أولًا فقرأ الفناء شبكةً خضراء
  /// مخطّطة (العشب يخترق كل صف)، والملاط الرقيق يجعل السطح حجرًا متصلًا.
  /// القناع البيضاوي ٨ × ٥٫٢ **أصغر** من نصف شبكة ١٥ × ١٠٫٧، وإلا قصّ الأركان
  /// فقط فخرج الفناء مستطيلًا؛ بهذه النسبة يصير بيضاويًا حقيقيًا ١٦ × ١٠٫٤
  /// (٥٣٪ من عرض الهضبة) بـ**٣٦ بلاطة**.
  ///
  /// **ارتفاع القاعدة ٢٫٧٦ لا ٢٫٨٥**: سطح موديل الهضبة (المقاس من ملفه)
  /// ٢٫٧٥–٢٫٩٧ في نطاق نصف القطر هذا. البلاطة بسماكة ٠٫١٧ وقاعدة على ٢٫٧٦
  /// تُدفن جزئيًا عند أعلى التموجات وتكاد تلامس العشب عند أخفضها، فلا فراغ
  /// ظاهر تحتها ولا تختفي كليًا.
  ///
  /// القوالب الأربعة تُحمَّل مرة واحدة ثم تُنسخ: البلاطة ٦٨ مثلثًا فقط، والنسخ
  /// يشترك في المواد والخامات (لا خامات أصلًا هنا) فلا يكلّف ذاكرة تُذكر.
  Future<void> _buildPlateauPaving(three.Group parent) async {
    const paths = [
      'assets/3d/floor_tile_1.glb',
      'assets/3d/floor_tile_2.glb',
      'assets/3d/floor_tile_3.glb',
      'assets/3d/floor_tile_4.glb',
    ];
    // **اللون أزرق-رمادي في الملف ليخرج حجرًا رماديًا على الشاشة.** شمس الظهيرة
    // 0xFFE082 مع محيط أخضر 0x4A6B56 تعطي للأوجه العلوية ‎(B/R ≈ 0.6)، فأي
    // رمادي متعادل هنا يصل أصفر رمليًا — وهذا ما حدث فعلًا: 0x9A968C ظهر
    // «كسكسي» على المرج. القناة الزرقاء مرفوعة لتعويض النقص، ونفس الحيلة
    // مستخدمة في river_water (٥٣،٩١،١٢٣) وgrass_rocks.
    const shades = [0x9298C4, 0x8A90BB, 0x9AA0CB, 0x848AB5];

    final templates = <three.Object3D>[];
    for (var i = 0; i < paths.length; i++) {
      try {
        final gltf = await three_jsm.GLTFLoader()
            .loadAsync(paths[i])
            .timeout(const Duration(seconds: 30));
        if (_disposed) return;
        final scene = gltf?['scene'];
        if (scene == null) continue;

        final shade = shades[i % shades.length];
        scene.traverse((child) {
          if (child is! three.Mesh) return;
          final materials = child.material is List
              ? child.material as List
              : [child.material];
          for (final mat in materials) {
            if (mat == null) continue;
            mat.side = three.DoubleSide;
            mat.metalness = 0.0;
            mat.color.setHex(shade);
            // نفس الوهج المحايد الذي تأخذه موديلات الحزمة، وإلا بدت البلاطة
            // داكنة بجانب الجزر الطافية.
            mat.emissive?.setHex(0x0C0C0C);
            mat.needsUpdate = true;
          }
        });
        makeModelCloneable(scene);
        templates.add(scene);
      } catch (e) {
        debugPrint('⚠️ paving tile failed: ${paths[i]} $e');
      }
    }
    if (_disposed || templates.isEmpty) return;

    const stepX = 2.0;
    const stepZ = 1.79;
    const cols = 16;
    const rows = 13;
    // القاعدة على سطح الهضبة المسطّح كما قيس من `plateau.glb`.
    const baseY = _kPlateauHeight - 0.09;
    const tileScale = 3.9;

    for (var row = 0; row < rows; row++) {
      final dz = (row - (rows - 1) / 2) * stepZ;
      for (var col = 0; col < cols; col++) {
        final dx = (col - (cols - 1) / 2) * stepX;
        // **القناع أصغر بكثير من الشبكة** (١١٫٥×٧٫٥ مقابل ١٥×١٠٫٧): أي قناع
        // قريب من نصف الشبكة يقصّ الأركان فقط فيخرج الفناء مستطيلًا — جرّبنا
        // ١٠٫٤×٨ على شبكة ٨٫٣×٥٫٩ فظهر بلاطة مستطيلة. هنا تُقصّ الأعمدة
        // والصفوف الطرفية كلها فيصير القوس بيضاويًا حقيقيًا.
        final nx = dx / _kPavingRadiusX;
        final nz = dz / _kPavingRadiusZ;
        if (nx * nx + nz * nz > 1.0) continue;

        // النوع عشوائي لا بالتناوب: التناوب المنتظم ١-٢-٣-٤ يرسم رقعة
        // شطرنج مرئية من بعيد، والعشوائية تذيب الفروق في نسج حجري طبيعي.
        final template = templates[_rng.nextInt(templates.length)];
        three.Object3D tile;
        try {
          tile = template.clone(true);
        } catch (e) {
          debugPrint('⚠️ paving clone failed: $e');
          continue;
        }

        // حاوية مستقلة: الجذر المنسوخ قد يحمل تحويلات المُصدِّر، فلا نكتب
        // الدوران/القياس عليه مباشرة.
        final holder = three.Group();
        holder.add(tile);
        holder.position.set(_kPlateauX + dx, baseY, _kPlateauZ + dz);
        // **لا دوران ٩٠°**: البلاطة ١٫٩٥ × ١٫٧٢ في خانة ٢٫٠ × ١٫٧٩، فإدارتها
        // تجعل ضلعها الطويل يتجاوز الخانة فيتراكب مع جارتها — وتراكب السطوح
        // المتساوية يُنتج وميض Z-fighting. الميل البسيط وحده يكسر الهندسة.
        holder.rotation.y = (_rng.nextDouble() - 0.5) * 0.04;
        // المحور الرأسي ٠٫٧: سماكة ٠٫٢ بدل ٠٫٢٨، فتبقى البلاطة قريبة من
        // العشب لا مرتفعة عنه.
        holder.scale.set(tileScale, tileScale * 0.7, tileScale);
        parent.add(holder);
      }
    }
  }

  Future<void> _buildStoneBridge() {
    // جسر حجري يعبر البحيرة الوسطى. الماء دائرة نصف قطرها ١٤٫٧٥ وشاطئها
    // ١٧٫١٥، فـ١٦٫٩ يمدّ الموديل (١٫٨٩٧ طولًا) إلى ٣٢ وحدة ويغرس طرفيه في
    // الشاطئين. **الطول لا يُصغَّر**: أي قيمة أقل تترك الجسر معلّقًا فوق الماء.
    // التصغير في العرض والارتفاع وحدهما (٨٫٩ → ٨٫٠ و١٠٫٢ → ٨٫٨)، فيصير
    // أنحف وأخفض ويترك مساحة أكبر للمرج حول البحيرة.
    const scaleX = 16.9; // 1.897 × 16.9 ≈ 32 طولًا
    const scaleY = 8.8; // 0.520 × 8.8 ≈ 4.58 ارتفاعًا
    const scaleZ = 8.0; // 1.126 × 8.0 ≈ 9.0 عرضًا

    return three_jsm.GLTFLoader()
        .loadAsync(kBridgeModel)
        .timeout(const Duration(seconds: 30))
        .then((gltf) {
          if (_disposed) return;
          final scene = gltf?["scene"];
          if (scene == null) {
            debugPrint('⚠️ bridge scene is null');
            return;
          }
          scene.traverse((child) {
            if (child is three.Mesh) {
              final materials = child.material is List
                  ? child.material as List
                  : [child.material];
              for (final mat in materials) {
                if (mat == null) continue;
                mat.side = three.DoubleSide;
                // الخامة المرسومة تحمل الظل والعمق، فلا تحتاج خريطة نواظم ولا
                // معدنًا — والمعدن بلا خريطة بيئة يسودّ.
                mat.metalness = 0.0;
                mat.needsUpdate = true;
              }
            }
          });
          makeTexturesUploadable(scene);

          scene.scale.set(scaleX, scaleY, scaleZ);
          // المركز عند ١٫٥٤: القاع ١٫٥٤ − ٢٫٢٩ = −٠٫٧٥، أي مستوى الماء
          // (kNatureWaterY = −٠٫٧٥) بالضبط، والسطح ٣٫٨٣ فوقه بقوس ظاهر.
          final lake = _centralLake;
          scene.position.set(lake[0], 1.54, lake[1]);
          _scene.add(scene);
          debugPrint('🌉 bridge model added');
        })
        .catchError((Object e) {
          debugPrint('⚠️ bridge model failed: $e');
          if (!_disposed) _buildFallbackBridge();
        });
  }

  /// نسخة الصندوق القديمة تبقى كخطة بديلة إن فشل الموديل في التحميل، حتى لا
  /// يختفي المعبر من المشهد كله بسبب ملف واحد.
  void _buildFallbackBridge() {
    final bridgeGroup = three.Group();
    final lake = _centralLake;
    bridgeGroup.position.set(lake[0], 0, lake[1]);

    final marbleMat = three.MeshPhongMaterial({
      "color": 0xA79B7E,
      "emissive": 0x0C0A06,
      "specular": 0x7A7462,
      "shininess": 16,
      "flatShading": true,
    });

    // Arch Deck
    final arch = three.Mesh(three.BoxGeometry(32, 1.2, 7.5), marbleMat);
    arch.position.set(0, 1.6, 0);
    bridgeGroup.add(arch);

    // Ramps
    final leftRamp = three.Mesh(three.BoxGeometry(10, 0.9, 7.5), marbleMat);
    leftRamp.position.set(-15.5, 0.7, 0);
    leftRamp.rotation.z = 0.16;
    bridgeGroup.add(leftRamp);

    final rightRamp = three.Mesh(three.BoxGeometry(10, 0.9, 7.5), marbleMat);
    rightRamp.position.set(15.5, 0.7, 0);
    rightRamp.rotation.z = -0.16;
    bridgeGroup.add(rightRamp);

    _scene.add(bridgeGroup);
  }

  /// زنابق الماء على سطح البحيرتين، لا في مجرى نهر.
  ///
  /// داخل ٧٢٪ من نصف قطر الماء: ما يقرب من الحافة يطفو فوق الشاطئ المرتفع
  /// (~١٫٢ فوق المرج) فيبدو معلّقًا في الهواء.
  void _buildWaterLilies() {
    final padMat = three.MeshPhongMaterial({
      "color": 0x2E7D32,
      "shininess": 40,
    });
    final lotusWhite = three.MeshPhongMaterial({
      "color": 0xFFFFFF,
      "emissive": 0xF48FB1,
      "shininess": 90,
    });

    for (final lake in kNatureLakes) {
      for (int i = 0; i < 10; i++) {
        final r = lake[2] * 0.72 * sqrt(_rng.nextDouble());
        final a = _rng.nextDouble() * pi * 2;
        final x = lake[0] + r * cos(a);
        final z = lake[1] + r * sin(a);

        final lilyGroup = three.Group();
        lilyGroup.position.set(x, kNatureWaterY + 0.03, z);

        final pad = three.Mesh(
          three.CylinderGeometry(1.2, 1.2, 0.06, 8),
          padMat,
        );
        lilyGroup.add(pad);

        final lotus = three.Mesh(three.ConeGeometry(0.5, 0.65, 6), lotusWhite);
        lotus.position.y = 0.35;
        lilyGroup.add(lotus);

        _scene.add(lilyGroup);
      }
    }
  }

  // =========================================================================
  // 🍃 4. FLUTTERING WIND LEAVES & BIRDS & FIREFLIES
  // =========================================================================

  void _buildLightParticlesAndWildlife() {
    // 1. Floating Golden Fireflies
    _particlesGroup.clear();
    _scene.add(_particlesGroup);
    _particleInitialY.clear();
    _particleSpeeds.clear();

    final particleGeo = three.SphereGeometry(0.2, 4, 4);
    final particleMat = three.MeshBasicMaterial({"color": 0xFFF59D});

    for (int i = 0; i < 80; i++) {
      final pMesh = three.Mesh(particleGeo, particleMat);
      final x = (_rng.nextDouble() * _kGroundW * 0.7) - (_kGroundW * 0.35);
      final y = 3.0 + _rng.nextDouble() * 24.0;
      final z = (_rng.nextDouble() * _kGroundD * 0.7) - (_kGroundD * 0.35);
      pMesh.position.set(x, y, z);
      _particlesGroup.add(pMesh);
      _particleInitialY.add(y);
      _particleSpeeds.add(0.015 + _rng.nextDouble() * 0.02);
    }

    // 2. Fluttering Falling Wind Leaves & Sakura Petals
    _fallingLeavesGroup.clear();
    _leafVelocities.clear();
    _scene.add(_fallingLeavesGroup);

    final leafMatPink = three.MeshBasicMaterial({
      "color": 0xF8BBD0,
      "side": three.DoubleSide,
    });
    final leafMatGold = three.MeshBasicMaterial({
      "color": 0xFFD54F,
      "side": three.DoubleSide,
    });
    final leafMatGreen = three.MeshBasicMaterial({
      "color": 0x81C784,
      "side": three.DoubleSide,
    });

    final leafGeo = three.PlaneGeometry(0.45, 0.3);

    for (int l = 0; l < 45; l++) {
      final mat = (l % 3 == 0)
          ? leafMatPink
          : (l % 3 == 1 ? leafMatGold : leafMatGreen);
      final leaf = three.Mesh(leafGeo, mat);
      final lx = (_rng.nextDouble() * _kGroundW * 0.6) - (_kGroundW * 0.3);
      final ly = 2.0 + _rng.nextDouble() * 26.0;
      final lz = (_rng.nextDouble() * _kGroundD * 0.6) - (_kGroundD * 0.3);
      leaf.position.set(lx, ly, lz);
      leaf.rotation.set(
        _rng.nextDouble() * 3,
        _rng.nextDouble() * 3,
        _rng.nextDouble() * 3,
      );
      _fallingLeavesGroup.add(leaf);
      _leafVelocities.add(
        three.Vector3(
          0.04 + _rng.nextDouble() * 0.03, // Drift with wind along +X
          -0.015 - _rng.nextDouble() * 0.02, // Gentle downward glide
          0.03 + _rng.nextDouble() * 0.02, // Drift along +Z
        ),
      );
    }

    // 3. White Doves Flying
    _birdsGroup.clear();
    final doveMat = three.MeshBasicMaterial({
      "color": 0xFFFFFF,
      "side": three.DoubleSide,
    });
    for (int b = 0; b < 5; b++) {
      final bird = three.Group();
      bird.position.set(-45 + b * 20.0, 42.0 + (b % 3) * 5.0, -35.0 + b * 14.0);

      final w1 = three.Mesh(three.PlaneGeometry(1.3, 0.5), doveMat);
      w1.position.set(0.55, 0, 0);
      bird.add(w1);

      final w2 = three.Mesh(three.PlaneGeometry(1.3, 0.5), doveMat);
      w2.position.set(-0.55, 0, 0);
      bird.add(w2);

      _birdsGroup.add(bird);
    }
    _scene.add(_birdsGroup);
  }

  // =========================================================================
  // 🏛️ 5. DISTINCT ARCHITECTURE & VISUAL PROGRESSION (TIERS 1 TO 5)
  // =========================================================================

  three.Object3D _buildProceduralPalm({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final segmentCount = tier == 1 ? 4 : (tier == 2 ? 5 : (tier == 3 ? 6 : 8));
    final trunkColor = isGoldTier ? 0xFFD700 : 0x795548;

    for (int s = 0; s < segmentCount; s++) {
      final topR = 0.44 - s * 0.035;
      final botR = 0.50 - s * 0.03;
      final mat = three.MeshPhongMaterial({
        "color": isGoldTier ? 0xFFD700 : (s % 2 == 0 ? 0x8D6E63 : trunkColor),
        "emissive": isGoldTier ? 0x665200 : 0x000000,
        "shininess": isGoldTier ? 90 : 15,
        "flatShading": true,
      });
      final segment = three.Mesh(
        three.CylinderGeometry(topR, botR, 1.0, 10),
        mat,
      );
      segment.position.set(
        sin(s * 0.12) * 0.25,
        0.5 + s * 0.95,
        cos(s * 0.08) * 0.1,
      );
      segment.rotation.z = -s * 0.03;
      group.add(segment);
    }

    final topY = segmentCount * 0.95 + 0.2;

    if (tier >= 2) {
      final dateMat = three.MeshPhongMaterial({
        "color": isGoldTier ? 0xFFEA00 : 0xE65100,
        "emissive": isGoldTier ? 0x775500 : 0x4E2700,
        "shininess": 60,
      });
      final bunchCount = tier == 2 ? 3 : (tier == 3 ? 5 : 7);
      for (int d = 0; d < bunchCount; d++) {
        final a = (d / bunchCount) * three.Math.pi * 2;
        for (int b = 0; b < (tier >= 4 ? 4 : 2); b++) {
          final date = three.Mesh(three.SphereGeometry(0.14, 6, 6), dateMat);
          date.position.set(0.65 * sin(a), topY - 0.4 - b * 0.2, 0.65 * cos(a));
          group.add(date);
        }
      }
    }

    final frondColorDark = isGoldTier ? 0xFFD700 : 0x1B5E20;
    final frondColorLight = isGoldTier ? 0xFFEB3B : 0x388E3C;
    final frondDark = three.MeshPhongMaterial({
      "color": frondColorDark,
      "shininess": 30,
      "side": three.DoubleSide,
      "flatShading": true,
    });
    final frondLight = three.MeshPhongMaterial({
      "color": frondColorLight,
      "shininess": 35,
      "side": three.DoubleSide,
      "flatShading": true,
    });

    final layers = tier == 1 ? 1 : 2;
    final frondLen = tier == 1
        ? 3.0
        : (tier == 2 ? 3.8 : (tier == 3 ? 4.5 : 5.4));
    final frondCount = tier == 1 ? 5 : (tier == 2 ? 7 : (tier == 3 ? 10 : 14));

    for (int l = 0; l < layers; l++) {
      final count = l == 0 ? frondCount : (frondCount * 0.6).toInt();
      final mat = l == 0 ? frondDark : frondLight;
      final yBase = topY + (l * 0.3);
      for (int i = 0; i < count; i++) {
        final angle = (i / count) * three.Math.pi * 2 + l * 0.3;
        final frond = three.Mesh(three.ConeGeometry(0.85, frondLen, 5), mat);
        frond.position.set(
          (frondLen * 0.38) * sin(angle),
          yBase - 0.5,
          (frondLen * 0.38) * cos(angle),
        );
        frond.rotation.z = 0.68;
        frond.rotation.y = -angle + three.Math.pi / 2;
        group.add(frond);
      }
    }

    final s = tier == 1
        ? 0.6
        : (tier == 2 ? 0.75 : (tier == 3 ? 0.9 : (tier == 4 ? 1.05 : 1.2)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _buildProceduralTree({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final trunkMat = three.MeshPhongMaterial({
      "color": isGoldTier ? 0xFFD700 : 0x4E342E,
      "emissive": isGoldTier ? 0x554400 : 0x000000,
      "shininess": isGoldTier ? 80 : 15,
      "flatShading": true,
    });
    final trunk = three.Mesh(
      three.CylinderGeometry(0.35, 0.6, 3.4, 10),
      trunkMat,
    );
    trunk.position.y = 1.7;
    group.add(trunk);

    if (tier >= 2) {
      for (int r = 0; r < 4; r++) {
        final angle = (r / 4) * three.Math.pi * 2;
        final root = three.Mesh(
          three.CylinderGeometry(0.12, 0.3, 0.8, 6),
          trunkMat,
        );
        root.position.set(sin(angle) * 0.5, 0.25, cos(angle) * 0.5);
        root.rotation.z = sin(angle) * 0.45;
        root.rotation.x = cos(angle) * 0.45;
        group.add(root);
      }
    }

    final leafColors = isGoldTier
        ? [0xFFD700, 0xFFEB3B, 0xFFF176, 0xFFD700, 0xFFC107]
        : (tier >= 4
              ? [
                  0x2E7D32,
                  0x388E3C,
                  0x43A047,
                  0xF8BBD0,
                  0xF48FB1,
                  0x388E3C,
                  0x2E7D32,
                ]
              : [0x2E7D32, 0x388E3C, 0x43A047, 0x4CAF50, 0x2E7D32]);

    final clusterConfigs = [
      [0.0, 4.8, 0.0, 2.0],
      [1.2, 4.2, 0.7, 1.6],
      [-1.1, 4.3, -0.5, 1.6],
      [0.4, 5.6, -0.3, 1.4],
      [-0.6, 5.1, 0.7, 1.4],
      [0.8, 5.4, -0.6, 1.2],
      [-0.2, 6.1, 0.1, 1.0],
    ];

    final clustersCount = tier == 1 ? 2 : (tier == 2 ? 4 : (tier == 3 ? 5 : 7));

    for (int i = 0; i < clustersCount; i++) {
      final p = clusterConfigs[i % clusterConfigs.length];
      final mat = three.MeshPhongMaterial({
        "color": leafColors[i % leafColors.length],
        "emissive": isGoldTier ? 0x443300 : 0x000000,
        "shininess": isGoldTier ? 80 : 20,
        "flatShading": true,
      });
      final leaf = three.Mesh(three.IcosahedronGeometry(p[3], 1), mat);
      leaf.position.set(p[0], p[1], p[2]);
      leaf.scale.set(1.0, 0.75, 1.0);
      group.add(leaf);
    }

    final s = tier == 1
        ? 0.6
        : (tier == 2 ? 0.75 : (tier == 3 ? 0.9 : (tier == 4 ? 1.05 : 1.2)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _buildProceduralChest({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final woodMat = three.MeshPhongMaterial({
      "color": isGoldTier ? 0x8D6E63 : 0x5D4037,
      "shininess": 35,
    });
    final goldMat = three.MeshPhongMaterial({
      "color": 0xFFA000,
      "emissive": 0x6B4B00,
      "shininess": 100,
    });
    final innerMat = three.MeshPhongMaterial({
      "color": 0xFFF9C4,
      "emissive": 0xFFA000,
      "shininess": 60,
    });

    final body = three.Mesh(three.BoxGeometry(1.8, 0.9, 1.2), woodMat);
    body.position.y = 0.45;
    group.add(body);

    final inner = three.Mesh(three.BoxGeometry(1.6, 0.3, 1.0), innerMat);
    inner.position.y = 0.75;
    group.add(inner);

    for (double sx in [-0.55, 0.0, 0.55]) {
      final strap = three.Mesh(three.BoxGeometry(0.08, 0.92, 1.22), goldMat);
      strap.position.set(sx, 0.45, 0);
      group.add(strap);
    }

    final lid = three.Mesh(three.BoxGeometry(1.8, 0.15, 1.2), woodMat);
    lid.position.set(0, 1.0, -0.4);
    lid.rotation.x = -0.5;
    group.add(lid);

    final coinCount = tier * 3;
    for (int c = 0; c < coinCount.clamp(3, 12); c++) {
      final coin = three.Mesh(
        three.CylinderGeometry(0.12, 0.12, 0.04, 8),
        goldMat,
      );
      coin.position.set(
        (_rng.nextDouble() - 0.5) * 1.0,
        0.9 + _rng.nextDouble() * 0.2,
        (_rng.nextDouble() - 0.5) * 0.5,
      );
      coin.rotation.x = _rng.nextDouble();
      coin.rotation.z = _rng.nextDouble();
      group.add(coin);
    }

    final diamond = three.Mesh(
      three.OctahedronGeometry(0.25 + tier * 0.04),
      three.MeshPhongMaterial({
        "color": isGoldTier ? 0xFFD700 : 0x00E5FF,
        "emissive": 0x0097A7,
        "shininess": 100,
      }),
    );
    diamond.position.set(0, 1.2, 0);
    group.add(diamond);

    group.scale.set(0.65, 0.65, 0.65);
    return group;
  }

  three.Object3D _buildProceduralHouse({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final wallMat = three.MeshPhongMaterial({
      "color": isGoldTier ? 0xFFF8E1 : 0xFFFFFF,
      "shininess": 20,
      "flatShading": true,
    });
    final woodMat = three.MeshPhongMaterial({
      "color": 0x4E342E,
      "shininess": 20,
    });
    final roofMat = three.MeshPhongMaterial({
      "color": isGoldTier ? 0xFFA000 : (tier >= 3 ? 0x00897B : 0xBF360C),
      "emissive": isGoldTier ? 0x442200 : 0x000000,
      "shininess": 35,
      "flatShading": true,
    });
    final goldMat = three.MeshPhongMaterial({
      "color": 0xFFA000,
      "shininess": 90,
    });

    final foundation = three.Mesh(three.BoxGeometry(3.8, 0.3, 3.0), woodMat);
    foundation.position.y = 0.15;
    group.add(foundation);

    final walls = three.Mesh(three.BoxGeometry(3.4, 2.4, 2.6), wallMat);
    walls.position.y = 1.35;
    group.add(walls);

    final roof = three.Mesh(three.ConeGeometry(2.8, 1.6, 4), roofMat);
    roof.position.y = 3.35;
    roof.rotation.y = three.Math.pi / 4;
    group.add(roof);

    final finial = three.Mesh(three.SphereGeometry(0.2, 10, 10), goldMat);
    finial.position.y = 4.2;
    group.add(finial);

    final door = three.Mesh(three.BoxGeometry(0.7, 1.3, 0.08), woodMat);
    door.position.set(0, 0.8, 1.32);
    group.add(door);

    final windowMat = three.MeshBasicMaterial({"color": 0xFFE082});
    for (int side in [-1, 1]) {
      final window = three.Mesh(three.BoxGeometry(0.55, 0.55, 0.06), windowMat);
      window.position.set(side * 1.0, 1.5, 1.32);
      group.add(window);
    }

    final s = tier == 1
        ? 0.75
        : (tier == 2 ? 0.85 : (tier == 3 ? 0.95 : (tier == 4 ? 1.05 : 1.15)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _buildProceduralMosque({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final marbleMat = three.MeshPhongMaterial({
      "color": 0xFFFFFF,
      "emissive": 0x111111,
      "specular": 0xFFFFFF,
      "shininess": 80,
      "flatShading": true,
    });
    final goldMat = three.MeshPhongMaterial({
      "color": 0xFFA000,
      "emissive": 0x6A4400,
      "shininess": 100,
    });
    final domeColor = isGoldTier ? 0xFFA000 : (tier >= 3 ? 0x00897B : 0xFFA000);
    final domeMat = three.MeshPhongMaterial({
      "color": domeColor,
      "emissive": isGoldTier ? 0x553300 : 0x00332A,
      "shininess": 95,
    });
    final darkMarble = three.MeshPhongMaterial({
      "color": 0xE0E0E0,
      "shininess": 40,
      "flatShading": true,
    });

    final platform = three.Mesh(three.BoxGeometry(6.6, 0.5, 5.0), darkMarble);
    platform.position.y = 0.25;
    group.add(platform);

    final hall = three.Mesh(three.BoxGeometry(5.0, 2.2, 3.8), marbleMat);
    hall.position.y = 1.35;
    group.add(hall);

    for (int c = -2; c <= 2; c++) {
      final col = three.Mesh(
        three.CylinderGeometry(0.16, 0.2, 2.2, 10),
        marbleMat,
      );
      col.position.set(c * 1.0, 1.35, 1.95);
      group.add(col);
    }

    final dome = three.Mesh(three.SphereGeometry(1.6, 18, 16), domeMat);
    dome.position.y = 4.7;
    dome.scale.set(1.0, 0.85, 1.0);
    group.add(dome);

    final finial = three.Mesh(three.ConeGeometry(0.18, 0.9, 8), goldMat);
    finial.position.y = 5.9;
    group.add(finial);

    final crescent = three.Mesh(
      three.TorusGeometry(0.22, 0.05, 6, 12, three.Math.pi * 1.4),
      goldMat,
    );
    crescent.position.set(0, 6.45, 0);
    group.add(crescent);

    final minaretCount = tier == 1 ? 2 : 4;
    final minaretCoords = minaretCount == 2
        ? [
            [-1, 1],
            [1, 1],
          ]
        : [
            [-1, -1],
            [1, -1],
            [-1, 1],
            [1, 1],
          ];

    for (final mc in minaretCoords) {
      final mx = mc[0];
      final mz = mc[1];
      final mGroup = three.Group();
      mGroup.position.set(mx * 2.9, 0, mz * 2.2);

      final shaft = three.Mesh(
        three.CylinderGeometry(0.26, 0.36, 5.4, 12),
        marbleMat,
      );
      shaft.position.y = 3.0;
      mGroup.add(shaft);

      final balcony1 = three.Mesh(
        three.TorusGeometry(0.44, 0.06, 6, 14),
        goldMat,
      );
      balcony1.position.y = 4.8;
      balcony1.rotation.x = three.Math.pi / 2;
      mGroup.add(balcony1);

      final mDome = three.Mesh(three.SphereGeometry(0.36, 12, 10), domeMat);
      mDome.position.y = 5.7;
      mDome.scale.set(1.0, 1.3, 1.0);
      mGroup.add(mDome);

      final spire = three.Mesh(three.ConeGeometry(0.1, 0.8, 8), goldMat);
      spire.position.y = 6.4;
      mGroup.add(spire);

      group.add(mGroup);
    }

    final s = tier == 1
        ? 0.75
        : (tier == 2 ? 0.88 : (tier == 3 ? 1.0 : (tier == 4 ? 1.15 : 1.3)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _buildProceduralPalace({int tier = 1}) {
    final group = three.Group();
    final isGoldTier = tier >= 5;

    final marbleMat = three.MeshPhongMaterial({
      "color": isGoldTier ? 0xFFF8E1 : 0xFFFFFF,
      "emissive": isGoldTier ? 0x443300 : 0x111111,
      "specular": 0xFFFFFF,
      "shininess": 85,
      "flatShading": true,
    });
    final goldMat = three.MeshPhongMaterial({
      "color": 0xFFA000,
      "emissive": 0x6A4400,
      "shininess": 100,
    });
    final darkMarble = three.MeshPhongMaterial({
      "color": 0xE0E0E0,
      "shininess": 40,
      "flatShading": true,
    });
    final emeraldMat = three.MeshPhongMaterial({
      "color": 0x00C853,
      "emissive": 0x004D1A,
      "shininess": 90,
    });

    final platform = three.Mesh(three.BoxGeometry(7.2, 0.6, 5.6), darkMarble);
    platform.position.y = 0.3;
    group.add(platform);

    final tier1 = three.Mesh(three.BoxGeometry(5.6, 2.4, 4.2), marbleMat);
    tier1.position.y = 1.5;
    group.add(tier1);

    final tier2 = three.Mesh(three.BoxGeometry(4.0, 1.8, 3.0), marbleMat);
    tier2.position.y = 3.6;
    group.add(tier2);

    final centerDome = three.Mesh(three.SphereGeometry(1.5, 18, 16), goldMat);
    centerDome.position.y = 5.3;
    centerDome.scale.set(1.0, 0.85, 1.0);
    group.add(centerDome);

    final spire = three.Mesh(three.ConeGeometry(0.18, 0.9, 8), goldMat);
    spire.position.y = 6.4;
    group.add(spire);

    final gem = three.Mesh(three.SphereGeometry(0.16, 8, 8), emeraldMat);
    gem.position.y = 7.0;
    group.add(gem);

    for (int sx in [-1, 1]) {
      final sideDome = three.Mesh(three.SphereGeometry(0.8, 14, 12), goldMat);
      sideDome.position.set(sx * 2.1, 3.2, 0);
      group.add(sideDome);
    }

    for (int mx in [-1, 1]) {
      for (int mz in [-1, 1]) {
        final tGroup = three.Group();
        tGroup.position.set(mx * 3.1, 0, mz * 2.4);

        final tower = three.Mesh(three.BoxGeometry(0.9, 4.8, 0.9), marbleMat);
        tower.position.y = 2.4;
        tGroup.add(tower);

        final tRoof = three.Mesh(three.ConeGeometry(0.65, 1.2, 4), goldMat);
        tRoof.position.y = 5.4;
        tRoof.rotation.y = three.Math.pi / 4;
        tGroup.add(tRoof);

        group.add(tGroup);
      }
    }

    final stair = three.Mesh(three.BoxGeometry(2.0, 0.4, 1.0), darkMarble);
    stair.position.set(0, 0.4, 2.3);
    group.add(stair);

    final portal = three.Mesh(three.BoxGeometry(1.4, 2.0, 0.1), goldMat);
    portal.position.set(0, 1.4, 2.12);
    group.add(portal);

    final s = tier == 1
        ? 0.75
        : (tier == 2 ? 0.88 : (tier == 3 ? 1.0 : (tier == 4 ? 1.15 : 1.3)));
    group.scale.set(s, s, s);
    return group;
  }

  three.Object3D _fallbackForType(RewardType type, {int tier = 1}) {
    switch (type) {
      case RewardType.palmTree:
        return _buildProceduralPalm(tier: tier);
      case RewardType.tree:
        return _buildProceduralTree(tier: tier);
      case RewardType.treasure:
        return _buildProceduralChest(tier: tier);
      case RewardType.house:
        return _buildProceduralHouse(tier: tier);
      case RewardType.palace:
        return _buildProceduralPalace(tier: tier);
      case RewardType.mosque:
        return _buildProceduralMosque(tier: tier);
    }
  }

  bool _isFarEnough(double x, double z) {
    if (!_isPlantable(x, z)) return false;

    for (final e in _savedEntries) {
      final dx = x - e.x;
      final dz = z - e.z;
      if ((dx * dx + dz * dz) < (_kMinSpacing * _kMinSpacing)) return false;
    }
    return true;
  }

  three.Vector3 _nextSpawnPosForType(RewardType type) {
    double x = 0;
    double z = 0;
    double y = 0;
    int tries = 0;

    switch (type) {
      case RewardType.palmTree:
        do {
          // النخيل في النصف الشرقي، والشجر في الغربي — التمييز القديم نفسه
          // لكن على مستطيل الجزيرة الجديد لا على ضفّتي النهر.
          x = 4.0 + _rng.nextDouble() * 78.0;
          z = _kPlantMinZ + _rng.nextDouble() * (_kPlantMaxZ - _kPlantMinZ);
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;

      case RewardType.tree:
        do {
          x = -76.0 + _rng.nextDouble() * 80.0;
          z = _kPlantMinZ + _rng.nextDouble() * (_kPlantMaxZ - _kPlantMinZ);
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;

      case RewardType.palace:
      case RewardType.mosque:
        do {
          // مستطيل داخل بيضاوي الهضبة (١٥ × ١٠٫٦): أركانه عند نصف قطر طبيعي
          // ٠٫٦٩، فتظل الظلال على السطح لا في الهواء.
          x = 17.0 + _rng.nextDouble() * 14.0;
          z = 17.0 + _rng.nextDouble() * 9.0;
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;

      case RewardType.house:
        do {
          x = -76.0 + _rng.nextDouble() * 58.0;
          z = 10.0 + _rng.nextDouble() * 66.0;
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;

      case RewardType.treasure:
        do {
          final isEast = _rng.nextBool();
          x = isEast
              ? 10.0 + _rng.nextDouble() * 72.0
              : -10.0 - _rng.nextDouble() * 66.0;
          z = _kPlantMinZ + _rng.nextDouble() * (_kPlantMaxZ - _kPlantMinZ);
          tries++;
        } while (!_isFarEnough(x, z) && tries < 90);
        break;
    }

    y = _calculateGroundElevation(x, z);
    return three.Vector3(x, y, z);
  }

  /// هل تصلح ([x], [z]) لغرسة؟ مرج الجزيرة، وبعيدة عن كل موديل قائم بمسافة
  /// [_kMinSpacing] على الأقل.
  bool _hasRoomAt(double x, double z) {
    if (!_isPlantable(x, z)) return false;
    for (final e in _savedEntries) {
      final dx = x - e.x;
      final dz = z - e.z;
      if (dx * dx + dz * dz < _kMinSpacing * _kMinSpacing) return false;
    }
    return true;
  }

  /// يحاول إيجاد موقع في حلقة حول ما تنظر إليه الكاميرا الآن. النخيل والكنز
  /// في نصفها الشرقي، والشجر والبيوت في نصفها الغربي — نفس تمييز المناطق
  /// القديم، لكن بالنسبة للكاميرا بدل مركز العالم.
  three.Vector3? _tryPlantRing(
    double inner,
    double outer,
    RewardType type,
    int tries, {
    bool biased = true,
  }) {
    final cx = _controls.target.x;
    final cz = _controls.target.z;
    final bool east =
        biased && (type == RewardType.palmTree || type == RewardType.treasure);
    final bool west =
        biased && (type == RewardType.tree || type == RewardType.house);

    for (var i = 0; i < tries; i++) {
      final r = inner + _rng.nextDouble() * (outer - inner);
      double a = _rng.nextDouble() * pi * 2;
      if (east) {
        a = (_rng.nextDouble() - 0.5) * pi;
      } else if (west) {
        a = (_rng.nextDouble() - 0.5) * pi + pi;
      }
      final x = cx + r * cos(a);
      final z = cz + r * sin(a);
      if (_hasRoomAt(x, z)) {
        return three.Vector3(x, _calculateGroundElevation(x, z), z);
      }
    }
    return null;
  }

  /// موقع الغرس اليدوي: حول الكاميرا أولًا، ثم دوائر أوسع إن كانت المنطقة
  /// مزدحمة، ثم مناطق العالم القديمة كملاذ أخير.
  three.Vector3 _nextPlantPosForType(RewardType type) {
    const rings = [
      [10.0, 22.0],
      [22.0, 34.0],
      [34.0, 48.0],
    ];
    // أولًا الجهة المفضّلة: النخيل شرقًا والشجر غربًا.
    for (final ring in rings) {
      final pos = _tryPlantRing(ring[0], ring[1], type, 30);
      if (pos != null) return pos;
    }
    // ثم الحلقة كاملة بلا تمييز جهة، حتى لا يقفز الهدف إلى طرف الأرض حين
    // تمتلئ الجهة المفضّلة.
    for (final ring in rings) {
      final pos = _tryPlantRing(ring[0], ring[1], type, 24, biased: false);
      if (pos != null) return pos;
    }
    return _nextSpawnPosForType(type);
  }

  /// هل تقع [p] داخل الكادر بهامش مريح؟ تُحسب إحداثيات NDC من مصفوفتَي العرض
  /// والإسقاط، فلا حاجة لاستنتاج fov أو aspect يدويًا.
  bool _isInSafeFrame(three.Vector3 p, {double margin = 0.8}) {
    _camera.updateMatrixWorld(true);
    final view = p.clone().applyMatrix4(_camera.matrixWorldInverse);
    if (view.z > -0.5) return false; // خلف الكاميرا
    final ndc = view.applyMatrix4(_camera.projectionMatrix);
    return ndc.x.abs() <= margin && ndc.y.abs() <= margin;
  }

  /// يُنعّم الكاميرا نحو الغرسة الجديدة عند الحاجة فقط.
  void _revealPlant(three.Vector3 p) {
    if (_isInSafeFrame(p)) return; // ظاهرة أصلًا — لا نُحرّك شيئًا
    _flyCameraFrom = _camera.position.clone();
    _flyOriginTarget = _controls.target.clone();
    _flyTarget = three.Vector3(p.x, p.y + 1.6, p.z);
    _flyStartMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// وميض ذهبي قصير عند ارتقاء نوع إلى مرحلة أعلى: جزيئات صغيرة تتصاعد
  /// وتخفت معًا. الجزيئات تُزال من المشهد بعد ١٫٤ ثانية، فلا تتراكم.
  void _spawnGoldBurst(three.Vector3 at) {
    final group = three.Group();
    group.position.set(at.x, at.y + 0.25, at.z);

    // مادة واحدة لكل الوميض: الخفوت جماعي، وهو المطلوب بصريًا، وأرخص بكثير
    // من مادة لكل جزيء.
    final material = three.MeshBasicMaterial({
      "color": 0xFFD54F,
      "transparent": true,
      "opacity": 0.95,
      "blending": three.AdditiveBlending,
      "depthWrite": false,
    });
    final geometry = three.SphereGeometry(1, 6, 6);

    final velocities = <three.Vector3>[];
    for (var i = 0; i < 20; i++) {
      final size = 0.06 + _rng.nextDouble() * 0.07;
      final particle = three.Mesh(geometry, material);
      particle.scale.set(size, size, size);
      group.add(particle);
      velocities.add(
        three.Vector3(
          (_rng.nextDouble() - 0.5) * 0.18,
          0.16 + _rng.nextDouble() * 0.22,
          (_rng.nextDouble() - 0.5) * 0.18,
        ),
      );
    }

    _scene.add(group);
    _goldBursts.add(
      _GoldBurst(
        group,
        velocities,
        material,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<three.Object3D?> _loadGLB(
    String path,
    RewardType type, {
    int tier = 1,
  }) async {
    // The same file can serve two tiers (e.g. the palm reuses the tier-4 model
    // for tier 5), and the cached copy is already scaled for its tier, so the
    // tier has to be part of the key.
    final cacheKey = '$path#$tier';
    if (_glbCache.containsKey(cacheKey)) {
      return _glbCache[cacheKey]!.clone(true);
    }

    try {
      debugPrint('📥 Loading GLB: $path (tier $tier)');
      final loader = three_jsm.GLTFLoader();
      final gltf = await loader
          .loadAsync(path)
          .timeout(const Duration(seconds: 15));

      if (gltf == null || gltf["scene"] == null) {
        debugPrint('⚠️ GLB scene is null for $path');
        return null;
      }

      final scene = gltf["scene"];

      scene.traverse((child) {
        if (child is three.Mesh) {
          final materials = child.material is List
              ? child.material as List
              : [child.material];
          for (final mat in materials) {
            if (mat != null) {
              mat.side = three.DoubleSide;

              // The exports ship metallicFactor 1.0, and this scene has no
              // environment map. A fully metallic surface reflects only its
              // environment, so it renders pure black — which is exactly how
              // every tree arrived on screen the first time the models loaded.
              // Leaves and bark are dielectric anyway.
              mat.metalness = 0.0;

              if (mat.map != null) {
                // glTF declares alphaMode MASK for every staged model. The old
                // code forced alpha blending on top of the cutout, which makes
                // leaf cards fight over draw order; a plain cutout is what the
                // file asks for, and it is cheaper.
                mat.transparent = false;
                mat.alphaTest = 0.5;
              }

              if (tier == 5) {
                // Gold without an environment map has to come from the base
                // colour and a little self-illumination, not from metalness —
                // metalness here would swing straight back to black.
                mat.color.setHex(0xFFD700);
                mat.roughness = 0.35;
                mat.emissive.setHex(0x2A1E00);
              }

              mat.needsUpdate = true;
            }
          }
        }
      });

      // The loader's image object cannot be uploaded as it is, so the texture
      // pixels are handed over as raw bytes. Without this every model renders
      // as a black silhouette.
      makeTexturesUploadable(scene);

      // three_dart cannot clone 32-bit index buffers, and every instance after
      // the first is a clone — so this has to run before the model is cached.
      makeModelCloneable(scene);
      fitModelToGround(scene, tierHeight(tier));
      _glbCache[cacheKey] = scene;
      debugPrint('✅ GLB cached: $cacheKey');
      return scene.clone(true);
    } catch (e) {
      debugPrint('⚠️ GLB failed for $path: $e');
      return null;
    }
  }

  /// Replaces the model child of [model] with the staged GLB, when the type
  /// and tier have one. Runs through [_glbQueue] so only one model parses at a
  /// time.
  Future<void> _upgradeToGLB(_AnimatedModel model) async {
    final tier = model.tier;
    final revision = model.revision;
    final path = resolveTierModelPath(model.type, tier);
    if (path == null) return;
    // قد يكون النوع ارتقى بينما كان هذا الطلب في الطابور: تحميل المرحلة
    // القديمة أولًا يُظهر الموديل صغيرًا ثم يكبّره بعد ثوانٍ، وهو وميض
    // حجم لا معنى له. الطلب الأحدث وحده هو الذي يُنفَّذ.
    if (model.tier != tier) return;

    try {
      final glb = await _loadGLB(path, model.type, tier: tier);
      if (glb == null || _disposed) return;
      // The entry may have been undone, or the screen rebuilt, while the model
      // was parsing.
      if (model.mesh.parent == null) return;
      if (model.revision != revision || model.tier != tier) return;

      // نضبط المقاس واللون قبل الاستبدال، فلا تظهر نسخة بمقاس خاطئ لإطار.
      _styleModelChild(model, glb);
      final oldChild = model.modelChild;
      if (oldChild != null) model.mesh.remove(oldChild);
      model.mesh.add(glb);
      model.modelChild = glb;
      model.glbActive = true;
      model.glbTier = tier;
      debugPrint('⬆️ Model active: ${model.type} (Tier $tier)');
    } catch (e) {
      debugPrint('⚠️ Upgrade failed for ${model.type} (Tier $tier): $e');
    }
  }

  void _enqueueUpgrade(_AnimatedModel model) {
    _glbQueue = _glbQueue
        .then((_) async {
          if (_disposed) return;
          await _upgradeToGLB(model);
        })
        .catchError((Object e) {
          debugPrint('⚠️ GLB queue: $e');
        });
  }

  /// يطبّق ارتفاع المرحلة ولونها على نسخة GLB جديدة (موادها مستقلة).
  void _styleModelChild(_AnimatedModel model, three.Object3D child) {
    if (hasTierModels(model.type)) {
      final height = modelInstanceHeight(
        model.tier,
        model.stage,
        model.scaleMultiplier,
      );
      fitModelToGround(
        child,
        height,
        sink: _groundSinkOf(model.type, model.tier, height),
      );
    }
    _applyTint(child, model.tint);
    model.appliedTint = model.tint;
  }

  /// كم يُدفن الموديل تحت الأرض: قاعدة النخلة العشبية كبيرة في المرتبة الأولى،
  /// والشجر جذعه في الأسفل. التفاصيل في `modelGroundSink`.
  double _groundSinkOf(RewardType type, int tier, double height) =>
      modelGroundSink(
        isPalm: type == RewardType.palmTree,
        tier: tier,
        height: height,
      );

  /// يمزج مواد الموديل نحو لون المرحلة. المواد هنا ملك الموديل وحده
  /// (الإجرائية تُبنى جديدة، و`Mesh.clone` يستنسخ مواد الـGLB)، فلا تتلوّن
  /// بقية الحديقة معها. نستبعد المادة المكرّرة لأن الموديل الإجرائي يشارك
  /// بعض المواد بين عدة أجزاء، ولو مزجناها لكل جزء لتضاعف اللون.
  void _applyTint(three.Object3D root, int? tint) {
    if (tint == null) return;
    final target = three.Color(tint);
    final done = <three.Material>{};
    root.traverse((node) {
      if (node is! three.Mesh) return;
      final raw = node.material;
      if (raw is List) {
        for (final mat in raw) {
          if (mat is three.Material && done.add(mat)) {
            _tintMaterial(mat, target);
          }
        }
      } else if (raw is three.Material && done.add(raw)) {
        _tintMaterial(raw, target);
      }
    });
  }

  void _tintMaterial(three.Material mat, three.Color tint) {
    // اللون هنا يُضرب في صورة الخامة، فالمادة البيضاء تُظهر الصورة كما هي.
    // 0.8 كان مناسبًا للموديلات الإجرائية المسطّحة، لكنه على نخيل الـGLB يمحو
    // الخامة: سعف المرتبة ٢ يخرج نعناعيًا والثالثة ليمونيًا. 0.45 يعطي صبغة
    // واضحة مع بقاء تفاصيل السعف والجذع، والوهج يتولّى بقية الإحساس بالترقية.
    mat.color.lerp(tint, 0.45);
    final emissive = mat.emissive;
    if (emissive != null) emissive.lerp(tint, 0.18);
    mat.needsUpdate = true;
  }

  /// يبني الطفل الإجرائي بمقاسات المرحلة والتكبير واللون.
  three.Object3D _buildModelChild(_AnimatedModel model) {
    final child = _fallbackForType(model.type, tier: model.tier);
    if (hasTierModels(model.type)) {
      final height = modelInstanceHeight(
        model.tier,
        model.stage,
        model.scaleMultiplier,
      );
      fitModelToGround(
        child,
        height,
        sink: _groundSinkOf(model.type, model.tier, height),
      );
    } else {
      child.scale.multiplyScalar(model.scaleMultiplier);
    }
    _applyTint(child, model.tint);
    return child;
  }

  /// مقياس الزينة الأرضية (الظل والكومة) بالنسبة لارتفاع النموذج.
  double _stageScaleOf(
    RewardType type,
    int tier,
    double multiplier, [
    int stage = 0,
  ]) {
    return hasTierModels(type)
        ? (modelInstanceHeight(tier, stage, multiplier) / 3.0).clamp(0.35, 3.0)
        : (1.0 + (tier - 1) * 0.08) * multiplier;
  }

  void _refreshGroundDressing(_AnimatedModel model) {
    final stageScale = _stageScaleOf(
      model.type,
      model.tier,
      model.scaleMultiplier,
      model.stage,
    );
    model.shadowChild?.scale.set(stageScale, stageScale, 1);
    model.moundChild?.scale.set(stageScale, 0.18, stageScale);
    final ring = model.decorRing;
    if (ring != null) {
      final r = 1.0 + stageScale * 0.55;
      ring.scale.set(r, r, 1);
    }
  }

  /// يحدّث موديلًا قائمًا بعد تغيّر مرحلته، دون حذف الغرسة وإعادة زرعها.
  void _restyleModel(_AnimatedModel model) {
    model.revision++;
    _refreshGroundDressing(model);

    final existing = model.modelChild;
    // إزالة التلوين لا يمكن أن تتم على نفس المادة (اللون تراكمي)، فنعيد بناء
    // الطفل ونطلب الـGLB من جديد بدل الاكتفاء بإعادة القياس.
    final clearingTint = model.tint == null && model.appliedTint != null;
    if (!clearingTint &&
        model.glbActive &&
        existing != null &&
        model.glbTier == model.tier) {
      // نفس ملف الـGLB: يكفي إعادة ضبط الارتفاع (وقد يتغيّر التكبير وحده).
      // نفصله لحظة القياس لأن `Box3` يقيس في إحداثيات العالم، والمجموعة
      // الأم موضوعة على الأرض في مكانها.
      final parent = existing.parent;
      parent?.remove(existing);
      final height = modelInstanceHeight(
        model.tier,
        model.stage,
        model.scaleMultiplier,
      );
      fitModelToGround(
        existing,
        height,
        sink: _groundSinkOf(model.type, model.tier, height),
      );
      parent?.add(existing);
      // قد يتغيّر اللون داخل التير نفسه (المرحلة ١ ← ٢)، فنطبّقه مرة واحدة.
      if (model.appliedTint != model.tint) {
        _applyTint(existing, model.tint);
        model.appliedTint = model.tint;
      }
      return;
    }

    final child = _buildModelChild(model);
    if (existing != null) model.mesh.remove(existing);
    model.mesh.add(child);
    model.modelChild = child;
    model.glbActive = false;
    model.glbTier = 0;
    if (hasTierModels(model.type)) _enqueueUpgrade(model);
  }

  three.Vector3? addModelAt({
    RewardType type = RewardType.palmTree,
    int tier = 1,
    int stage = 0,
    double scaleMultiplier = 1.0,
    int? tint,
    double? x,
    double? z,
    double? y,
    bool persist = true,
    bool ignoreCap = false,
    bool reveal = false,
    bool isDecor = false,
    int? expiresAt,
    bool track = true,
    _SavedEntry? savedEntry,
  }) {
    if (_animatedModels.length >= _kMaxSceneModels && !ignoreCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🌟 بلغت جنتك أوج نضارتها وازدهارها!',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Color(0xFF1B5E20),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }

    final calculatedPos = (x == null || z == null)
        ? (reveal ? _nextPlantPosForType(type) : _nextSpawnPosForType(type))
        : three.Vector3(x, y ?? _calculateGroundElevation(x, z), z);

    final group = three.Group();
    group.position.set(calculatedPos.x, calculatedPos.y, calculatedPos.z);
    group.rotation.y = three.Math.randFloat(0, three.Math.pi * 2);

    final model = _AnimatedModel(
      group,
      DateTime.now().millisecondsSinceEpoch,
      type,
      tier: tier,
      stage: stage,
      scaleMultiplier: scaleMultiplier,
      tint: tint,
      isDecor: isDecor,
      expiresAt: expiresAt,
    );

    // البديل الإجرائي يظهر فورًا، ثم يُستبدل بالـGLB عند وصوله. كلاهما
    // مضبوط على نفس الارتفاع، فلا يحدث انكماش مفاجئ.
    final procedural = _buildModelChild(model);
    group.add(procedural);
    model.modelChild = procedural;
    model.appliedTint = tint;

    // مقاسات الظل والكومة تتبع المرحلة بدل ثباتها: كومة بعرض ١٫٣ تحت شجرة
    // ارتفاعها ١٫٢ تجعل الشتلة تبدو غارقة في جبل تراب.
    final stageScale = _stageScaleOf(type, tier, scaleMultiplier, stage);

    // 1. Soft Dark Contact Shadow Decal on the ground
    final shadowRadius =
        (type == RewardType.palace || type == RewardType.mosque)
        ? 4.5
        : (type == RewardType.house
              ? 2.5
              : (type == RewardType.treasure ? 1.4 : 1.8));
    final shadowMat = three.MeshBasicMaterial({
      "color": 0x061F12,
      "transparent": true,
      "opacity": 0.42,
      "side": three.DoubleSide,
    });
    final shadowDecal = three.Mesh(
      three.CircleGeometry(radius: shadowRadius, segments: 14),
      shadowMat,
    );
    shadowDecal.rotation.x = -three.Math.pi / 2;
    shadowDecal.position.y = 0.02;
    shadowDecal.scale.set(stageScale, stageScale, 1);
    group.add(shadowDecal);
    model.shadowChild = shadowDecal;

    // 2. Earthen Root Mound for Trees and Palms
    if (type == RewardType.tree || type == RewardType.palmTree) {
      // مادة واحدة مشتركة: كل موديل كان يخصّص مادة خاصة بالكومة، أي ١٢٠ مادة
      // متطابقة في مشهد مملوء. المشاركة تجعل تحديث الخامة مرة واحدة يكفي.
      _moundMat ??= three.MeshPhongMaterial({
        "color": 0x7C8A64,
        "emissive": 0x0B1208,
        "shininess": 6,
        "flatShading": false,
      });
      final soilMound = three.Mesh(three.DodecahedronGeometry(0.65), _moundMat);
      soilMound.scale.set(stageScale, 0.18, stageScale);
      soilMound.position.y = 0.04;
      group.add(soilMound);
      model.moundChild = soilMound;
    }

    // 3. حلقة ذهبية خفيفة: علامة الزينة المؤقتة الوحيدة (لا نغيّر لون
    //    الموديل نفسه حتى لا يختلط بالنماذج الدائمة).
    if (isDecor) {
      final ring = three.Mesh(
        three.TorusGeometry(1, 0.055, 6, 40),
        three.MeshBasicMaterial({
          "color": 0xFFD54F,
          "transparent": true,
          "opacity": 0.5,
          "blending": three.AdditiveBlending,
          "depthWrite": false,
        }),
      );
      ring.rotation.x = -three.Math.pi / 2;
      ring.position.y = 0.05;
      final r = 1.0 + stageScale * 0.55;
      ring.scale.set(r, r, 1);
      group.add(ring);
      model.decorRing = ring;
    }

    _scene.add(group);
    _animatedModels.add(model);

    // السجل يُنشأ دائمًا (حتى للنماذج المحمّلة) كي تراه دوال التباعد
    // و`_writeSaved`؛ `persist` يتحكم بالكتابة فقط. النماذج العرضية (`track:
    // false`) لا سجل لها أصلًا، فلا تتسرّب إلى الحفظ عند أول كتابة لاحقة.
    if (track) {
      final entry =
          savedEntry ??
          _SavedEntry(
            type,
            calculatedPos.x,
            calculatedPos.y,
            calculatedPos.z,
            tier: tier,
            stage: stage,
            isDecor: isDecor,
            expiresAt: expiresAt,
          );
      if (!_savedEntries.contains(entry)) _savedEntries.add(entry);
      model.entry = entry;
    }

    // The procedural mesh above is what appears immediately; the staged GLB is
    // swapped in asynchronously once it parses, so a slow device never waits on
    // the model before the garden grows.
    if (hasTierModels(type)) _enqueueUpgrade(model);

    if (isDecor && track) _sessionDecor.add(model);
    if (persist) _writeSaved();

    // الغرسة اليدوية وحدها تُحرّك الكاميرا: المزامنة والاسترجاع لا يقفزان
    // بالمستخدم إلى مكان آخر.
    if (reveal) _revealPlant(calculatedPos);
    return calculatedPos;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 13),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// الضغطة العادية: آخر زينة أُضيفت في هذه الجلسة (وليست مكافأة دائمة).
  void _undoLastDecor() {
    while (_sessionDecor.isNotEmpty) {
      final model = _sessionDecor.last;
      if (!_animatedModels.contains(model)) {
        _sessionDecor.removeLast();
        continue;
      }
      _removeModel(model);
      _writeSaved();
      setState(() {});
      return;
    }
    _toast('لا توجد زينة جديدة في هذه الجلسة');
  }

  /// الضغط المطوّل: حذف آخر مكافأة نهائيًا من السجل وخصمها من عدّاد الذكر.
  Future<void> _confirmPermanentUndo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D2818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0x55FFD700)),
          ),
          title: const Text(
            'تراجع دائم',
            style: TextStyle(fontSize: 20, color: Color(0xFFFFD700)),
          ),
          content: const Text(
            'سيُحذف آخر ذكر من سجل المكافآت، وتُخصم واحدة من عدّاد الذكر '
            'المرتبط به. لا يمكن التراجع عن هذه الخطوة.',
            style: TextStyle(fontSize: 13, height: 1.6, color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'احذف',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final removed = await _storage.removeLastReward();
    if (removed == null) {
      _toast('لا توجد مكافآت للتراجع عنها');
      return;
    }
    final count = _storage.getDhikrCount(removed.dhikrId);
    if (count > 0) {
      await _storage.saveDhikrCount(removed.dhikrId, count - 1);
    }
    _applyEvolution();
    _toast('حُذفت آخر مكافأة (${removed.type.displayName}) نهائيًا');
  }

  void _resetCamera() {
    _camera.position.set(_kHomeX, _kHomeY, _kHomeZ);
    _controls.target.set(_kHomeTargetX, _kHomeTargetY, _kHomeTargetZ);
    _camera.lookAt(_controls.target);
    _controls.update();
  }

  /// يُربط بمصدر أحداث المشهد ([DomLikeListenable]) — نفس المصدر الذي يحرّك
  /// الكاميرا. يُستدعى مرة واحدة فقط؛ التكرار محمي بالعلم.
  void _bindScenePointer() {
    if (_scenePointerBound) return;
    final state = _globalKey.currentState;
    if (state == null) return;
    _scenePointerBound = true;
    debugPrint('👆 scene pointer bound');

    state.addEventListener('pointerdown', (dynamic e) {
      final id = (e.pointerId as num).toInt();
      final down = Offset(
        (e.clientX as num).toDouble(),
        (e.clientY as num).toDouble(),
      );
      // إصبع ثالث، أو مؤشر سابق لم يصل حدث رفعه: ابدأ إيماءة نظيفة بدل أن
      // تبقى الحالة عالقة على إصبعين لا وجود لهما.
      if (_scenePointers.length >= 2 && !_scenePointers.containsKey(id)) {
        _scenePointers.clear();
        _endTwoFinger();
      }
      _scenePointers[id] = down;
      _sceneTapDown = down;
      _sceneTapDownMs = DateTime.now().millisecondsSinceEpoch;
      if (_scenePointers.length == 2) _beginTwoFinger();
    });

    state.addEventListener('pointermove', (dynamic e) {
      final id = (e.pointerId as num).toInt();
      if (!_scenePointers.containsKey(id)) return;
      _scenePointers[id] = Offset(
        (e.clientX as num).toDouble(),
        (e.clientY as num).toDouble(),
      );
      _moveTwoFinger();
    });

    state.addEventListener('pointerup', (dynamic e) {
      final id = (e.pointerId as num).toInt();
      final wasTwoFinger = _twoFingerTouched;
      _scenePointers.remove(id);
      if (_scenePointers.length < 2) _endTwoFinger();
      if (_scenePointers.isEmpty) _twoFingerTouched = false;

      final down = _sceneTapDown;
      _sceneTapDown = null;
      if (down == null) return;
      final up = Offset(
        (e.clientX as num).toDouble(),
        (e.clientY as num).toDouble(),
      );
      // الإيماءة بإصبعين ليست لمسة فحص، حتى لو رُفعت الأصابع بسرعة.
      if (wasTwoFinger) return;
      final elapsed = DateTime.now().millisecondsSinceEpoch - _sceneTapDownMs;
      // السحبة تدير الكاميرا، فلا تُفتح بها بطاقة.
      if (elapsed > 450 || (up - down).distance > 14) return;
      _handleSceneTap(up);
    });
  }

  Offset? _twoFingerMidpoint() {
    if (_scenePointers.length < 2) return null;
    final points = _scenePointers.values.take(2).toList(growable: false);
    return (points[0] + points[1]) / 2;
  }

  void _beginTwoFinger() {
    _twoFingerTouched = true;
    _twoFingerMid = _twoFingerMidpoint();
    _twoFingerAccum = Offset.zero;
    _twoFingerMode = _kTwoFingerUndecided;
  }

  void _endTwoFinger() {
    _twoFingerMid = null;
    _twoFingerAccum = Offset.zero;
    _twoFingerMode = _kTwoFingerUndecided;
  }

  /// إصبعان: يمين/شمال يدوّر، أعلى/أسفل يقرّب ويبعد.
  ///
  /// `OrbitControls` لا يعرف هذا التمييز: `DOLLY_ROTATE` يدوّر بأي اتجاه،
  /// ويقرّب فقط عند تغيّر المسافة بين الإصبعين. لذلك عُطّل `TWO` في `initPage`
  /// وتولّينا الإيماءة هنا. الاتجاه يُقفل بعد أول ١٢ بكسل حتى لا تهتز الكاميرا
  /// بين الدوران والتقريب في السحبة المائلة.
  void _moveTwoFinger() {
    final mid = _twoFingerMidpoint();
    if (mid == null) return;
    final last = _twoFingerMid;
    _twoFingerMid = mid;
    if (last == null) return;
    final delta = mid - last;

    if (_twoFingerMode == _kTwoFingerUndecided) {
      _twoFingerAccum += delta;
      if (_twoFingerAccum.distance < 12) return;
      _twoFingerMode = _twoFingerAccum.dx.abs() >= _twoFingerAccum.dy.abs()
          ? _kTwoFingerRotate
          : _kTwoFingerZoom;
    }

    if (_twoFingerMode == _kTwoFingerRotate) {
      final viewportHeight = _controls.domElement.clientHeight;
      if (viewportHeight <= 0) return;
      _controls.rotateLeft(
        2 * pi * delta.dx / viewportHeight * _controls.rotateSpeed,
      );
      return;
    }

    // سحب لأعلى (dy سالب) يقرّب، ولأسفل يبعد. ١٨ بكسل ≈ خطوة عجلة واحدة.
    final step = pow(0.95, -delta.dy / 18).toDouble();
    if (step < 1) {
      _controls.dollyIn(step);
    } else {
      _controls.dollyOut(1 / step);
    }
  }

  /// لمسة على المشهد: شعاع من الكاميرا عبر نقطة اللمس، وأول موديل يصيبه
  /// يفتح بطاقته. نتسلّق من الجسم المصاب إلى جذر الغرسة، فتصلح الظلال
  /// وأكوام التراب كأهداف لمس أيضًا.
  ///
  /// البطاقة تُرسم داخل المشهد لا كـ bottom sheet: الفتح من حدث المؤشر
  /// كان يُغلق الشيت في نفس النقرة (نقرة المتصفح التالية تصيب الحاجز)،
  /// وبطاقة داخلية أيضًا أقرب لروح «فحص الموديل».
  void _handleSceneTap(Offset local) {
    if (_animatedModels.isEmpty || _width <= 0 || _height <= 0) return;

    final ray = three.Raycaster();
    ray.setFromCamera(
      three.Vector2((local.dx / _width) * 2 - 1, -(local.dy / _height) * 2 + 1),
      _camera,
    );

    // نجمع الـMeshes نفسها ونمرّرها بلا تكرار: `intersectObjects(roots, true)`
    // يمرّ على كل Group في ثلاثي الأبعاد، و`Object3D.raycast` يطبع
    // «Object3D raycast todo» لكل واحد منها — مئات الأسطر في كل لمسة.
    final targets = <three.Object3D>[];
    final owner = <three.Object3D, _AnimatedModel>{};
    for (final m in _animatedModels) {
      m.mesh.traverse((child) {
        if (child is three.Mesh) {
          targets.add(child);
          owner[child] = m;
        }
      });
    }

    for (final hit in ray.intersectObjects(targets, false)) {
      final m = owner[hit.object];
      if (m != null) {
        debugPrint('🎯 Model tapped: ${m.type.name} (Tier ${m.tier})');
        setState(() {
          _inspectedType = m.type;
          _inspectedTier = m.tier;
          _inspectedStage = m.stage;
          _inspectedIsDecor = m.isDecor;
          _inspectedExpiresAt = m.expiresAt;
        });
        return;
      }
    }

    // لمسة على أرض فارغة تطوي البطاقة.
    if (_inspectedType != null) setState(() => _inspectedType = null);
  }

  /// بطاقة زجاجية صغيرة تصف الغرسة الملموسة: النوع، مرتبة النماء، وعدد
  /// المكافآت وراءها.
  Widget _buildInspectCard({
    required RewardType type,
    required int tier,
    required int stage,
    required bool isDecor,
    int? expiresAt,
  }) {
    final earned = _earnedByType[type] ?? 0;
    final permanent = _animatedModels
        .where((m) => m.type == type && !m.isDecor)
        .length;
    final decor = _animatedModels
        .where((m) => m.type == type && m.isDecor)
        .length;

    final stageLabel = switch (stage) {
      1 => 'تكبير',
      2 => 'تكبير وَلون',
      _ => 'الفسلة الأساسية',
    };
    final hoursLeft = expiresAt == null
        ? 0
        : ((expiresAt - DateTime.now().millisecondsSinceEpoch) / 3600000)
              .ceil()
              .clamp(0, 24);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -10),
          child: child,
        ),
      ),
      child: GestureDetector(
        // يبتلع اللمسة كي لا تصل إلى الكانفس تحته.
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2818).withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          GardenAssets.getIconAsset(type),
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.displayName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                              Text(
                                isDecor
                                    ? 'زينة مؤقتة · المرتبة '
                                          '${NumberFormatter.toArabic(tier)}'
                                    : 'مرتبة النمو · المستوى '
                                          '${NumberFormatter.toArabic(tier)}'
                                          ' · $stageLabel',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _inspectedType = null),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white54,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isDecor)
                      _buildInspectStat(
                        'متبقٍ من الزينة',
                        hoursLeft == 0
                            ? 'انتهت'
                            : '${NumberFormatter.toArabic(hoursLeft)} ساعة',
                      )
                    else
                      Row(
                        children: [
                          _buildInspectStat(
                            'إجمالي المكافآت',
                            NumberFormatter.toArabic(earned),
                          ),
                          const SizedBox(width: 16),
                          _buildInspectStat(
                            'في هذا المشهد',
                            NumberFormatter.toArabic(permanent),
                          ),
                          const SizedBox(width: 16),
                          _buildInspectStat(
                            'زينة',
                            NumberFormatter.toArabic(decor),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInspectStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white54),
        ),
      ],
    );
  }

  /// بطاقة المكافأة. تُفتح من شريط الفلاتر بعد اختيار النوع ثانيًا.
  void _showRewardInfoModal(RewardType type, {int? tier, int? count}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final total = count ?? (_earnedByType[type] ?? 0);
        final level = tier ?? modelTierForCount(total);
        final stage = modelStageForCount(total);
        final stageLabel = switch (stage) {
          1 => 'تكبير',
          2 => 'تكبير وَلون',
          _ => 'الفسلة الأساسية',
        };
        final decorCount = _animatedModels
            .where((m) => m.type == type && m.isDecor)
            .length;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2818).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Image.asset(
                      GardenAssets.getIconAsset(type),
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${type.displayName} في رياض الجنة',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                          Text(
                            'مرتبة النمو: المستوى '
                            '${NumberFormatter.toArabic(level)} · $stageLabel',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoStat(
                        'إجمالي المكافآت',
                        NumberFormatter.toArabic(total),
                      ),
                      _buildInfoStat(
                        'في المشهد 3D',
                        NumberFormatter.toArabic(
                          _animatedModels
                              .where((m) => m.type == type && !m.isDecor)
                              .length,
                        ),
                      ),
                      _buildInfoStat(
                        'زينة',
                        NumberFormatter.toArabic(decorCount),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoStat(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFD700),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget scene = Builder(
      builder: (BuildContext context) {
        initSize(context);
        return _buildSceneWithOverlay(context);
      },
    );

    // كتبويب داخل الرئيسية: الرئيسية تملك الـScaffold والشريط السفلي، فإدخال
    // Scaffold آخر يضيف طبقة Material ويغيّر insets بلا داعٍ.
    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFF071B12), child: scene);
    }

    return Scaffold(backgroundColor: const Color(0xFF071B12), body: scene);
  }

  Widget _buildSceneWithOverlay(BuildContext context) {
    if (!_three3dRender.isInitialized) {
      return Container(
        color: const Color(0xFF071B12),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFD700)),
              SizedBox(height: 16),
              Text(
                '🌿 جارٍ فتح أبواب جنتك النورانية...',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 18, color: Color(0xFFFFD700)),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final currentW = constraints.maxWidth;
        final currentH = constraints.maxHeight;
        _onResize(currentW, currentH);

        return Stack(
          children: [
            // 3D Canvas
            SizedBox(
              width: currentW,
              height: currentH,
              child: three_jsm.DomLikeListenable(
                key: _globalKey,
                builder: (BuildContext context) {
                  return Container(
                    width: currentW,
                    height: currentH,
                    color: const Color(0xFF071B12),
                    child: Builder(
                      builder: (BuildContext context) {
                        if (kIsWeb) {
                          return HtmlElementView(
                            viewType: _three3dRender.textureId!.toString(),
                          );
                        } else {
                          return Texture(textureId: _three3dRender.textureId!);
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            // Top Glassmorphic HUD
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _buildTopGlassBar(),
                ),
              ),
            ),

            // 🧾 بطاقة فحص الموديل — تنزل من تحت الشريط العلوي
            if (_inspectedType != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 88, 16, 0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _buildInspectCard(
                        type: _inspectedType!,
                        tier: _inspectedTier,
                        stage: _inspectedStage,
                        isDecor: _inspectedIsDecor,
                        expiresAt: _inspectedExpiresAt,
                      ),
                    ),
                  ),
                ),
              ),

            // 🌅 Day Phase Switcher (فجر / ظهيرة / ليل)
            SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildLightModePill(),
                ),
              ),
            ),

            // Bottom Controls & Filter Pills
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: _buildBottomGlassPanel(),
                ),
              ),
            ),

            // 🚪 حاجب أول إقلاع: يغطي المشهد والحواف حتى تكتمل آخر شبكة/بلاطة.
            if (!_sceneReady)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF071B12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFFFD700),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '🌿 جارٍ فتح أبواب جنتك النورانية...',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        if (_assetsTotal > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${NumberFormatter.toArabic(_assetsDone)} / '
                            '${NumberFormatter.toArabic(_assetsTotal)}',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 🌅 زر إضاءة اليوم: تلقائي (يتبع الساعة) ← فجر ← ظهيرة ← ليل.
  Widget _buildLightModePill() {
    final DayLightMode mode = _lightMode;
    final double hour = _currentHour();
    final IconData icon = mode.isAuto ? modeAtHour(hour).icon : mode.icon;
    final Color accent = mode.isAuto ? modeAtHour(hour).accent : mode.accent;
    final String label = mode.isAuto ? 'تلقائي' : mode.label;
    final String? subLabel = mode.isAuto ? periodLabelAtHour(hour) : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
        onTap: _cycleLightMode,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2818).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: accent),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 1),
                Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: accent.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopGlassBar() {
    final permanent = _animatedModels.where((m) => !m.isDecor).length;
    final decor = _animatedModels.where((m) => m.isDecor).length;
    final rewards = _earnedByType.values.fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2818).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 18,
              ),
              onPressed: () {
                if (widget.embedded) {
                  widget.onExit?.call();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'جنتي',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  Text(
                    '${NumberFormatter.toArabic(rewards)} مكافأة · '
                    '${NumberFormatter.toArabic(permanent)} غرسة · '
                    '${NumberFormatter.toArabic(decor)} زينة',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _soundEnabled
                  ? 'كتم الأجواء الروحانية'
                  : 'تشغيل الأجواء الروحانية',
              icon: Icon(
                _soundEnabled ? Icons.volume_up : Icons.volume_off,
                color: _soundEnabled ? const Color(0xFFFFD700) : Colors.white54,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _soundEnabled = !_soundEnabled;
                  SpiritualAudioService().toggle();
                });
              },
            ),
            IconButton(
              tooltip: _autoRotate ? 'إيقاف الدوران' : 'تشغيل الدوران',
              icon: Icon(
                _autoRotate ? Icons.sync : Icons.sync_disabled,
                color: _autoRotate ? const Color(0xFFFFD700) : Colors.white54,
                size: 20,
              ),
              onPressed: () => setState(() => _autoRotate = !_autoRotate),
            ),
            IconButton(
              tooltip: 'إعادة ضبط المنظور الآيزومتري',
              icon: const Icon(
                Icons.center_focus_strong,
                color: Color(0xFFFFD700),
                size: 20,
              ),
              onPressed: _resetCamera,
            ),
            IconButton(
              tooltip: 'حقن تجريبي (مؤقت)',
              icon: const Icon(
                Icons.science,
                color: Color(0xFF80CBC4),
                size: 20,
              ),
              onPressed: _openDebugInjector,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomGlassPanel() {
    final decorCount = _animatedModels.where((m) => m.isDecor).length;
    final decorHours = (_decorRemaining.inMinutes / 60).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Category Pills
        SizedBox(
          height: 42,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: RewardType.values.map((type) {
                final count = _earnedByType[type] ?? 0;
                final isSelected = _selectedFilter == type;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFilter = isSelected ? null : type;
                      });
                      if (isSelected) {
                        _showRewardInfoModal(type);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                            : const Color(0xFF0D2818).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : const Color(0xFFFFD700).withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            GardenAssets.getIconAsset(type),
                            width: 18,
                            height: 18,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${type.displayName} (${NumberFormatter.toArabic(count)})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFFFFD700)
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Action Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2818).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _plantSingleDecor,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'اغرس زينة',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: const Color(0xFFFFD700),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _decorCycleActive ? null : _plantDecorSet,
                  icon: Icon(
                    Icons.auto_awesome,
                    size: 15,
                    color: _decorCycleActive
                        ? Colors.white38
                        : const Color(0xFFFFD700),
                  ),
                  label: Text(
                    _decorCycleActive
                        ? 'الزينة ${NumberFormatter.toArabic(decorHours)}س'
                        : 'زينة ٢٤س',
                    style: TextStyle(
                      fontSize: 12,
                      color: _decorCycleActive
                          ? Colors.white38
                          : const Color(0xFFFFD700),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: const Color(
                        0xFFFFD700,
                      ).withValues(alpha: _decorCycleActive ? 0.15 : 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_animatedModels.isNotEmpty)
                  Tooltip(
                    message:
                        'ضغطة: آخر زينة في الجلسة\nضغط مطوّل: حذف آخر مكافأة نهائيًا',
                    child: InkWell(
                      onTap: _undoLastDecor,
                      onLongPress: _confirmPermanentUndo,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.undo,
                              size: 16,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'تراجع',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                InkWell(
                  onTap: _openDecorBoard,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: Color(0xFFFFD54F),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'زينة الجنة (${NumberFormatter.toArabic(decorCount)})',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFFFD54F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// صياغة الوقت المتبقي للزينة بصيغة قصيرة («٣ س ١٢ د» أو «٤٥ د»).
  String _formatDecorLeft(Duration left) {
    final h = left.inHours;
    final m = left.inMinutes % 60;
    if (h > 0) {
      return '${NumberFormatter.toArabic(h)} س ${NumberFormatter.toArabic(m)} د';
    }
    return '${NumberFormatter.toArabic(m)} د';
  }

  /// يزيل الزينة الترحيبية (بلا انتهاء) للنوع قبل زرع زينة حقيقية مكانها،
  /// حتى لا يظهر نوعان من نفس الموديل في نفس الوقت.
  void _dropWelcomeDecorOf(RewardType type) {
    final welcome = _animatedModels
        .where((m) => m.isDecor && m.type == type && m.expiresAt == null)
        .toList();
    for (final m in welcome) {
      _removeModel(m);
    }
  }

  /// يغرس زينة واحدة من النوع المحدد بمرتبة ومرحلة عشوائية لمدة ٢٤ ساعة.
  /// النوع الواحد لا يُكرَّر قبل انتهاء دورته.
  void _plantSingleDecor() {
    final type = _selectedFilter ?? RewardType.palmTree;
    final active = _activeDecorOf(type);
    if (active != null) {
      final left = DateTime.fromMillisecondsSinceEpoch(
        active.expiresAt!,
      ).difference(DateTime.now());
      _toast(
        'زينة ${type.displayName} مزروعة بالفعل · باقي ${_formatDecorLeft(left)}',
      );
      return;
    }

    _dropWelcomeDecorOf(type);
    final tier = 1 + _rng.nextInt(5);
    final stage = _rng.nextInt(3);
    final pos = addModelAt(
      type: type,
      tier: tier,
      stage: stage,
      scaleMultiplier: modelScaleForStage(tier, stage),
      tint: modelTintForStage(tier, stage),
      isDecor: true,
      expiresAt: DateTime.now().add(_kDecorLifetime).millisecondsSinceEpoch,
      reveal: true,
    );
    if (pos == null) return;
    setState(() {});
    _toast(
      'زينة ${type.displayName} لمدة ٢٤ ساعة · المرتبة '
      '${NumberFormatter.toArabic(tier)}',
    );
  }

  /// يمنح زينة الدورة: نموذج واحد لكل نوع بمرحلة عشوائية، لمدة ٢٤ ساعة.
  /// يملأ الأنواع الناقصة فقط، فلا يكرر نوعًا ما زال مزروعًا.
  void _plantDecorSet() {
    final missing = RewardType.values
        .where((t) => !_decorActiveFor(t))
        .toList();
    if (missing.isEmpty) {
      _toast('كل الأنواع لديها زينة نشطة — انتظر انتهاء المؤقت');
      return;
    }
    final expiresAt = DateTime.now()
        .add(_kDecorLifetime)
        .millisecondsSinceEpoch;
    var added = 0;
    for (final type in missing) {
      _dropWelcomeDecorOf(type);
      final tier = 1 + _rng.nextInt(5);
      final stage = _rng.nextInt(3);
      final pos = addModelAt(
        type: type,
        tier: tier,
        stage: stage,
        scaleMultiplier: modelScaleForStage(tier, stage),
        tint: modelTintForStage(tier, stage),
        isDecor: true,
        expiresAt: expiresAt,
        persist: false,
      );
      if (pos != null) added++;
    }
    if (added == 0) return;
    _writeSaved();
    setState(() {});
    _toast('وُزّعت ${NumberFormatter.toArabic(added)} زينة لمدة ٢٤ ساعة');
  }

  /// حالة كل نوع كما تعرضها لوحة الزينة (تُقرأ لحظيًا كل ثانية).
  _DecorSlot _decorSlotOf(RewardType type) {
    final m = _activeDecorOf(type);
    return _DecorSlot(
      type: type,
      tier: m?.tier,
      stage: m?.stage,
      expiresAt: m?.expiresAt,
    );
  }

  void _openDecorBoard() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DecorBoard(
        slots: () => [for (final t in RewardType.values) _decorSlotOf(t)],
        onPlant: (type) {
          _selectedFilter = type;
          _plantSingleDecor();
        },
        onPlantAll: _plantDecorSet,
      ),
    );
  }

  /// عتبات التجربة: كل زر يضبط العدد على «العتبة − ١» ليرى المستخدم ما قبل
  /// الارتقاء مباشرة. أزرار مؤقتة تُحذف قبل الإصدار.
  static const List<int> _kDebugThresholds = <int>[
    9,
    24,
    99,
    199,
    499,
    999,
    1999,
    2999,
    4999,
    5999,
    7999,
    9999,
  ];

  void _openDebugInjector() {
    var type = _selectedFilter ?? RewardType.palmTree;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final current = _earnedByType[type] ?? 0;
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2818).withValues(alpha: 0.97),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: const Color(0x55FFD700)),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.science,
                            color: Color(0xFF80CBC4),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'حقن تجريبي (مؤقت)',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${type.displayName} · العدد الحالي: '
                        '${NumberFormatter.toArabic(current)} مكافأة',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: RewardType.values.map((t) {
                          final selected = t == type;
                          return ChoiceChip(
                            label: Text(
                              t.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: selected
                                    ? const Color(0xFFFFD700)
                                    : Colors.white70,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) => setSheet(() => type = t),
                            selectedColor: const Color(
                              0xFFFFD700,
                            ).withValues(alpha: 0.2),
                            backgroundColor: Colors.black26,
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFFFFD700)
                                  : Colors.white24,
                            ),
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'اضغط رقمًا لضبط العدد على العتبة − ١:',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _kDebugThresholds.map((n) {
                          return OutlinedButton(
                            onPressed: () async {
                              await _setRewardCount(type, n);
                              setSheet(() {});
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFD54F),
                              side: const BorderSide(color: Color(0x55FFD700)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: const Size(48, 32),
                            ),
                            child: Text(
                              NumberFormatter.toArabic(n),
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _addOneReward(type);
                                setSheet(() {});
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                '+١ مكافأة',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: const Color(0xFFFFD700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _clearAllRewards();
                                setSheet(() {});
                              },
                              icon: const Icon(Icons.delete_sweep, size: 16),
                              label: const Text(
                                'مسح الكل',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(
                                  color: Color(0x55FF5252),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'هذه الأزرار تُحذف قبل الإصدار، ولا تمسّ عدّادات الأذكار.',
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _setRewardCount(RewardType type, int count) async {
    final all = _storage.getAllRewards();
    all.removeWhere((r) => r.type == type);
    final now = DateTime.now();
    final stamp = now.microsecondsSinceEpoch;
    for (var i = 0; i < count; i++) {
      all.add(
        Reward(
          id: '${stamp}_${type.name}_$i',
          type: type,
          posX: 0.5,
          posY: 0.5,
          earnedAt: now,
          dhikrId: 'debug',
        ),
      );
    }
    await _storage.saveRewards(all);
    _applyEvolution();
    _toast('${type.displayName}: ${NumberFormatter.toArabic(count)} مكافأة');
  }

  Future<void> _addOneReward(RewardType type) async {
    final all = _storage.getAllRewards();
    final now = DateTime.now();
    all.add(
      Reward(
        id: '${now.microsecondsSinceEpoch}_${type.name}',
        type: type,
        posX: 0.5,
        posY: 0.5,
        earnedAt: now,
        dhikrId: 'debug',
      ),
    );
    await _storage.saveRewards(all);
    _applyEvolution();
  }

  Future<void> _clearAllRewards() async {
    await _storage.saveRewards([]);
    await _storage.saveRewards3D([]);
    for (final m in List<_AnimatedModel>.of(_animatedModels)) {
      _scene.remove(m.mesh);
    }
    _animatedModels.clear();
    _savedEntries.clear();
    _sessionDecor.clear();
    _earnedByType.clear();
    if (mounted) setState(() {});
    _toast('مُسحت بيانات الاختبار من المشهد والسجل');
  }

  void render() {
    final gl = _three3dRender.gl;
    final now = DateTime.now().millisecondsSinceEpoch;
    _frameCount++;

    // 0. تحليق الكاميرا إلى غرسة غُرست خارج الكادر. الهدف والكاميرا يُزاحان
    //    بنفس المقدار، فتبقى المسافة والاتجاه كما هما وينتقل النظر وحده.
    if (_flyTarget != null &&
        _flyOriginTarget != null &&
        _flyCameraFrom != null) {
      final t = ((now - _flyStartMs) / _kFlyMs).clamp(0.0, 1.0);
      final double ease = t < 0.5
          ? 2 * t * t
          : 1 - 2 * (1 - t) * (1 - t); // easeInOutQuad
      final from = _flyOriginTarget!;
      final to = _flyTarget!;
      final cam = _flyCameraFrom!;
      final dx = (to.x - from.x) * ease;
      final dy = (to.y - from.y) * ease;
      final dz = (to.z - from.z) * ease;
      _controls.target.set(from.x + dx, from.y + dy, from.z + dz);
      _camera.position.set(cam.x + dx, cam.y + dy, cam.z + dz);
      _camera.lookAt(_controls.target);
      if (t >= 1.0) {
        _flyTarget = null;
        _flyOriginTarget = null;
        _flyCameraFrom = null;
      }
    }

    // 1. Model Growth Animation
    for (final am in _animatedModels) {
      final elapsed = now - am.bornAt;
      final t = (elapsed / 620.0).clamp(0.0, 1.0);
      // نمو مرن (easeOutBack): يتجاوز الحجم النهائي قليلًا ثم يستقر عليه،
      // فيبدو كأن الغرسة «تنبت» بدل أن تتمدد بخط مستقيم.
      const c1 = 1.70158;
      const c3 = c1 + 1.0;
      final u = t - 1.0;
      final eased = 1.0 + c3 * u * u * u + c1 * u * u;
      final s = 0.2 + eased * 0.8;
      am.mesh.scale.set(s, s, s);

      // حلقة الزينة تدور ببطء حول الغرسة، فتظل علامة حيّة بلا ضجيج.
      final ring = am.decorRing;
      if (ring != null) ring.rotation.z += 0.004;
    }

    // 2. Clouds Drifting
    for (int i = 0; i < _clouds.length; i++) {
      final cloud = _clouds[i];
      cloud.position.x += 0.035 * (1 + (i % 2) * 0.4);
      if (cloud.position.x > 300) {
        cloud.position.x = -300;
      }
    }

    // 3. Fluttering Falling Leaves & Petals in the Wind
    for (int l = 0; l < _fallingLeavesGroup.children.length; l++) {
      if (l < _leafVelocities.length) {
        final leaf = _fallingLeavesGroup.children[l];
        final vel = _leafVelocities[l];
        leaf.position.x += vel.x;
        leaf.position.y += vel.y + 0.008 * sin(_frameCount * 0.06 + l);
        leaf.position.z += vel.z;

        leaf.rotation.x += 0.03;
        leaf.rotation.y += 0.02;
        leaf.rotation.z += 0.015;

        // Reset if it hits ground or bounds
        if (leaf.position.y < 0.2 ||
            leaf.position.x > 80 ||
            leaf.position.z > 60) {
          leaf.position.set(
            -70 + _rng.nextDouble() * 40.0,
            18.0 + _rng.nextDouble() * 12.0,
            -50 + _rng.nextDouble() * 40.0,
          );
        }
      }
    }

    // 4. Floating Light Particles
    for (int i = 0; i < _particlesGroup.children.length; i++) {
      if (i < _particleInitialY.length && i < _particleSpeeds.length) {
        final p = _particlesGroup.children[i];
        final initY = _particleInitialY[i];
        final speed = _particleSpeeds[i];
        p.position.y = initY + sin(_frameCount * speed + i) * 1.5;
        p.position.x += 0.01 * sin(_frameCount * 0.02 + i);
      }
    }

    // 5. White Doves Flapping
    for (int b = 0; b < _birdsGroup.children.length; b++) {
      final bird = _birdsGroup.children[b];
      bird.position.x += 0.07;
      bird.position.z += 0.03 * sin(_frameCount * 0.03 + b);
      if (bird.position.x > 140) bird.position.x = -140;

      if (bird.children.length >= 2) {
        final flap = sin(_frameCount * 0.25 + b) * 0.4;
        bird.children[0].rotation.z = flap;
        bird.children[1].rotation.z = -flap;
      }
    }

    // 6. 🌅 دورة إضاءة اليوم: انسياب التبديل اليدوي، أو تحديث تلقائي مُخفَّف
    //    (كل [kAutoRefreshFrames] إطارًا ≈ نصف ثانية — بلا فرق بصري وكلفة ~صفر)
    if (_tweenTo != null) {
      _advanceTransition();
    } else if (_lightMode.isAuto && _frameCount % kAutoRefreshFrames == 0) {
      _applySpec(_targetSpec());
    }

    // 7. Starfield Twinkle (يتلألأ كلما ظهرت النجوم)
    if (_starBaseOpacity > 0.0 && _starMat != null) {
      final double pulse =
          starField.twinkleBase +
          starField.twinkleAmplitude *
              sin(_frameCount * starField.twinkleSpeed);
      _starMat!.opacity = _starBaseOpacity * pulse;
      _starHaloMat?.opacity =
          _starBaseOpacity * starField.haloOpacityRatio * pulse;
    }

    // 8. وميض الترقية الذهبي
    for (var i = _goldBursts.length - 1; i >= 0; i--) {
      final burst = _goldBursts[i];
      final t = (now - burst.bornAt) / 1400.0;
      if (t >= 1.0) {
        _scene.remove(burst.group);
        _goldBursts.removeAt(i);
        continue;
      }
      for (var k = 0; k < burst.group.children.length; k++) {
        final particle = burst.group.children[k];
        final v = burst.velocities[k];
        particle.position.x += v.x;
        particle.position.y += v.y;
        particle.position.z += v.z;
        // جذب خفيف يُبطئ الصعود، وتباعد يمنع التكتل في خط واحد.
        v.y -= 0.004;
        v.x *= 0.985;
        v.z *= 0.985;
      }
      final fade = 1.0 - t;
      burst.material.opacity = 0.95 * fade * fade;
    }

    _renderer!.render(_scene, _camera);
    gl.flush();
    if (!kIsWeb) {
      _three3dRender.updateTexture(_sourceTexture);
    }
  }

  void initRenderer() {
    Map<String, dynamic> options = {
      "width": _width,
      "height": _height,
      "gl": _three3dRender.gl,
      "antialias": true,
      "canvas": _three3dRender.element,
    };
    _renderer = three.WebGLRenderer(options);
    _renderer!.setPixelRatio(_dpr);
    _renderer!.setSize(_width, _height, false);
    _renderer!.shadowMap.enabled = false;

    if (!kIsWeb) {
      var pars = three.WebGLRenderTargetOptions({
        "minFilter": three.LinearFilter,
        "magFilter": three.LinearFilter,
        "format": three.RGBAFormat,
      });
      _renderTarget = three.WebGLRenderTarget(
        (_width * _dpr).toInt(),
        (_height * _dpr).toInt(),
        pars,
      );
      _renderTarget.samples = 4;
      _renderer!.setRenderTarget(_renderTarget);
      _sourceTexture = _renderer!.getRenderTargetGLTexture(_renderTarget);
    }
  }

  void initScene() {
    initRenderer();
    initPage();
  }

  void initPage() {
    _scene = three.Scene();
    // كائنان ثابتان تُعدَّل قيمهما مع دورة اليوم (بلا إعادة إنشاء)
    _bgColor = three.Color(0x134C37);
    _scene.background = _bgColor;
    // الضباب كان يبدأ عند ١٥٠ لحجب حدّ الأرض المسطّحة. الأرض الآن جزيرة
    // والحدّ هو ما نريد رؤيته: عند ١٥٠ كان نصف الجزيرة البعيد يذوب في لون
    // الخلفية نفسه، فيختفي الجرف وتُقرأ الجزيرة بقعة خضراء. ٤٠٠ تُبقي الحافة
    // واضحة من كادر الافتتاح، و١٠٠٠ تترك الجزر الطافية عند أقصى تصغير (٣٤٠)
    // شبه صافية.
    _fog = three.Fog(0x134C37, 400, 1000);
    _scene.fog = _fog;

    // نصف قطر رؤية أوسع: الرأسي ٥٦ على الهاتف حتى لا يضيق الكادر، والأفقي ٤٤
    // على سطح المكتب — نفس قاعدة [_onResize] حتى لا يتغيّر الكادر عند أول إطار.
    final double fov = _width < _height ? 56.0 : 44.0;
    _camera = three.PerspectiveCamera(fov, _width / _height, 0.1, 1000);
    _camera.position.set(_kHomeX, _kHomeY, _kHomeZ);
    _camera.lookAt(three.Vector3(_kHomeTargetX, _kHomeTargetY, _kHomeTargetZ));

    _controls = three_jsm.OrbitControls(_camera, _globalKey);
    _controls.enableDamping = true;
    _controls.dampingFactor = 0.06;
    _controls.minDistance = 18;
    _controls.maxDistance = 340;
    // ٨٥° تقريبًا: تسمح بالنزول إلى مستوى الأرض تقريبًا بدل التوقف عند ٧٢°.
    _controls.maxPolarAngle = 1.483;
    _controls.panSpeed = 1.0;
    _controls.screenSpacePanning = true;
    _controls.rotateSpeed = 0.7;
    // السحب الأساسي (فأرة يسار / إصبع واحد) = تحريك، لا دوران حول نقطة ثابتة.
    // التدوير يبقى على الفأرة اليمنى، وإيماءة الإصبعين تُعالج في
    // `_moveTwoFinger`: يمين/شمال دوران، أعلى/أسفل تقريب وإبعاد. لذلك لا نُعطي
    // OrbitControls خريطة TWO، وإلا دوّر بأي اتجاه ونافس معالجتنا.
    _controls.mouseButtons = {
      'LEFT': three.MOUSE.PAN,
      'MIDDLE': three.MOUSE.DOLLY,
      'RIGHT': three.MOUSE.ROTATE,
    };
    _controls.touches = {'ONE': three.TOUCH.PAN};
    _controls.target.set(_kHomeTargetX, _kHomeTargetY, _kHomeTargetZ);

    // مصادر الإضاءة — تُنشأ مرة واحدة (بقيم الظهيرة الأصلية) ثم تُعدَّل قيمها
    // مع دورة اليوم في [_applySpec] بلا حذف/إضافة.
    _ambientLight = three.AmbientLight(0x4A6B56, 0.55);
    _scene.add(_ambientLight!);

    _sunLight = three.DirectionalLight(0xFFE082, 1.35);
    _sunLight!.position.set(55, 90, 45);
    _scene.add(_sunLight!);

    _fillLight = three.DirectionalLight(0x388E3C, 0.40);
    _fillLight!.position.set(-50, 30, -40);
    _scene.add(_fillLight!);

    // ارتداد السحاب: من الأسفل إلى الأعلى، بارد، فلا يلمس المرج (يواجه السماء)
    // ويُظهر حصى الجرف الذي يقع ظلّه في الجهة المقابلة للشمس.
    _underLight = three.DirectionalLight(0x9DB2C4, 0.62);
    _underLight!.position.set(26, -70, 44);
    _scene.add(_underLight!);
    _underLightB = three.DirectionalLight(0x9DB2C4, 0.62);
    _underLightB!.position.set(-30, -70, -46);
    _scene.add(_underLightB!);

    _buildAtmosphere();
    _buildSculptedTerrain();
    // شبكة أمان: أصل معلّق (شبكة بطيئة أو ملف مفقود) لا يحقّ له حجب الجنة.
    Future.delayed(const Duration(seconds: 25), () {
      if (!_sceneReady && !_disposed) {
        debugPrint('⚠️ scene gate timeout: $_assetsDone/$_assetsTotal');
        _markSceneReady();
      }
    });
    if (_assetsTotal == 0) _markSceneReady();
    _buildLightParticlesAndWildlife();

    // 🌅 إضاءة اللحظة الحالية (تلقائي حسب ساعة الجهاز، أو وضع ثابت محفوظ)
    _applySpec(_targetSpec());

    final saved = List<_SavedEntry>.of(_savedEntries);
    _savedEntries.clear();
    for (final e in saved) {
      addModelAt(
        type: e.type,
        tier: e.tier,
        stage: e.stage,
        scaleMultiplier: modelScaleForStage(e.tier, e.stage),
        tint: modelTintForStage(e.tier, e.stage),
        x: e.x,
        z: e.z,
        y: e.y,
        isDecor: e.isDecor,
        expiresAt: e.expiresAt,
        persist: false,
        ignoreCap: true,
        savedEntry: e,
      );
    }

    // السلّم هو مصدر الحقيقة: عدد المكافآت يحدد ما يُعرض الآن.
    _applyEvolution(notify: false);

    // أول فتح فقط: ثلاث غرسات عرضية بدل حديقة فارغة. ليست مكافآت ولا تُحفظ
    // كدائمة، وتُعامل كزينة حتى لا تختلط بعدّاد النماء. بلا انتهاء حتى لا
    // تحجب دورة الزينة الأولى.
    if (_animatedModels.isEmpty) {
      for (final type in [
        RewardType.palmTree,
        RewardType.tree,
        RewardType.treasure,
      ]) {
        addModelAt(
          type: type,
          tier: 1,
          isDecor: true,
          persist: false,
          track: false,
        );
      }
    }

    _loaded = true;
    setState(() {});
    // بعد أول إطار يكون [DomLikeListenable] قد بُني، فتصبح أحداثه متاحة.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindScenePointer());
    animate();
  }

  void animate() {
    if (!mounted || _disposed) return;

    if (_loaded) {
      // الربط ينتظر بناء [DomLikeListenable]؛ نُعيد المحاولة حتى ينجح بدل
      // الاعتماد على توقيت إطار واحد.
      if (!_scenePointerBound) _bindScenePointer();
      if (_autoRotate && !_isFlying) {
        _controls.autoRotate = true;
        _controls.autoRotateSpeed = 0.4;
      } else {
        // التدوير التلقائي يدور حول الهدف، فلا يجوز أن يعمل أثناء التحليق
        // إلى غرسة جديدة وإلا انحرف مسار الكاميرا.
        _controls.autoRotate = false;
      }
      // 2. حدود ناعمة لنقطة النظر قبل حساب الأوربت: تمنع السحب الطولي من
      //    رفع الكاميرا إلى السحب أو قذف النظر خارج حدود الجنة.
      final t = _controls.target;
      t.x = t.x.clamp(_kPanMinX, _kPanMaxX).toDouble();
      t.y = t.y.clamp(_kPanMinY, _kPanMaxY).toDouble();
      t.z = t.z.clamp(_kPanMinZ, _kPanMaxZ).toDouble();
      _controls.update();
      render();
    }

    Future.delayed(const Duration(milliseconds: 16), animate);
  }

  @override
  void dispose() {
    _disposed = true;
    _glbCache.clear();
    _periodTicker?.cancel();
    _decorTicker?.cancel();
    _clock.stop();
    _three3dRender.dispose();
    super.dispose();
  }
}

/// مقعد زينة نوع واحد: مرحلته العشوائية ووقت انتهائه.
class _DecorSlot {
  const _DecorSlot({required this.type, this.tier, this.stage, this.expiresAt});

  final RewardType type;
  final int? tier;
  final int? stage;
  final int? expiresAt;

  bool get planted => expiresAt != null;
}

/// لوحة «زينة الجنة»: صف لكل نوع، بمرتبته ومرحلته العشوائية ومؤقت تنازلي
/// حتى انتهاء الـ٢٤ ساعة. المؤقت هنا لا يعتمد على تحديث الشاشة الأم، بل
/// يعيد بناء نفسه كل ثانية.
class _DecorBoard extends StatefulWidget {
  const _DecorBoard({
    required this.slots,
    required this.onPlant,
    required this.onPlantAll,
  });

  final List<_DecorSlot> Function() slots;
  final void Function(RewardType type) onPlant;
  final VoidCallback onPlantAll;

  @override
  State<_DecorBoard> createState() => _DecorBoardState();
}

class _DecorBoardState extends State<_DecorBoard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _countdown(int? expiresAt) {
    if (expiresAt == null) return '—';
    final left = expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) return 'انتهت';
    final d = Duration(milliseconds: left);
    String two(int v) => NumberFormatter.toArabic(v).padLeft(2, '٠');
    return '${NumberFormatter.toArabic(d.inHours)}:'
        '${two(d.inMinutes % 60)}:'
        '${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final slots = widget.slots();
    final planted = slots.where((s) => s.planted).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D2818).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Color(0xFFFFD700),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'زينة الجنة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                          Text(
                            '٢٤ ساعة · عنصر واحد لكل نوع · '
                            '${NumberFormatter.toArabic(planted)} من '
                            '${NumberFormatter.toArabic(RewardType.values.length)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white54),
                      iconSize: 20,
                    ),
                  ],
                ),
                Divider(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  height: 18,
                ),
                for (final slot in slots)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Image.asset(
                          GardenAssets.getIconAsset(slot.type),
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot.type.displayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                slot.planted
                                    ? 'المرتبة '
                                          '${NumberFormatter.toArabic(slot.tier ?? 0)}'
                                          ' · المرحلة '
                                          '${NumberFormatter.toArabic(slot.stage ?? 0)}'
                                    : 'غير مزروعة',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: slot.planted
                                      ? const Color(0xFFFFD54F)
                                      : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: slot.planted ? 0.35 : 0.1),
                            ),
                          ),
                          child: Text(
                            _countdown(slot.expiresAt),
                            style: TextStyle(
                              fontSize: 11,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: slot.planted
                                  ? const Color(0xFFFFD700)
                                  : Colors.white24,
                            ),
                          ),
                        ),
                        if (!slot.planted)
                          TextButton(
                            onPressed: () => widget.onPlant(slot.type),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFFD700),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(44, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'اغرس',
                              style: TextStyle(fontSize: 11),
                            ),
                          )
                        else
                          const SizedBox(width: 44),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: planted == RewardType.values.length
                        ? null
                        : widget.onPlantAll,
                    icon: Icon(
                      Icons.auto_awesome,
                      size: 15,
                      color: planted == RewardType.values.length
                          ? Colors.white38
                          : const Color(0xFFFFD700),
                    ),
                    label: Text(
                      planted == RewardType.values.length
                          ? 'كل الأنواع مزروعة'
                          : 'أكمل الأنواع الناقصة',
                      style: TextStyle(
                        fontSize: 12,
                        color: planted == RewardType.values.length
                            ? Colors.white38
                            : const Color(0xFFFFD700),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: const Color(0xFFFFD700).withValues(
                          alpha: planted == RewardType.values.length
                              ? 0.15
                              : 0.45,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
