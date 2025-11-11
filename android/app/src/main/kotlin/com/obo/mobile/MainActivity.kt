package com.obo.mobile

import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "obo_mobile/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSimCards" -> {
                        result.success(getSimCards())
                    }

                    "sendSms" -> {
                        val phone = call.argument<String>("phone")
                        val message = call.argument<String>("message")
                        val subscriptionId = call.argument<Int>("subscriptionId")
                        try {
                            val success = sendSms(phone, message, subscriptionId)
                            result.success(success)
                        } catch (error: Exception) {
                            result.error("SMS_ERROR", error.localizedMessage, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun getSimCards(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
            return emptyList()
        }
        val subscriptionManager = getSystemService(SubscriptionManager::class.java)
        val activeList: List<SubscriptionInfo> =
            subscriptionManager?.activeSubscriptionInfoList ?: emptyList()

        return activeList.map { info ->
            mapOf(
                "subscriptionId" to info.subscriptionId,
                "displayName" to info.displayName?.toString(),
                "carrierName" to info.carrierName?.toString(),
                "number" to info.number,
                "slotIndex" to info.simSlotIndex
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun sendSms(phone: String?, message: String?, subscriptionId: Int?): Boolean {
        if (phone.isNullOrBlank()) {
            throw IllegalArgumentException("Phone number is missing.")
        }
        if (message.isNullOrBlank()) {
            throw IllegalArgumentException("Message body is missing.")
        }

        val smsManager = when {
            subscriptionId != null && subscriptionId >= 0 -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val systemManager = getSystemService(SmsManager::class.java)
                    systemManager?.createForSubscriptionId(subscriptionId)
                        ?: SmsManager.getDefault()
                } else {
                    SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
                }
            }

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
            }

            else -> SmsManager.getDefault()
        }

        val parts = smsManager.divideMessage(message)
        return if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            true
        } else {
            smsManager.sendTextMessage(phone, null, message, null, null)
            true
        }
    }
}
