import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'services/seed_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // アプリを先に表示し、認証・シードは非同期で実行（ブロックしない）
  runApp(const TequilaApp());

  FirebaseAuth.instance.signInAnonymously().then((_) {
    seedDummyData();
  }).catchError((e) {
    // ignore: avoid_print
    print('Firebase init error: $e');
  });
}

class TequilaApp extends StatelessWidget {
  const TequilaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '20th Anniversary Tequila',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
