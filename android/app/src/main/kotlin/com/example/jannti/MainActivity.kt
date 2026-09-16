package com.example.jannti

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Environment
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.jannti/audio"
    private val TAG = "JannatiAudio"
    private var mediaPlayer: MediaPlayer? = null

    // APK download tracking
    private var apkDownloadId: Long = -1L
    private var apkDownloadReceiver: BroadcastReceiver? = null

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
                            Log.e(TAG, "Failed to open URL: $url", e)
                            result.error("OPEN_URL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL cannot be null or empty", null)
                    }
                }
                "downloadAndInstallApk" -> {
                    val url = call.argument<String>("url")
                    if (!url.isNullOrBlank()) {
                        try {
                            downloadAndInstallApk(url)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to start APK download: $url", e)
                            result.error("DOWNLOAD_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "APK URL cannot be null or empty", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // --- In-app APK Download + Install ---

    private fun downloadAndInstallApk(url: String) {
        Log.d(TAG, "Starting APK download: $url")
        unregisterApkReceiver()

        val apkFile = File(
            getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
            "jannati_update.apk"
        )
        if (apkFile.exists()) apkFile.delete()

        val request = DownloadManager.Request(Uri.parse(url)).apply {
            setTitle("تحديث جنتي")
            setDescription("جار تنزيل التحديث...")
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            setDestinationUri(Uri.fromFile(apkFile))
            setAllowedOverMetered(true)
            setAllowedOverRoaming(true)
            setMimeType("application/vnd.android.package-archive")
        }

        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        apkDownloadId = dm.enqueue(request)
        Log.d(TAG, "APK download enqueued, id=$apkDownloadId")

        apkDownloadReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val id = intent?.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L) ?: -1L
                if (id != apkDownloadId) return

                val query = DownloadManager.Query().setFilterById(id)
                val cursor = dm.query(query)
                var success = false
                if (cursor.moveToFirst()) {
                    val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                    success = status == DownloadManager.STATUS_SUCCESSFUL
                }
                cursor.close()

                if (success) {
                    Log.d(TAG, "APK download complete, launching installer")
                    installApk(apkFile)
                } else {
                    Log.e(TAG, "APK download failed or cancelled")
                }
                unregisterApkReceiver()
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                apkDownloadReceiver,
                IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
                Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(
                apkDownloadReceiver,
                IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
            )
        }
    }

    private fun installApk(apkFile: File) {
        try {
            val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "${packageName}.fileprovider",
                    apkFile
                )
            } else {
                Uri.fromFile(apkFile)
            }

            val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                putExtra(Intent.EXTRA_RETURN_RESULT, true)
            }
            startActivity(installIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch APK installer: ${e.message}", e)
        }
    }

    private fun unregisterApkReceiver() {
        apkDownloadReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
            apkDownloadReceiver = null
        }
    }

    // --- Audio methods ---

    private fun playUrl(url: String, isStream: Boolean, loop: Boolean = false) {
        try {
            Log.d(TAG, "Playing URL: $url (isStream=$isStream, loop=$loop)")
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
                    Log.d(TAG, "MediaPlayer prepared, starting playback")
                    mp.start()
                }

                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra, url=$url")
                    true
                }

                setOnBufferingUpdateListener { _, percent ->
                    if (percent % 25 == 0) Log.d(TAG, "Buffering: $percent%")
                }

                setOnCompletionListener {
                    Log.d(TAG, "Playback completed for: $url")
                }

                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception playing audio: ${e.message}", e)
        }
    }

    private fun pauseAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.pause()
                    Log.d(TAG, "Audio paused")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception pausing audio: ${e.message}", e)
        }
    }

    private fun stopAudio() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.reset()
                it.release()
                Log.d(TAG, "Audio stopped and released")
            }
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Exception stopping audio: ${e.message}", e)
            mediaPlayer = null
        }
    }

    override fun onDestroy() {
        unregisterApkReceiver()
        stopAudio()
        super.onDestroy()
    }
}