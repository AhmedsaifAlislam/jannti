package com.example.jannti

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.content.res.AssetFileDescriptor
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
    // مشغّل مستقل لكل طبقة صوتية (طبقات الطبيعة + قناة القرآن) حتى تعمل معًا.
    private val players = mutableMapOf<String, MediaPlayer>()
    private val assetDescriptors = mutableMapOf<String, AssetFileDescriptor>()

    // APK download tracking
    private var apkDownloadId: Long = -1L
    private var apkDownloadReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val id = call.argument<String>("id") ?: "main"
                    val url = call.argument<String>("url")
                    val isStream = call.argument<Boolean>("isStream") ?: false
                    val loop = call.argument<Boolean>("loop") ?: false
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                    if (url != null) {
                        playUrl(id, url, isStream, loop, volume)
                        result.success(true)
                    } else {
                        result.error("INVALID_URL", "URL cannot be null", null)
                    }
                }
                "stop" -> {
                    val id = call.argument<String>("id")
                    if (id != null) stopAudio(id) else stopAllAudio()
                    result.success(true)
                }
                "pause" -> {
                    pauseAudio()
                    result.success(true)
                }
                "setVolume" -> {
                    val id = call.argument<String>("id")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                    if (id != null) {
                        players[id]?.setVolume(volume, volume)
                    } else {
                        players.values.forEach { it.setVolume(volume, volume) }
                    }
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

    private fun playUrl(
        id: String,
        url: String,
        isStream: Boolean,
        loop: Boolean = false,
        volume: Float = 1.0f
    ) {
        try {
            Log.d(TAG, "Playing [$id]: $url (isStream=$isStream, loop=$loop, vol=$volume)")
            stopAudio(id)

            val player = MediaPlayer()
            players[id] = player
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )

            if (url.startsWith("http://") || url.startsWith("https://")) {
                player.setDataSource(url)
            } else {
                // أصل صوتي محلي داخل التطبيق (Flutter assets)
                val afd = assets.openFd("flutter_assets/$url")
                assetDescriptors[id] = afd
                player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            }
            player.isLooping = loop
            player.setVolume(volume, volume)

            player.setOnPreparedListener { mp ->
                Log.d(TAG, "MediaPlayer [$id] prepared, starting playback")
                mp.start()
            }

            player.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MediaPlayer [$id] error: what=$what, extra=$extra, url=$url")
                true
            }

            player.setOnCompletionListener {
                Log.d(TAG, "Playback completed for [$id]: $url")
            }

            player.prepareAsync()
        } catch (e: Exception) {
            Log.e(TAG, "Exception playing audio [$id]: ${e.message}", e)
            stopAudio(id)
        }
    }

    private fun pauseAudio() {
        try {
            players.values.forEach {
                if (it.isPlaying) it.pause()
            }
            Log.d(TAG, "Audio paused")
        } catch (e: Exception) {
            Log.e(TAG, "Exception pausing audio: ${e.message}", e)
        }
    }

    private fun stopAudio(id: String) {
        try {
            players.remove(id)?.let {
                if (it.isPlaying) it.stop()
                it.reset()
                it.release()
                Log.d(TAG, "Audio [$id] stopped and released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception stopping audio [$id]: ${e.message}", e)
            players.remove(id)
        }
        try {
            assetDescriptors.remove(id)?.close()
        } catch (_: Exception) {
        }
    }

    private fun stopAllAudio() {
        for (id in players.keys.toList()) {
            stopAudio(id)
        }
    }

    override fun onDestroy() {
        unregisterApkReceiver()
        stopAllAudio()
        super.onDestroy()
    }
}