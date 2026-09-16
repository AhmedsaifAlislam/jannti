import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Conditional import: real web impl on web, stub on other platforms
import 'audio_web_stub.dart'
    if (dart.library.html) 'audio_web_impl.dart';

class AudioItem {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String url;
  final bool isStream;
  final bool loop;

  const AudioItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.url,
    this.isStream = false,
    this.loop = false,
  });
}

class SpiritualAudioService {
  static final SpiritualAudioService _instance = SpiritualAudioService._internal();
  factory SpiritualAudioService() => _instance;
  SpiritualAudioService._internal();

  static const MethodChannel _channel = MethodChannel('com.example.jannti/audio');

  bool _isPlaying = false;
  String? _currentAudioId;

  bool get isPlaying => _isPlaying;
  String? get currentAudioId => _currentAudioId;

  // =========================================================================
  // 🌿 أصوات الطبيعة ورياض الجنة (تسجيلات طبيعية حقيقية 100% بدون أي موسيقى أو آلات)
  // =========================================================================
  static const List<AudioItem> natureTracks = [
    AudioItem(
      id: 'river_pure',
      title: 'خرير أنهار الفردوس 🌊',
      subtitle: 'صوت ماء نقي طبيعي يتدفق في جدول عذب',
      icon: '🌊',
      url: 'https://actions.google.com/sounds/v1/water/water_running_by.ogg',
      isStream: false,
      loop: true,
    ),
    AudioItem(
      id: 'leaves_pure',
      title: 'حفيف أشجار ورياح الجنان 🍃',
      subtitle: 'صوت حفيف نسيم الرياح الحقيقي بين أوراق الشجر',
      icon: '🍃',
      url: 'https://actions.google.com/sounds/v1/weather/wind_in_leaves_on_porch.ogg',
      isStream: false,
      loop: true,
    ),
    AudioItem(
      id: 'birds_pure',
      title: 'تغريد عصافير الفجر والروضة 🕊️',
      subtitle: 'أصوات عصافير وطيور برية مغردة في الغابة',
      icon: '🕊️',
      url: 'https://actions.google.com/sounds/v1/animals/june_songbirds.ogg',
      isStream: false,
      loop: true,
    ),
    AudioItem(
      id: 'night_pure',
      title: 'سكون ليل الطبيعة والتهجد 🌌',
      subtitle: 'أجواء ليلية طبيعية هادئة تملأ القلب سكينة وخشوعاً',
      icon: '🌌',
      url: 'https://actions.google.com/sounds/v1/ambiences/night_crickets.ogg',
      isStream: false,
      loop: true,
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

  Future<void> playAudioItem(AudioItem item) async {
    try {
      _currentAudioId = item.id;

      if (kIsWeb) {
        // ✅ تشغيل HTML5 Audio حقيقي في المتصفح عبر conditional import
        playSoundWeb(item.url, item.loop);
        // نعطي المتصفح 300ms ثم نتحقق من الحالة الفعلية
        await Future.delayed(const Duration(milliseconds: 300));
        _isPlaying = !isWebAudioPaused();
        if (_isPlaying) {
          debugPrint('🎵 Web Audio playing: ${item.title} → ${item.url}');
        } else {
          debugPrint('⚠️ Web Audio paused or blocked after play(): ${item.url}');
        }
      } else {
        // ✅ تشغيل عبر MethodChannel على أندرويد
        await _channel.invokeMethod('play', {
          'url': item.url,
          'isStream': item.isStream,
          'loop': item.loop,
        });
        _isPlaying = true;
        debugPrint('🎵 Native Audio playing: ${item.title}');
      }
    } catch (e) {
      debugPrint('⚠️ Audio play error: $e');
      _isPlaying = false;
    }
  }

  Future<void> toggle([AudioItem? item]) async {
    final target = item ?? natureTracks.first;
    if (_currentAudioId == target.id && _isPlaying) {
      await stop();
    } else {
      await playAudioItem(target);
    }
  }

  Future<void> stop() async {
    try {
      if (kIsWeb) {
        stopSoundWeb();
      } else {
        await _channel.invokeMethod('stop');
      }
      _isPlaying = false;
      _currentAudioId = null;
      debugPrint('🔇 Audio stopped');
    } catch (e) {
      debugPrint('⚠️ Audio stop error: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      if (kIsWeb) {
        setVolumeWeb(volume.clamp(0.0, 1.0));
      } else {
        await _channel.invokeMethod('setVolume', {
          'volume': volume.clamp(0.0, 1.0),
        });
      }
    } catch (e) {
      debugPrint('⚠️ Audio setVolume error: $e');
    }
  }
}
