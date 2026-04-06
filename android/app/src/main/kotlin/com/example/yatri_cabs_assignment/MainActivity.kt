package com.example.yatri_cabs_assignment

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yatri_cabs/keys")
			.setMethodCallHandler { call, result ->
				if (call.method == "getGoogleMapsApiKey") {
					try {
						val buildConfigKey = BuildConfig.GOOGLE_DIRECTIONS_API_KEY.trim()
						if (buildConfigKey.isNotEmpty()) {
							result.success(buildConfigKey)
							return@setMethodCallHandler
						}

						val appInfo = packageManager.getApplicationInfo(
							packageName,
							PackageManager.GET_META_DATA
						)
						val key =
							appInfo.metaData
								?.getString("com.google.android.geo.API_KEY")
								?.trim()
								?: ""
						result.success(key)
					} catch (_: Exception) {
						result.success("")
					}
				} else {
					result.notImplemented()
				}
			}
	}
}
