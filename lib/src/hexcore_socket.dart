import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:hexcore/src/hexcore_storage.dart';

class HexcoreSocket {
  final WebSocket _socket;

  HexcoreSocket(this._socket);

  static Future<HexcoreSocket> connect() async {
    final storage = await HexcoreStorage.create();
    try {
      final authKey = storage.getLeagueAuth();
      final port = storage.getLeaguePort();

      WebSocket socket =
          await WebSocket.connect('wss://riot:$authKey@127.0.0.1:$port/');

      return HexcoreSocket(socket);
    } catch (e) {
      log(
        "Verify if you are connected to League Client before trying to connect to it's socket",
        name: "HEXCORE",
      );
      throw Exception(e);
    }
  }

  /// Subscribe to LCU Events. for examble with you subscribe to ```[5, "OnJsonApiEvent"]```
  /// the socket will handle every event the client sends.
  /// To learn more about LCU events see: https://hextechdocs.dev/getting-started-with-the-lcu-websocket/
  void add(String event) {
    _socket.add(event);
  }

  /// Returns a [StreamSubscription] which handles LCU Events
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _socket.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  Future<dynamic> close() async {
    await _socket.close();
  }
}
