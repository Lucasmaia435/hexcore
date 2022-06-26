import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hexcore/hexcore.dart';

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  Hexcore core = await Hexcore.create();
  core.connectToClient();
  runApp(MyWidget(
    core: core,
  ));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key, required this.core}) : super(key: key);
  final Hexcore core;
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp();
  }
}
