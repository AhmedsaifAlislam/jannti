package com.example.jannti

import android.content.Intent
import android.net.Uri
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.jannti/audio"
    private val TAG = "JannatiAudio"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val url = call.argument<String>("url")
                    val isStream = call.argument<Boolean>("isStream") ?: false
                    val loop = call.argument<Boolean>("loop") ?: false
                    if (url != null) {
                        playUrl(url, isStream, loop)
                        result.success(true)
                    } else {
                        result.error("INVALID_URL", "URL cannot be null", null)
                    }
                }
                "stop" -> {
                    stopAudio()
                    result.success(true)
                }
                "pause" -> {
                    pauseAudio()
                    result.success(true)
                }
                "setVolume" -> {
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                    mediaPlayer?.setVolume(volume, volume)
                    result.success(true)
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (!url.isNullOrBlank()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Failed to open URL: $url", e)
                            result.error("OPEN_URL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL cannot be null or empty", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playUrl(url: String, isStream: Boolean, loop: Boolean = false) {
        try {
            Log.d(TAG, "▶️ Playing URL: $url (isStream=$isStream, loop=$loop)")
            stopAudio()

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build()
                )

                setDataSource(url)
                isLooping = loop

                setOnPreparedListener { mp ->
                    Log.d(TAG, "✅ MediaPlayer prepared, starting playback")
                    mp.start()
                }

                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "❌ MediaPlayer error: what=$what, extra=$extra, url=$url")
                    true
                }

                setOnBufferingUpdateListener { _, percent ->
                    if (percent % 25 == 0) {
                        Log.d(TAG, "📊 Buffering: $percent%")
                    }
                }

                setOnCompletionListener {
                    Log.d(TAG, "🏁 Playback completed for: $url")
                    if (!isStream) {
                        // Non-stream tracks: reset state when done
                    }
                }

                // Use prepareAsync for both streams and files to avoid blocking UI
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception playing audio: ${e.message}", e)
        }
    }

    private fun pauseAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.pause()
                    Log.d(TAG, "⏸️ Audio paused")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception pausing audio: ${e.message}", e)
        }
    }

    private fun stopAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.reset()
                it.release()
                Log.d(TAG, "⏹️ Audio stopped and released")
            }
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception stopping audio: ${e.message}", e)
            mediaPlayer = null
        }
    }

    override fun onDestroy() {
        stopAudio()
        super.onDestroy()
    }
}
