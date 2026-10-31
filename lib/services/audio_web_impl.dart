// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// مجموعة مشغّلات مستقلة: كل مفتاح (طبقة طبيعة أو قناة القرآن) له عنصره الخاص،
/// فيمكن تشغيل عدة أصوات معًا مع ضبط جهارة كل واحد على حدة.
final Map<String, html.AudioElement> _players = <String, html.AudioElement>{};

/// يحوّل مسار أصل محلي (مثل `assets/audio/nature_water_a.ogg`) إلى الرابط
/// الذي يخدمه Flutter Web فعليًا (`assets/assets/audio/nature_water_a.ogg`).
String _resolveSource(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return Uri.base.resolve('assets/$url').toString();
}

void playSoundWeb(String key, String url, bool loop, double volume) {
  stopSoundWeb(key);
  final audio = html.AudioElement();
  audio.src = _resolveSource(url);
  audio.loop = loop;
  audio.crossOrigin = 'anonymous';
  audio.volume = volume.clamp(0.0, 1.0).toDouble();
  _players[key] = audio;
  audio.play();
}

void stopSoundWeb(String key) {
  final audio = _players.remove(key);
  if (audio != null) {
    audio.pause();
    audio.src = '';
  }
}

void stopAllWeb() {
  for (final key in _players.keys.toList()) {
    stopSoundWeb(key);
  }
}

void setVolumeWeb(String key, double volume) {
  final audio = _players[key];
  if (audio != null) {
    audio.volume = volume.clamp(0.0, 1.0).toDouble();
  }
}

bool isPausedWeb(String key) => _players[key]?.paused ?? true;

double currentVolumeWeb(String key) =>
    (_players[key]?.volume ?? 0.0).toDouble();
