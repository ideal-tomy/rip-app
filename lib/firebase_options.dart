import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA8nqYnvD_nPjHi2Po8PFscZkmrKXwmxio',
    appId: '1:998351330791:web:e92ecf5695a7c8c512f142',
    messagingSenderId: '998351330791',
    projectId: 'rip-app-79c14',
    authDomain: 'rip-app-79c14.firebaseapp.com',
    storageBucket: 'rip-app-79c14.firebasestorage.app',
  );
}