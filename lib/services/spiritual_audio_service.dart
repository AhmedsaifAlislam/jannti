import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Conditional import: real web impl on web, stub on other platforms
import 'audio_web_stub.dart' if (dart.library.html) 'audio_web_impl.dart';
import 'storage_service.dart';

class AudioSegment {
  final String url;

  /// مدة المقطع بالمللي ثانية (نعرفها من الملف نفسه، فلا حاجة لسؤال المشغّل).
  final int durationMs;

  const AudioSegment({required this.url, required this.durationMs});
}

class AudioItem {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String url;
  final bool isStream;
  final bool loop;

  /// مقاطع تتناوب داخل الطبقة الواحدة مع تبادل ناعم.
  /// فارغة = مقطع واحد فقط (تُستخدم [url] كما هي).
  final List<AudioSegment> segments;

  const AudioItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.url,
    this.isStream = false,
    this.loop = false,
    this.segments = const <AudioSegment>[],
  });
}

/// 🎚️ مدير الصوت: مزج طبقات الطبيعة + تلاوات القرآن في قناة مستقلة.
///
/// قواعد المزيج:
/// - سقف المزيج = الجهارة ÷ √(عدد الطبقات) حتى لا يتجاوز الصوت الكلي الجهارة أبدًا.
/// - طبقة واحدة فقط (الرائدة) على السقف، والباقي على سلّم نسب عشوائي أدنى منه.
/// - كل ٢٠–٤٠ ثانية يتبادل الدور رائد جديد بانتقال ناعم ~٥ ثوانٍ.
/// - تذبذب خفيف عشوائي للطبقات غير الرائدة.
class SpiritualAudioService {
  static final SpiritualAudioService _instance =
      SpiritualAudioService._internal();
  factory SpiritualAudioService() => _instance;
  SpiritualAudioService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.example.jannti/audio',
  );

  /// مفتاح مشغّل القرآن (قناة مستقلة عن طبقات الطبيعة).
  static const String quranKey = 'quran';

  // =========================================================================
  // حالة المزيج
  // =========================================================================
  final Set<String> _layers = <String>{};
  final Map<String, double> _gain = <String, double>{};
  final Map<String, double> _target = <String, double>{};
  String? _leader;
  double _master = 0.5;
  bool _mixPlaying = false;

  Timer? _rotationTimer;
  Timer? _nudgeTimer;
  Timer? _rampTimer;

  final math.Random _rnd = math.Random();

  // =========================================================================
  // حالة تتابع المقاطع داخل كل طبقة
  //   - خانة ٠ تستخدم مفتاح الطبقة نفسه (توافق مع الواجهة والمشغّلات).
  //   - خانة ١ تستخدم مفتاحًا مشتقًّا `layer#1` وتُشغّل فقط أثناء التبادل.
  // =========================================================================
  /// مدة التبادل الناعم بين مقطعين متتاليين.
  static const int crossfadeMs = 6000;

  /// ساعة داخلية تتحرك مع نبضة المُنحدر (١٨٠ مللي) — حتمية في الاختبارات.
  int _clockMs = 0;

  /// فهرس المقطع الحالي لكل طبقة.
  final Map<String, int> _segIndex = <String, int>{};

  /// الخانة النشطة (٠ أو ١) لكل طبقة.
  final Map<String, int> _segSlot = <String, int>{};

  /// لحظة بدء المقطع الحالي (بالساعة الداخلية).
  final Map<String, int> _segStartedAt = <String, int>{};

  /// لحظة بدء التبادل — وجوده يعني أن تبادلًا جارٍ الآن.
  final Map<String, int> _fadeStartAt = <String, int>{};

  /// آخر جهارة أُرسلت لكل مشغّل (لتجنّب نداءات منصة زائدة).
  final Map<String, double> _appliedVolume = <String, double>{};

  /// يمنع تداخل نبضتين إذا تأخّر نداء المنصة.
  bool _ticking = false;

  static final Map<String, List<AudioSegment>> _segmentsById =
      <String, List<AudioSegment>>{
        for (final track in natureTracks) track.id: track.segments,
      };

  /// نبضة تُشعِر الواجهة بتغيّر مستويات الطبقات (لرسم المؤشرات فقط).
  final ValueNotifier<int> mixerTick = ValueNotifier<int>(0);

  // =========================================================================
  // حالة القرآن
  // =========================================================================
  String? _quranId;
  bool _quranPlaying = false;

  String? get quranId => _quranId;
  bool get isQuranPlaying => _quranPlaying;

  // =========================================================================
  // واجهة القراءة
  // =========================================================================
  bool get isMixPlaying => _mixPlaying && _layers.isNotEmpty;
  bool get isPlaying => isMixPlaying || _quranPlaying;

  Set<String> get activeLayers => Set<String>.unmodifiable(_layers);
  bool isLayerActive(String id) => _layers.contains(id);
  bool isLeader(String id) => _layers.length > 1 && _leader == id;
  double layerGain(String id) => _gain[id] ?? 0.0;

  /// سقف الجهارة الحالي (أعلى قيمة يمكن أن تصلها أي طبقة).
  double get mixCeiling => _ceiling;

  double get masterVolume => _master;

  /// يقرأ القيم المحفوظة (يُستدعى عند بدء الشاشات).
  void syncFromStorage() {
    _master = _savedVolume();
    if (_layers.isEmpty) {
      _layers.addAll(_savedLayers());
    }
    mixerTick.value++;
  }

  double _savedVolume() {
    try {
      return StorageService().getAudioVolume().clamp(0.0, 1.0).toDouble();
    } catch (_) {
      return _master;
    }
  }

  List<String> _savedLayers() {
    try {
      return StorageService()
          .getMixLayers()
          .where((id) => natureTracks.any((t) => t.id == id))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistLayers() async {
    try {
      await StorageService().setMixLayers(_layers.toList());
    } catch (e) {
      debugPrint('⚠️ persist mix layers: $e');
    }
  }

  // =========================================================================
  // 🌿 أصوات الطبيعة ورياض الجنة (تسجيلات طبيعية حقيقية 100% بدون موسيقى)
  //    كل طبقة قائمة مقاطع ٦٠ ثانية تتناوب بتبادل ناعم (٦ ثوانٍ)،
  //    والملفات محليّة في assets/audio/ وموحّدة الجهارة على -24 LUFS.
  //    المصادر: مكتبة أصوات Google (ريح الخلفية) + radio aporee ::: maps
  //    (ترخيص Public Domain).
  // =========================================================================
  static const List<AudioItem> natureTracks = [
    AudioItem(
      id: 'river_pure',
      title: 'خرير أنهار الفردوس 🌊',
      subtitle: 'ثلاثة جداول تتناوب بتبادل ناعم — ماء نقي بلا انقطاع',
      icon: '🌊',
      url: 'assets/audio/nature_water_a.ogg',
      isStream: false,
      loop: true,
      segments: [
        AudioSegment(url: 'assets/audio/nature_water_a.ogg', durationMs: 60000),
        AudioSegment(url: 'assets/audio/nature_water_b.ogg', durationMs: 60000),
        AudioSegment(url: 'assets/audio/nature_water_c.ogg', durationMs: 60000),
      ],
    ),
    AudioItem(
      id: 'leaves_pure',
      title: 'حفيف أشجار ورياح الجنان 🍃',
      subtitle: 'نسيم الغابة يتبدّل بين ثلاثة مشاهد بلا قطع',
      icon: '🍃',
      url: 'assets/audio/nature_wind.ogg',
      isStream: false,
      loop: true,
      segments: [
        AudioSegment(url: 'assets/audio/nature_wind.ogg', durationMs: 100000),
        AudioSegment(url: 'assets/audio/nature_wind_a.ogg', durationMs: 60000),
        AudioSegment(url: 'assets/audio/nature_wind_b.ogg', durationMs: 60000),
      ],
    ),
    AudioItem(
      id: 'birds_pure',
      title: 'تغريد عصافير الفجر والروضة 🕊️',
      subtitle: 'فجران طبيعيان يتعاقبان — تغريد حقيقي بلا موسيقى',
      icon: '🕊️',
      url: 'assets/audio/nature_birds_a.ogg',
      isStream: false,
      loop: true,
      segments: [
        AudioSegment(url: 'assets/audio/nature_birds_a.ogg', durationMs: 60000),
        AudioSegment(url: 'assets/audio/nature_birds_b.ogg', durationMs: 60000),
      ],
    ),
    AudioItem(
      id: 'night_pure',
      title: 'سكون ليل الطبيعة والتهجد 🌌',
      subtitle: 'ليلان طبيعيان يتناوبان — سكون يملأ القلب خشوعاً',
      icon: '🌌',
      url: 'assets/audio/nature_night.ogg',
      isStream: false,
      loop: true,
      segments: [
        AudioSegment(url: 'assets/audio/nature_night.ogg', durationMs: 45000),
        AudioSegment(url: 'assets/audio/nature_night_b.ogg', durationMs: 60000),
      ],
    ),
  ];

  // =========================================================================
  // 📖 تلاوات القرآن الكريم (mp3quran.net + qurango.net — مثبتة ومستقرة)
  // =========================================================================
  static const List<AudioItem> quranTracks = [
    AudioItem(
      id: 'radio_tartil',
      title: 'إذاعة تلاوات القرآن الكريم 📻',
      subtitle: 'بث مباشر متواصل لأجمل التلاوات الخاشعة',
      icon: '📻',
      url: 'https://backup.qurango.net/radio/tarateel',
      isStream: true,
      loop: false,
    ),
    AudioItem(
      id: 'surah_rahman',
      title: 'سورة الرحمن • وصف الجنان 🌿',
      subtitle: 'بصوت الشيخ مشاري العفاسي',
      icon: '🌿',
      url: 'https://server8.mp3quran.net/afs/055.mp3',
      loop: false,
    ),
    AudioItem(
      id: 'surah_waqiah',
      title: 'سورة الواقعة • أصحاب اليمين 🌴',
      subtitle: 'بصوت الشيخ مشاري العفاسي',
      icon: '🌴',
      url: 'https://server8.mp3quran.net/afs/056.mp3',
      loop: false,
    ),
    AudioItem(
      id: 'surah_insan',
      title: 'سورة الإنسان • عين السلسبيل 💎',
      subtitle: 'بصوت الشيخ مشاري العفاسي',
      icon: '💎',
      url: 'https://server8.mp3quran.net/afs/076.mp3',
      loop: false,
    ),
    AudioItem(
      id: 'surah_mulk',
      title: 'سورة الملك • المانعة 🛡️',
      subtitle: 'بصوت الشيخ مشاري العفاسي',
      icon: '🛡️',
      url: 'https://server8.mp3quran.net/afs/067.mp3',
      loop: false,
    ),
    AudioItem(
      id: 'surah_yasin',
      title: 'سورة يس • قلب القرآن ❤️',
      subtitle: 'بصوت الشيخ مشاري العفاسي',
      icon: '❤️',
      url: 'https://server8.mp3quran.net/afs/036.mp3',
      loop: false,
    ),
  ];

  // =========================================================================
  // المحرّك: السقف والسلّم والتبادل
  // =========================================================================

  /// نسبة خفض المزيج أثناء التلاوة حتى لا يتجاوز مجموعهما الجهارة.
  double get _duck => _quranPlaying ? 0.5 : 1.0;

  /// جهارة التلاوة (٩٢٪ من الجهارة تترك هامشًا آمنًا لطبقات الطبيعة).
  double get _quranGain => (_master * 0.92).clamp(0.0, 1.0).toDouble();

  double get _ceiling {
    final n = _layers.length;
    if (n <= 1) return (_master * _duck).clamp(0.0, 1.0).toDouble();
    return (_master * _duck / math.sqrt(n.toDouble()))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// نسب الطبقات غير الرائدة (أعلى من أدناها تضمن ترتيبًا واضحًا).
  static const List<double> _ladder = [0.72, 0.58, 0.45, 0.34];

  Future<void> toggleLayer(AudioItem item) async {
    _master = _savedVolume();
    if (_layers.contains(item.id)) {
      _layers.remove(item.id);
      _gain.remove(item.id);
      _target.remove(item.id);
      if (_leader == item.id) _leader = null;
      await _stopLayerPlayers(item.id);
      if (_layers.isEmpty) {
        await stopMix();
      } else {
        _rebalance(keepLeader: _leader != null);
        _scheduleTimers();
      }
    } else {
      _layers.add(item.id);
      _gain[item.id] = 0;
      _target[item.id] = 0;
      if (_mixPlaying) {
        await _startLayerSequence(item.id, 0);
        _rebalance(keepLeader: true);
        _scheduleTimers();
      } else {
        await startMix();
      }
    }
    await _persistLayers();
    mixerTick.value++;
  }

  Future<void> startMix() async {
    if (_layers.isEmpty) return;
    _master = _savedVolume();
    for (final track in natureTracks) {
      if (!_layers.contains(track.id)) continue;
      _gain[track.id] = 0;
      await _startLayerSequence(track.id, 0);
    }
    _mixPlaying = true;
    _rebalance();
    _scheduleTimers();
    mixerTick.value++;
  }

  Future<void> stopMix() async {
    final ids = _layers.toList();
    _mixPlaying = false;
    _cancelTimers();
    for (final id in ids) {
      await _stopLayerPlayers(id);
    }
    mixerTick.value++;
  }

  /// يضبط جهارة الماستر لكل شيء (المزيج + التلاوة).
  Future<void> setVolume(double volume, {bool persist = false}) async {
    _master = volume.clamp(0.0, 1.0).toDouble();
    try {
      // التلاوة تأخذ الجهارة كاملة
      if (kIsWeb) {
        setVolumeWeb(quranKey, _quranGain);
      } else {
        await _channel.invokeMethod('setVolume', {
          'id': quranKey,
          'volume': _quranGain,
        });
      }
      if (persist) {
        await StorageService().setAudioVolume(_master);
      }
    } catch (e) {
      debugPrint('⚠️ Audio setVolume error: $e');
    }
    // المزيج يُعاد توزيعه على السقف الجديد
    if (_layers.isNotEmpty) {
      _rebalance(keepLeader: _leader != null);
    }
    mixerTick.value++;
  }

  /// يوقف كل شيء (مؤقت السكون).
  Future<void> stop() async {
    await stopMix();
    await stopQuran();
  }

  // =========================================================================
  // القرآن (قناة مستقلة: يمكن أن يعمل مع طبقات الطبيعة)
  // =========================================================================

  Future<void> playAudioItem(AudioItem item) async {
    try {
      _master = _savedVolume();
      _quranId = item.id;
      if (kIsWeb) {
        playSoundWeb(quranKey, item.url, item.loop, _quranGain);
        await Future.delayed(const Duration(milliseconds: 300));
        _quranPlaying = !isPausedWeb(quranKey);
        if (_quranPlaying) {
          debugPrint('🎵 Web Audio playing: ${item.title} → ${item.url}');
        } else {
          debugPrint('⚠️ Web Audio paused or blocked: ${item.url}');
        }
      } else {
        await _channel.invokeMethod('play', {
          'id': quranKey,
          'url': item.url,
          'isStream': item.isStream,
          'loop': item.loop,
          'volume': _quranGain,
        });
        _quranPlaying = true;
        debugPrint('🎵 Native Audio playing: ${item.title}');
      }
      // خفض المزيج تحت التلاوة
      if (_layers.isNotEmpty) {
        _rebalance(keepLeader: _leader != null);
      }
    } catch (e) {
      debugPrint('⚠️ Audio play error: $e');
      _quranPlaying = false;
    }
    mixerTick.value++;
  }

  Future<void> toggleQuran(AudioItem item) async {
    if (_quranId == item.id && _quranPlaying) {
      await stopQuran();
    } else {
      await playAudioItem(item);
    }
  }

  Future<void> stopQuran() async {
    try {
      await _stopPlayer(quranKey);
      _quranId = null;
      _quranPlaying = false;
      if (_layers.isNotEmpty) {
        _rebalance(keepLeader: _leader != null);
      }
      debugPrint('🔇 Quran stopped');
    } catch (e) {
      debugPrint('⚠️ Audio stop error: $e');
    }
    mixerTick.value++;
  }

  /// زر الصوت في العالم ثلاثي الأبعاد: تشغيل/إيقاف المزيج.
  Future<void> toggle([AudioItem? item]) async {
    if (isMixPlaying) {
      await stopMix();
      return;
    }
    if (_layers.isEmpty) {
      syncFromStorage();
      if (_layers.isEmpty) {
        _layers.add((item ?? natureTracks.first).id);
      }
    }
    await startMix();
    await _persistLayers();
  }

  // =========================================================================
  // المشغّلات (ويب/أندرويد)
  // =========================================================================

  Future<void> _startPlayer(
    String key,
    String url,
    bool loop,
    double volume,
  ) async {
    _appliedVolume.remove(key);
    try {
      if (kIsWeb) {
        playSoundWeb(key, url, loop, volume);
      } else {
        await _channel.invokeMethod('play', {
          'id': key,
          'url': url,
          'isStream': false,
          'loop': loop,
          'volume': volume,
        });
      }
    } catch (e) {
      debugPrint('⚠️ start player $key: $e');
    }
  }

  Future<void> _stopPlayer(String key) async {
    _appliedVolume.remove(key);
    try {
      if (kIsWeb) {
        stopSoundWeb(key);
      } else {
        await _channel.invokeMethod('stop', {'id': key});
      }
    } catch (e) {
      debugPrint('⚠️ stop player $key: $e');
    }
  }

  void _applyGain(String key, double value) {
    final v = value.clamp(0.0, 1.0).toDouble();
    final last = _appliedVolume[key];
    // توفير نداءات المنصة: لا نرسل قيمة لم تتغير فعليًا.
    if (last != null && (last - v).abs() < 0.002) return;
    _appliedVolume[key] = v;
    try {
      if (kIsWeb) {
        setVolumeWeb(key, v);
      } else {
        _channel.invokeMethod('setVolume', {'id': key, 'volume': v});
      }
    } catch (e) {
      debugPrint('⚠️ gain $key: $e');
    }
  }

  // =========================================================================
  // تتابع المقاطع داخل الطبقة (تبادل ناعم)
  // =========================================================================

  /// مفتاح مشغّل خانة معيّنة داخل الطبقة.
  /// الخانة ٠ تستخدم معرّف الطبقة نفسه (يبقي الواجهة والاختبارات كما هي).
  static String _slotKey(String layerId, int slot) =>
      slot == 0 ? layerId : '$layerId#1';

  int _slotOf(String id) => _segSlot[id] ?? 0;

  /// يبدأ تتابع الطبقة من مقطعها الأول على الخانة ٠.
  Future<void> _startLayerSequence(String id, double volume) async {
    final segs = _segmentsById[id] ?? const <AudioSegment>[];
    _segIndex[id] = 0;
    _segSlot[id] = 0;
    _segStartedAt[id] = _clockMs;
    _fadeStartAt.remove(id);
    if (segs.isEmpty) {
      // احتياط: طبقة بلا مقاطع (لا يحدث مع natureTracks).
      return;
    }
    await _startPlayer(_slotKey(id, 0), segs.first.url, true, volume);
  }

  /// يوقف خانات الطبقة (أثناء التبادل تكون هناك خانتان).
  Future<void> _stopLayerPlayers(String id) async {
    _fadeStartAt.remove(id);
    _segStartedAt.remove(id);
    _segIndex.remove(id);
    _segSlot.remove(id);
    await _stopPlayer(_slotKey(id, 0));
    await _stopPlayer(_slotKey(id, 1));
  }

  /// يبدأ المقطع التالي على الخانة الأخرى من الصفر ثم يتقاطعان.
  Future<void> _beginCrossfade(String id) async {
    final segs = _segmentsById[id] ?? const <AudioSegment>[];
    if (segs.length < 2) return;
    final next = ((_segIndex[id] ?? 0) + 1) % segs.length;
    final newSlot = 1 - _slotOf(id);
    _segIndex[id] = next;
    _segSlot[id] = newSlot;
    _segStartedAt[id] = _clockMs;
    _fadeStartAt[id] = _clockMs;
    await _startPlayer(_slotKey(id, newSlot), segs[next].url, true, 0);
    _applyLayerVolume(id);
  }

  /// ينهي التبادل: يغلق الخانة الخارجة ويُبقي الداخلة.
  void _finishCrossfade(String id) {
    final slot = _slotOf(id);
    _fadeStartAt.remove(id);
    _stopPlayer(_slotKey(id, 1 - slot));
    _applyLayerVolume(id);
  }

  /// يوزّع جهارة الطبقة على خاناتها حسب منحنى التبادل.
  void _applyLayerVolume(String id) {
    final base = _gain[id] ?? 0.0;
    final slot = _slotOf(id);
    final fadeStart = _fadeStartAt[id];
    if (fadeStart == null) {
      _applyGain(_slotKey(id, slot), base);
      return;
    }
    final p = ((_clockMs - fadeStart) / crossfadeMs).clamp(0.0, 1.0).toDouble();
    _applyGain(_slotKey(id, slot), base * p);
    _applyGain(_slotKey(id, 1 - slot), base * (1 - p));
  }

  /// يفحص مواعيد التبديل لكل طبقة (يُستدعى مع كل نبضة).
  Future<bool> _advanceSequences() async {
    if (!_mixPlaying) return false;
    var changed = false;
    for (final id in _layers.toList()) {
      final segs = _segmentsById[id] ?? const <AudioSegment>[];
      if (segs.length < 2) continue;
      final fadeStart = _fadeStartAt[id];
      if (fadeStart == null) {
        final started = _segStartedAt[id] ?? _clockMs;
        final dur = segs[_segIndex[id] ?? 0].durationMs;
        final fadeAt = started + math.max(dur - crossfadeMs, 12000);
        if (_clockMs >= fadeAt) {
          await _beginCrossfade(id);
          changed = true;
        }
      } else if (_clockMs - fadeStart >= crossfadeMs) {
        _finishCrossfade(id);
        changed = true;
      }
    }
    return changed;
  }

  // =========================================================================
  // الخوارزمية
  // =========================================================================

  /// يعيد توزيع النسب: رائد على السقف، والباقي على سلّم أدنى.
  void _rebalance({bool keepLeader = false}) {
    if (_layers.isEmpty) {
      _leader = null;
      return;
    }
    final ids = _layers.toList();
    String leader;
    if (keepLeader && _leader != null && ids.contains(_leader)) {
      leader = _leader!;
    } else if (ids.length == 1) {
      leader = ids.first;
    } else {
      final pool = ids.where((id) => id != _leader).toList();
      leader = pool.isEmpty ? ids.first : pool[_rnd.nextInt(pool.length)];
    }

    final ceiling = _ceiling;
    final ratios = List<double>.from(_ladder)..shuffle(_rnd);
    _target[leader] = ceiling;
    var i = 0;
    for (final id in ids) {
      if (id == leader) continue;
      _target[id] = ceiling * ratios[i % ratios.length];
      i++;
    }
    _leader = leader;
  }

  void _scheduleTimers() {
    _ensureRamp();
    _scheduleRotation();
    _scheduleNudge();
  }

  void _cancelTimers() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _nudgeTimer?.cancel();
    _nudgeTimer = null;
    _rampTimer?.cancel();
    _rampTimer = null;
  }

  /// الانتقال الناعم: يقرّب الكسب الحقيقي من الهدف كل ١٨٠ مللي (~٥ ثوانٍ)،
  /// ويُدير في نفس النبضة تتابع المقاطع وتبادلها.
  void _ensureRamp() {
    _rampTimer ??= Timer.periodic(
      const Duration(milliseconds: 180),
      (_) => _onRampTick(),
    );
  }

  Future<void> _onRampTick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      _clockMs += 180;
      var moved = false;
      for (final id in _layers.toList()) {
        final current = _gain[id] ?? 0.0;
        final target = _target[id] ?? 0.0;
        if ((current - target).abs() < 0.005) {
          if (current != target) {
            _gain[id] = target;
            moved = true;
          }
          continue;
        }
        _gain[id] = current + (target - current) * 0.12;
        moved = true;
      }
      final sequenced = await _advanceSequences();
      for (final id in _layers.toList()) {
        _applyLayerVolume(id);
      }
      if (moved || sequenced) mixerTick.value++;
    } finally {
      _ticking = false;
    }
  }

  /// تبادل القيادة كل ٢٠–٤٠ ثانية.
  void _scheduleRotation() {
    _rotationTimer?.cancel();
    if (_layers.length < 2) return;
    final seconds = 20 + _rnd.nextInt(21);
    _rotationTimer = Timer(Duration(seconds: seconds), () {
      if (_layers.length < 2 || !_mixPlaying) return;
      _rebalance();
      mixerTick.value++;
      _scheduleRotation();
    });
  }

  /// تذبذب خفيف للطبقات غير الرائدة (بين ٣٠٪ و٩٠٪ من السقف).
  void _scheduleNudge() {
    _nudgeTimer?.cancel();
    if (_layers.length < 2) return;
    final seconds = 5 + _rnd.nextInt(5);
    _nudgeTimer = Timer(Duration(seconds: seconds), () {
      if (_layers.length < 2 || !_mixPlaying) return;
      final others = _layers.where((id) => id != _leader).toList();
      if (others.isNotEmpty) {
        final id = others[_rnd.nextInt(others.length)];
        final ceiling = _ceiling;
        final current = _target[id] ?? ceiling * 0.6;
        final delta = ceiling * 0.1 * (_rnd.nextBool() ? 1 : -1);
        _target[id] = (current + delta)
            .clamp(ceiling * 0.30, ceiling * 0.90)
            .toDouble();
      }
      _scheduleNudge();
    });
  }
}
