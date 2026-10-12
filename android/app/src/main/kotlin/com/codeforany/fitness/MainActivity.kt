package com.codeforany.fitness

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: the Health Connect permission
// screen is launched through an ActivityResult contract, which only a
// FragmentActivity can register. With the plain activity the request
// silently returns "denied".
class MainActivity: FlutterFragmentActivity() {
}
