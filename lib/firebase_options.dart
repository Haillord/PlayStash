// lib/firebase_options.dart
// Сгенерировано вручную для Windows-платформы на основе google-services.json

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return windows;
    }
    // Для Android/iOS/Web используем стандартный DefaultFirebaseOptions
    throw UnsupportedError(
      'DefaultFirebaseOptions not supported for this platform.',
    );
  }

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB9LR7yAEV0XWUfuCLzhmLW-pTK9rlWahs',
    appId: '1:217121557488:windows:f6e734c2cdd72e44ea2b35',
    messagingSenderId: '217121557488',
    projectId: 'game-tracker-405b9',
    authDomain: 'game-tracker-405b9.firebaseapp.com',
    databaseURL: '',
    storageBucket: 'game-tracker-405b9.firebasestorage.app',
    measurementId: '',
  );
}