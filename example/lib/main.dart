import 'dart:async';
import 'dart:io';

import 'package:audio_toolkit/audio_toolkit.dart';
import 'package:audio_toolkit/language_type.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: Container());
  }
}
