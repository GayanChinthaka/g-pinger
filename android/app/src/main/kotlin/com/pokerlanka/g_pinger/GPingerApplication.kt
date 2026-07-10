package com.pokerlanka.g_pinger

import android.app.Application
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine at application scope so the Dart isolate (and its
 * ping timer) survives the activity being destroyed — back button, minimize,
 * or swipe-away. The foreground service keeps the process alive; this keeps
 * the engine alive inside it.
 */
class GPingerApplication : Application() {

    companion object {
        const val ENGINE_ID = "g_pinger_engine"
    }

    override fun onCreate() {
        super.onCreate()

        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)

        val channel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "com.pokerlanka.gpinger/pinger_service",
        )
        PingerForegroundService.onStopFromNotification = {
            channel.invokeMethod("stopFromNotification", null)
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, PingerForegroundService::class.java)
                        .setAction(PingerForegroundService.ACTION_START)
                        .putExtra(
                            PingerForegroundService.EXTRA_TEXT,
                            call.argument<String>("text") ?: "Pinging…",
                        )
                    ContextCompat.startForegroundService(this, intent)
                    result.success(null)
                }
                "update" -> {
                    PingerForegroundService.updateNotification(
                        this,
                        call.argument<String>("text") ?: "",
                    )
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, PingerForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
