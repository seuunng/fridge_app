import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBl_i5hCKgo-HPZqbi-Sf-Ey5BjzlDQx0E',
    appId: '1:897589496124:android:ce3073c291afd5258eb639',
    messagingSenderId: '897589496124',
    projectId: 'food-for-later',
    storageBucket: 'food-for-later.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBYq8R-yfT13Zk2zptHuiIUiTWpfKbHzDs',
    appId: '1:897589496124:ios:7cf5769271adfa7c8eb639',
    messagingSenderId: '897589496124',
    projectId: 'food-for-later',
    storageBucket: 'food-for-later.appspot.com',
    androidClientId:
        '897589496124-mqudmevsl1fnujtg5av3nfa5qkmmlvir.apps.googleusercontent.com',
    iosClientId:
        '897589496124-0lvf9jpu1u8567657fb2bj0cm97f7d1c.apps.googleusercontent.com',
    iosBundleId: 'com.example.foodForLater',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCVwCjP8Tn1FX7gxVO_IG_lJur8TLsu6Zc',
    appId: '1:897589496124:web:2f55ce54afa252a68eb639',
    messagingSenderId: '897589496124',
    projectId: 'food-for-later',
    authDomain: 'food-for-later.firebaseapp.com',
    storageBucket: 'food-for-later.appspot.com',
    measurementId: 'G-BFFCMJR6QT',
  );
}
