import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hexcore/src/hexcore_client.dart';
import 'package:hexcore/src/hexcore_storage.dart';
import 'package:hexcore/src/utils/lockfile_utils.dart';

class Hexcore {
  /// [HexcoreStorage] store all the needed data from the League client, such as, it's path and connection needed keys.
  final HexcoreStorage _storage;

  /// [HexcoreClient] instance that handles all the REST calls to League client.
  final HexcoreClient _client;

  /// Called when the [Hexcore] get connected to the League Client.
  void Function()? onConnect;

  /// Called when the [Hexcore] disconnect from the League Client or when the client is closed.
  void Function()? onDisconnect;

  /// Called when the [Hexcore] is trying to connect to the League Client.
  void Function()? onWaiting;

  /// Notify the current [HexcoreState] of the application
  ValueNotifier<HexcoreState> state =
      ValueNotifier<HexcoreState>(HexcoreState.initial);

  /// Watch the directory to know when the player reopens the League Client after connecting the first time
  StreamSubscription<FileSystemEvent>? _watchDirectory;

  Hexcore._create(
    this._client,
    this._storage,
  );

  /// Async constructor for [Hexcore], where it creates an private [HexcoreStorage] and [HexcoreClient] instances that are needed by [Hexcore]
  static Future<Hexcore> create() async {
    HexcoreStorage storage = await HexcoreStorage.create();
    HexcoreClient client = await HexcoreClient.create(storage: storage);

    return Hexcore._create(
      client,
      storage,
    );
  }

  /// Dispose and/or cancel all the listeners, clients and streams in the [Hexcore] instance
  Future<void> close() async {
    state.dispose();
    _client.close();
    await _watchDirectory?.cancel();
  }

  void _updateState(HexcoreState state) {
    this.state.value = state;
    switch (state) {
      case HexcoreState.connected:
        onConnect?.call();
        break;
      case HexcoreState.waiting:
        onWaiting?.call();
        break;
      case HexcoreState.searchingClientPath:
        break;
      default:
        break;
    }
  }

  /// Try to connect to League Client.
  ///
  /// [Hexcore] will store the path of the player's client to make it easier and quicker to connected again.
  ///
  /// If [Hexcore] never connected before, it will search for the League Client path.
  ///
  /// If [Hexcore] has been connected once, it will watch the directory waiting for League Client to be open.
  ///
  /// Also [Hexcore] listen to the Client state, if the clients get closed [Hexcore] will change its state and starts to wait for the client to reopen.
  Future<void> connectToClient() async {
    _updateState(HexcoreState.waiting);

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
        _updateState(HexcoreState.connected);

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
    _updateState(HexcoreState.searchingClientPath);
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
        _updateState(HexcoreState.connected);

        break;
      }
    }
  }

  StreamSubscription<FileSystemEvent>?
      _listenToClientDirectoryAfterLeagueClose() {
    Directory leagueDirectory = Directory(_storage.getLeaguePath());
    String validatorPath = '${_storage.getLeaguePath()}\\lockfile';
    _watchDirectory = leagueDirectory.watch().listen((event) {
      if (event is FileSystemDeleteEvent && event.path == validatorPath) {
        onDisconnect?.call();
        connectToClient();
      }
    });
    return _watchDirectory;
  }

  /// Send a custom notification to League Client. Make a REST request to league's client showing a notification.
  /// Show a notification at league client with [title], [details] and a background given by [backgroundUrl], [backgroundUrl] can be null. After a feel seconds this notification will disapear.
  ///
  /// The sended notification will be added to the notification list at client, in that list you will be able to see the [title], [details] and an image, given by [iconUrl].
  Future<void> sendCustomNotification({
    String? backgroundUrl,
    String? iconUrl,
    required String title,
    required String details,
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

  /// Create a custom lobby by its [lobbyName], and if its passed and [lobbyPassword].
  ///
  /// The current player will be redirect to the custom lobby after the creation.
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

  /// List all the custom lobbys presents in the client.
  Future<List<Map<String, dynamic>>> listCustomMatches() async {
    var response = await _client.request('GET', '/lol-lobby/v1/custom-games');

    return response;
  }

  /// Join a custom lobby by a given [id], if the lobby needs a password, you can pass it through [password].
  ///
  /// You can get the [id] of an lobby at the [listCustomMatches]'s response.
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

/// Enum used to describe the state of the [Hexcore] connecion to League Client
enum HexcoreState {
  initial,
  connected,
  waiting,
  searchingClientPath,
}
