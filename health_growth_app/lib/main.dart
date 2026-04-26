import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'ui/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Growth',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: home ?? const HomePage(),
    );
  }
}
