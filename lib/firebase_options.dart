import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: (dotenv.isInitialized ? dotenv.env['FIREBASE_ANDROID_API_KEY'] : null) ??
            'AIzaSyAXcx_MkLt2gxTfMte5bz4q3ebJ14kjLOc',
        appId: (dotenv.isInitialized ? dotenv.env['FIREBASE_ANDROID_APP_ID'] : null) ??
            '1:443707726754:android:bd05c837704107888070fb',
        messagingSenderId: (dotenv.isInitialized ? dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] : null) ??
            '443707726754',
        projectId: (dotenv.isInitialized ? dotenv.env['FIREBASE_PROJECT_ID'] : null) ??
            'areis-b73bd',
        storageBucket: (dotenv.isInitialized ? dotenv.env['FIREBASE_STORAGE_BUCKET'] : null) ??
            'areis-b73bd.firebasestorage.app',
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: (dotenv.isInitialized ? dotenv.env['FIREBASE_IOS_API_KEY'] : null) ??
            'AIzaSyAKWJLt7meehW1A7n7TiK7jnteQtxFMoiA',
        appId: (dotenv.isInitialized ? dotenv.env['FIREBASE_IOS_APP_ID'] : null) ??
            '1:443707726754:ios:55963db1de72b1408070fb',
        messagingSenderId: (dotenv.isInitialized ? dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] : null) ??
            '443707726754',
        projectId: (dotenv.isInitialized ? dotenv.env['FIREBASE_PROJECT_ID'] : null) ??
            'areis-b73bd',
        storageBucket: (dotenv.isInitialized ? dotenv.env['FIREBASE_STORAGE_BUCKET'] : null) ??
            'areis-b73bd.firebasestorage.app',
        iosBundleId: 'com.culturecards.app',
      );


      // static const FirebaseOptions mac = FirebaseOptions(
      //   apiKey: '',
      //   appId: '',
      //   messagingSenderId: '',
      //   projectId: '',
      //   storageBucket: '',
      //   iosBundleId: 'com.culturecards.app',
      // );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForLiveStreamApp123456789',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'culturecards-live-stream',
    authDomain: 'culturecards-live-stream.firebaseapp.com',
    storageBucket: 'culturecards-live-stream.appspot.com',
  );
}
