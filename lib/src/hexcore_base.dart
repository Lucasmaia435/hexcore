import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hexcore/src/hexcore_client.dart';
import 'package:hexcore/src/hexcore_storage.dart';
import 'package:hexcore/src/utils/lockfile_utils.dart';

class Hexcore {
  final HexcoreStorage _storage;
  final HexcoreClient _client;

  void Function()? onConnect;
  void Function()? onDisconnect;
  void Function()? onWaiting;

  ValueNotifier<HexcoreStatus> status =
      ValueNotifier<HexcoreStatus>(HexcoreStatus.waiting);

  StreamSubscription<FileSystemEvent>? watchDirectory;
  Hexcore(
    this._client,
    this._storage,
  );

  static Future<Hexcore> create() async {
    HexcoreStorage storage = await HexcoreStorage.create();
    HexcoreClient client = await HexcoreClient.create(storage: storage);

    return Hexcore(
      client,
      storage,
    );
  }

  Future<void> close() async {
    status.dispose();
    _client.close();
    await watchDirectory?.cancel();
  }

  void _updateStatus(HexcoreStatus status) {
    this.status.value = status;
    switch (status) {
      case HexcoreStatus.connected:
        onConnect?.call();
        break;
      case HexcoreStatus.waiting:
        print('Procurando');
        onWaiting?.call();
        break;

      case HexcoreStatus.searchingClientPath:
        break;
      default:
        break;
    }
  }

  Future<void> connectToClient() async {
    _updateStatus(HexcoreStatus.waiting);

    if (_storage.hasLeaguePath()) {
      Directory leagueDirectory = Directory(_storage.getLeaguePath());
      List<FileSystemEntity> entities = await leagueDirectory.list().toList();

      bool hasLockfileInDirectory = false;
      String? filePath;

      for (var element in entities) {
        if (element.uri.toFilePath().contains('lockfile')) {
          hasLockfileInDirectory = true;
          filePath = element.uri.toFilePath();
        }
      }

      if (hasLockfileInDirectory) {
        File file = File(filePath!);
        Map<String, dynamic> lockFileContent = readLockFile(file);

        await _client.updateWithLockfile(lockFileContent);
        _updateStatus(HexcoreStatus.connected);

        _listenToClientDirectoryAfterLeagueClose();
      } else {
        await _watchDirectoryForLockfile(leagueDirectory);
      }
    } else {
      await _findLeaguePath();
      await connectToClient();
    }
  }

  Future<void> _findLeaguePath() async {
    _updateStatus(HexcoreStatus.searchingClientPath);
    bool keepProcess = true;
    while (keepProcess) {
      if (Platform.isWindows) {
        var result = await Process.start(
          'cmd ',
          [],
        );
        result.stdout.forEach((List<int> data) async {
          String string = utf8.decode(data, allowMalformed: true);
          if (string.contains("League of Legends")) {
            String path = lockFilePath(string);

            await _storage.saveLeaguePath(path);

            keepProcess = false;
            result.kill();
          }
        });
        result.stdin.writeln("cd / && dir LeagueClient.exe /s /p");
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  Future<void> _watchDirectoryForLockfile(Directory leagueDirectory) async {
    await for (final event in leagueDirectory.watch()) {
      String filePath = event.path;
      File validator = File('${_storage.getLeaguePath()}\\lockfile');

      if (filePath == validator.path) {
        File file = File(filePath);
        Map<String, dynamic> lockFileContent = readLockFile(file);

        await _client.updateWithLockfile(lockFileContent);
        _updateStatus(HexcoreStatus.connected);

        break;
      }
    }
  }

  StreamSubscription<FileSystemEvent>?
      _listenToClientDirectoryAfterLeagueClose() {
    Directory leagueDirectory = Directory(_storage.getLeaguePath());
    String validatorPath = '${_storage.getLeaguePath()}\\lockfile';
    watchDirectory = leagueDirectory.watch().listen((event) {
      if (event is FileSystemDeleteEvent && event.path == validatorPath) {
        onDisconnect?.call();
        connectToClient();
      }
    });
    return watchDirectory;
  }

  Future<void> sendCustomNotification({
    String? backgroundUrl,
    String? iconUrl,
    String? title,
    String? details,
  }) async {
    await _client.request(
      'POST',
      '/player-notifications/v1/notifications',
      body: {
        "backgroundUrl": backgroundUrl,
        "critical": true,
        "data": {"title": title, "details": details},
        "detailKey": "pre_translated_details",
        "iconUrl": iconUrl,
        "titleKey": "pre_translated_title",
        "type": "default"
      },
    );
  }

  Future<void> createCustomMatch(
      {required String lobbyName, String? lobbyPassword}) async {
    await _client.request('POST', '/lol-lobby/v2/lobby', body: {
      "customGameLobby": {
        "configuration": {
          "gameMode": "CLASSIC",
          "gameMutator": "",
          "gameServerRegion": "",
          "mapId": 11,
          "mutators": {"id": 1},
          "spectatorPolicy": "AllAllowed",
          "teamSize": 5
        },
        "lobbyName": lobbyName,
        "lobbyPassword": lobbyPassword ?? ''
      },
      "isCustom": true
    });
  }

  Future<void> listCustomMatches() async {
    var response = await _client.request('GET', '/lol-lobby/v1/custom-games');

    return response;
  }

  Future<void> joinCustomMatch({
    required String id,
    String? password,
  }) async {
    await _client.request(
      'POST',
      '/lol-lobby/v1/custom-games/$id/join',
      body: {
        "asSpectator": false,
        "password": password ?? '',
      },
    );
  }
}

enum HexcoreStatus {
  connected,
  waiting,
  searchingClientPath,
}
