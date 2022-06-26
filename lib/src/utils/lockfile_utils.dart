import 'dart:io';

String lockFilePath(String string) {
  String path = string.split('\n')[1].split(':')[1].replaceAll(r'\', '/');
  path = path.substring(0, path.length - 1);

  String directory = string.split('\n')[1].split(':')[0].split('').last;

  return '$directory:$path';
}

Map<String, dynamic> readLockFile(File file) {
  String content = file.readAsStringSync();
  List<String> args = content.split(':');

  return {
    'port': int.parse(args[2]),
    'auth_key': args[3],
  };
}
