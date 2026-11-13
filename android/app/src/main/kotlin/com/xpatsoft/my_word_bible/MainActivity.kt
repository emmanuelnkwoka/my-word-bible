package com.xpatsoft.my_word_bible

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Shares rendered Scripture cards from the app cache (see res/xml/mwb_card_paths.xml). */
class MwbCardFileProvider : FileProvider()

/**
 * Card export channel for the Scripture Card Studio:
 * - saveToGallery: MediaStore (Android 10+) or Pictures/ with permission (Android 9 and older)
 * - saveToLocation: Storage Access Framework "Save as" picker
 * - shareToApp: hands images (and optional text) to one installed app, e.g. WhatsApp
 * - installedPackages: which supported social apps are installed
 *
 * The app never posts anything itself: the target app opens and the user decides.
 */
class MainActivity : FlutterActivity() {
    private var pendingSave: Pair<ByteArray, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "installedPackages" -> result.success(installed(call.argument<List<String>>("packages") ?: emptyList()))
                    "saveToGallery" -> result.success(
                        saveToGallery(call.argument<ByteArray>("bytes")!!, call.argument<String>("fileName")!!, call.argument<String>("mimeType")!!),
                    )
                    "saveToLocation" -> saveToLocation(call, result)
                    "shareToApp" -> result.success(shareToApp(call))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.success(failed(e.message ?: e.javaClass.simpleName))
            }
        }
    }

    private fun failed(detail: String?) = mapOf("status" to "failed", "detail" to detail)

    private fun isInstalled(pkg: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= 33) {
            packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(pkg, 0)
        }
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun installed(packages: List<String>): List<String> = packages.filter { isInstalled(it) }

    private fun saveToGallery(bytes: ByteArray, fileName: String, mime: String): Map<String, Any?> {
        val location = "Pictures/My Word Bible/$fileName"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/My Word Bible")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: return failed("The gallery did not accept the image")
            val stream = contentResolver.openOutputStream(uri) ?: return failed("The image could not be written")
            stream.use { it.write(bytes) }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return mapOf("status" to "saved", "location" to location)
        }
        if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), REQUEST_STORAGE)
            return mapOf("status" to "permissionNeeded")
        }
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "My Word Bible")
        dir.mkdirs()
        val file = File(dir, fileName)
        file.writeBytes(bytes)
        MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf(mime), null)
        return mapOf("status" to "saved", "location" to location)
    }

    private fun saveToLocation(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")!!
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = call.argument<String>("mimeType")!!
            putExtra(Intent.EXTRA_TITLE, call.argument<String>("fileName")!!)
        }
        pendingSave?.second?.success(mapOf("status" to "cancelled"))
        pendingSave = Pair(bytes, result)
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQUEST_SAVE_AS)
    }

    @Deprecated("Activity result API is not used by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (requestCode == REQUEST_SAVE_AS) {
            val pending = pendingSave ?: return
            pendingSave = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                pending.second.success(mapOf("status" to "cancelled"))
                return
            }
            try {
                val stream = contentResolver.openOutputStream(uri)
                if (stream == null) {
                    pending.second.success(failed("The file could not be written"))
                    return
                }
                stream.use { it.write(pending.first) }
                pending.second.success(mapOf("status" to "saved", "location" to (uri.lastPathSegment ?: uri.toString())))
            } catch (e: Exception) {
                pending.second.success(failed(e.message))
            }
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun shareToApp(call: MethodCall): Map<String, Any?> {
        val pkg = call.argument<String>("package")!!
        if (!isInstalled(pkg)) return mapOf("status" to "notInstalled")
        val files = call.argument<List<ByteArray>>("files")!!
        val names = call.argument<List<String>>("fileNames")!!
        val mime = call.argument<String>("mimeType")!!
        val text = call.argument<String>("text")
        if (files.isEmpty() || files.size != names.size) return failed("No images")

        val dir = File(cacheDir, "mwb_cards").apply { mkdirs() }
        // Remove cards from earlier shares (older than an hour) so the cache stays small.
        val cutoff = System.currentTimeMillis() - 60 * 60 * 1000
        dir.listFiles()?.filter { it.lastModified() < cutoff }?.forEach { it.delete() }

        val uris = files.mapIndexed { i, bytes ->
            val f = File(dir, names[i])
            f.writeBytes(bytes)
            FileProvider.getUriForFile(this, "$packageName.mwbcards", f)
        }
        val intent = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0])
        } else {
            Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
        }
        intent.type = mime
        intent.setPackage(pkg)
        if (!text.isNullOrEmpty()) intent.putExtra(Intent.EXTRA_TEXT, text)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val clip = ClipData.newRawUri("", uris[0])
        uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
        intent.clipData = clip
        startActivity(intent)
        return mapOf("status" to "opened", "location" to pkg)
    }

    companion object {
        private const val CHANNEL = "com.xpatsoft.mwb/card_export"
        private const val REQUEST_SAVE_AS = 7301
        private const val REQUEST_STORAGE = 7302
    }
}
