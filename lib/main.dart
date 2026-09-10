import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:greens_app/screens/auth_gate.dart';

//initial start up script, added in github, alterd in vscode

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xzvawbevrlatfshsgnum.supabase.co',
    publishableKey: 'sb_publishable_w3f76jQ5ZPNT7SmCds0SQA_eGFxoTAO',
  );

  runApp(const SilkstoneGreensApp());
}

class SilkstoneGreensApp extends StatelessWidget {
  const SilkstoneGreensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Silkstone Greens App',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
