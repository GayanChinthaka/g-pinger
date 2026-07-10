package com.pokerlanka.g_pinger

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Keeps the process alive (and Dart timers running) while pinging in the
 * background, and shows an ongoing notification with live stats and a Stop
 * action.
 */
class PingerForegroundService : Service() {

    companion object {
        const val ACTION_START = "com.pokerlanka.gpinger.action.START"
        const val ACTION_STOP = "com.pokerlanka.gpinger.action.STOP"
        const val EXTRA_TEXT = "text"

        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "pinger_status"

        /** Set by MainActivity so a notification Stop tap reaches Dart. */
        var onStopFromNotification: (() -> Unit)? = null

        @Volatile
        private var isRunning = false

        fun updateNotification(context: Context, text: String) {
            if (!isRunning) return
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(context, text))
        }

        private fun buildNotification(context: Context, text: String): Notification {
            val stopPending = PendingIntent.getService(
                context,
                0,
                Intent(context, PingerForegroundService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val openPending = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.let {
                    PendingIntent.getActivity(
                        context,
                        1,
                        it,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                }
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.launcher_icon)
                .setContentTitle("G Pinger")
                .setContentText(text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(openPending)
                .addAction(0, "Stop", stopPending)
                .build()
        }

        private fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Pinging status",
                        NotificationManager.IMPORTANCE_LOW,
                    ),
                )
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                onStopFromNotification?.invoke()
                stopSelf()
            }
            else -> {
                createChannel(this)
                val notification =
                    buildNotification(this, intent?.getStringExtra(EXTRA_TEXT) ?: "Pinging…")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                isRunning = true
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }
}
