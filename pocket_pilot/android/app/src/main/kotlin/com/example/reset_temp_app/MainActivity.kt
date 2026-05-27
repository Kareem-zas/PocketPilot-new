package com.example.reset_temp_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity is required by local_auth for biometric prompts.
// Using FlutterActivity instead will cause local_auth to crash on Android.
class MainActivity : FlutterFragmentActivity()
