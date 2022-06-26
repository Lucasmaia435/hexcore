import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hexcore/hexcore.dart';

Hexcore? hexcore;
void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  hexcore = await Hexcore.create();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hexcore Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Hexcore Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    if (hexcore?.state.value != HexcoreState.connected) {
      hexcore?.connectToClient();
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: AnimatedBuilder(
        animation: hexcore!.state,
        builder: (BuildContext context, Widget? child) {
          if (hexcore!.state.value == HexcoreState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('HexcoreStatus: ${hexcore!.state.value.toString()}'),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: OutlinedButton(
                      onPressed: () {
                        hexcore!.sendCustomNotification(
                          title: 'Hexcore is ready',
                          details: 'Connected to League Client',
                        );
                      },
                      child: const Text('Send notification'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      hexcore!.createCustomMatch(
                        lobbyName: 'Hexcore match',
                        lobbyPassword: 'h3xc0r3',
                      );
                    },
                    child: const Text('Create custom match'),
                  )
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
