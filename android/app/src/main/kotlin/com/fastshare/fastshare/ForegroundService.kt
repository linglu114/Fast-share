package com.fastshare.fastshare

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

class ForegroundService : Service() {

    private var currentTitle: String = "瞬息"
    private var currentBody: String = "Running in background"
    private var currentProgress: Int = -1
    private var currentProgressMax: Int = 100

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> {
                intent.getStringExtra(EXTRA_TITLE)?.let { currentTitle = it }
                intent.getStringExtra(EXTRA_BODY)?.let { currentBody = it }
                if (intent.hasExtra(EXTRA_PROGRESS)) {
                    currentProgress = intent.getIntExtra(EXTRA_PROGRESS, -1)
                    currentProgressMax = intent.getIntExtra(EXTRA_PROGRESS_MAX, 100)
                } else {
                    currentProgress = -1
                }
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
        }

        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Fallback if type enforcement fails on older APIs
            startForeground(NOTIFICATION_ID, notification)
        }

        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentTitle)
            .setContentText(currentBody)
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (currentProgress >= 0) {
            builder.setProgress(currentProgressMax, currentProgress, false)
        } else {
            builder.setProgress(0, 0, true) // indeterminate
        }

        return builder.build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Transfer Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shown while file transfers are active in background"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val CHANNEL_ID = "fastshare_foreground"
        const val NOTIFICATION_ID = 1
        const val ACTION_UPDATE = "com.fastshare.UPDATE_NOTIFICATION"
        const val ACTION_STOP = "com.fastshare.STOP_SERVICE"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_PROGRESS = "extra_progress"
        const val EXTRA_PROGRESS_MAX = "extra_progress_max"

        fun createIntent(context: Context, title: String, body: String): Intent {
            return Intent(context, ForegroundService::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
            }
        }

        fun updateIntent(
            context: Context,
            title: String,
            body: String,
            progress: Int?,
            progressMax: Int?
        ): Intent {
            return Intent(context, ForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                if (progress != null) {
                    putExtra(EXTRA_PROGRESS, progress)
                    putExtra(EXTRA_PROGRESS_MAX, progressMax ?: 100)
                }
            }
        }

        fun stopIntent(context: Context): Intent {
            return Intent(context, ForegroundService::class.java).apply {
                action = ACTION_STOP
            }
        }
    }
}
