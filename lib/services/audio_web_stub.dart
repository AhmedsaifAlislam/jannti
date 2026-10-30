// Web stub: does nothing on non-web platforms
void playSoundWeb(String key, String url, bool loop, double volume) {}
void stopSoundWeb(String key) {}
void stopAllWeb() {}
void setVolumeWeb(String key, double volume) {}
bool isPausedWeb(String key) => true;
double currentVolumeWeb(String key) => 0.0;
