import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'ui/ui_admin_home.dart';

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
      title: 'Admin App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: home ?? const AdminHome(),
    );
  }
}
