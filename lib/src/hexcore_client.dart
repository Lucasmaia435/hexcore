import 'dart:convert';
import 'dart:io';

import 'package:hexcore/src/hexcore_storage.dart';

import 'utils/certificate.dart';

class HexcoreClient {
  final HexcoreStorage _storage;

  final HttpClient _client;

  int _port = -1;
  String _authKey = '';

  HexcoreClient(
    this._client,
    this._storage,
  );

  Future<void> updateWithLockfile(Map<String, dynamic> lockfileData) async {
    _port = lockfileData['port'];
    _authKey = lockfileData['auth_key'];

    await _storage.setLeaguePort(_port);
    await _storage.setLeagueAuth(_authKey);
  }

  static Future<HexcoreClient> create({required HexcoreStorage storage}) async {
    return HexcoreClient(
      HttpClient(
        context: await readRiotCertificate(),
      ),
      storage,
    );
  }

  Future<dynamic> request(String method, String endpoint,
      {Map<String, dynamic>? body}) async {
    HttpClientRequest req = await _client.openUrl(
      method,
      Uri.parse('https://127.0.0.1:$_port$endpoint'),
    );

    req.headers.set(
      HttpHeaders.acceptHeader,
      'application/json',
    );
    req.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json',
    );
    req.headers.set(
      HttpHeaders.authorizationHeader,
      'Basic ${utf8.fuse(base64).encode('riot:$_authKey')}',
    );

    if (body != null) req.add(json.fuse(utf8).encode(body));

    HttpClientResponse resp = await req.close();
    return resp.transform(utf8.decoder).join().then(
          (String data) => json.decode(
            data.isEmpty ? '{}' : data,
          ),
        );
  }

  void close() {
    _client.close();
  }
}
