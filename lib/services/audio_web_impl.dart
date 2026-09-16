// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

html.AudioElement? _webAudioElement;

void playSoundWeb(String url, bool loop) {
  stopSoundWeb();
  final audio = html.AudioElement();
  audio.src = url;
  audio.loop = loop;
  audio.crossOrigin = 'anonymous';
  _webAudioElement = audio;
  audio.play();
}

void stopSoundWeb() {
  if (_webAudioElement != null) {
    _webAudioElement!.pause();
    _webAudioElement!.src = '';
    _webAudioElement = null;
  }
}

void setVolumeWeb(double volume) {
  _webAudioElement?.volume = volume.clamp(0.0, 1.0);
}

bool isWebAudioPaused() => _webAudioElement?.paused ?? true;
