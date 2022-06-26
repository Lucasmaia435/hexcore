import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Root certificate use to validate the game client's SSL
Future<SecurityContext> readRiotCertificate() async {
  String cert = await rootBundle
      .loadString('packages/hexcore/assets/certificate/riotgames.pem');

  SecurityContext secCtx = SecurityContext();
  secCtx.setTrustedCertificatesBytes(utf8.encode(cert));

  return secCtx;
}
