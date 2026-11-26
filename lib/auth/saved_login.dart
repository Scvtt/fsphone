import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// The last successful desktop sign-in, kept on this PC so a restart can
/// register again without typing the extension password.
class SavedLogin {
  const SavedLogin({
    required this.server,
    required this.domain,
    required this.extension,
    required this.password,
    required this.trustAnyCertificate,
  });

  final String server;
  final String domain;
  final String extension;
  final String password;
  final bool trustAnyCertificate;

  static const _server = 'fsphone.server';
  static const _domain = 'fsphone.domain';
  static const _extension = 'fsphone.extension';
  static const _password = 'fsphone.password';
  static const _trust = 'fsphone.trust';

  static Future<SavedLogin?> read() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString(_server);
    final extension = prefs.getString(_extension);
    final password = prefs.getString(_password);
    if (server == null ||
        server.isEmpty ||
        extension == null ||
        extension.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return SavedLogin(
      server: server,
      domain: prefs.getString(_domain) ?? '',
      extension: extension,
      password: password,
      trustAnyCertificate: prefs.getBool(_trust) ?? true,
    );
  }

  static Future<void> write(SavedLogin login) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_server, login.server);
    await prefs.setString(_domain, login.domain);
    await prefs.setString(_extension, login.extension);
    await prefs.setString(_password, login.password);
    await prefs.setBool(_trust, login.trustAnyCertificate);
  }

  static Future<void> clear() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_server);
    await prefs.remove(_domain);
    await prefs.remove(_extension);
    await prefs.remove(_password);
    await prefs.remove(_trust);
  }
}
