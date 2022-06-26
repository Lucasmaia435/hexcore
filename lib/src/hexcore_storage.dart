import 'package:shared_preferences/shared_preferences.dart';

class HexcoreStorage {
  SharedPreferences? storage;

  static Future<HexcoreStorage> create() async {
    var instance = HexcoreStorage();

    instance.storage = await SharedPreferences.getInstance();

    return instance;
  }

  Future<bool> saveLeaguePath(String path) async {
    bool res = await storage!.setString('league_client_path', path);

    return res;
  }

  String getLeaguePath() {
    String? path = storage!.getString('league_client_path');
    return path!;
  }

  bool hasLeaguePath() {
    return storage?.containsKey('league_client_path') ?? false;
  }

  int getLeaguePort() {
    int? port = storage!.getInt('league_client_port');

    return port!;
  }

  Future<bool> setLeaguePort(int port) async {
    bool res = await storage!.setInt('league_client_port', port);

    return res;
  }

  String getLeagueAuth() {
    String? auth = storage!.getString('league_client_auth');

    return auth!;
  }

  Future<bool> setLeagueAuth(String auth) async {
    bool res = await storage!.setString('league_client_auth', auth);

    return res;
  }
}
