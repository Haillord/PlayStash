// lib/services/google_auth_desktop.dart
// Полноценный OAuth 2.0 with PKCE для Google Sign-In на desktop
//
// Как работает:
// 1. Открываем браузер с Google OAuth страницей
// 2. Google редиректит на http://localhost:8080/?code=...
// 3. Локальный HTTP-сервер ловит callback
// 4. Обмениваем code на access_token + id_token через POST /token
// 5. Firebase Auth завершает логин через credential

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleAuthDesktop {
  static const _clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const _clientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
  static const _redirectPort = 8080;
  static const _redirectUri = 'http://localhost:$_redirectPort';

  static String _randomString(int length) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Future<UserCredential> signIn() async {
    final codeVerifier = _randomString(64);
    final codeChallenge = base64UrlEncode(
      sha256.convert(utf8.encode(codeVerifier)).bytes,
    ).replaceAll('=', '');
    final state = _randomString(16);

    // 1. Запускаем локальный HTTP-сервер
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _redirectPort);

    // 2. Открываем браузер с Google OAuth
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
    });

    await launchUrl(authUrl, mode: LaunchMode.externalApplication);

    // 3. Ждём редирект от Google
    final request = await server.first;
    final params = request.uri.queryParameters;

    // Отвечаем браузеру страницей успеха
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write('''
        <html>
        <body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;">
          <div style="text-align:center;">
            <h2 style="color:#4CAF50;">✅ Вход выполнен!</h2>
            <p>Можете закрыть это окно.</p>
          </div>
        </body>
        </html>
      ''');
    await request.response.close();
    await server.close();

    // Проверяем state (защита от CSRF)
    if (params['state'] != state) {
      throw Exception('Invalid state parameter');
    }

    final code = params['code'];
    if (code == null) {
      final error = params['error'] ?? 'unknown_error';
      throw Exception('Google auth error: $error');
    }

    // 4. Обмениваем code на токены
    final tokenClient = HttpClient();
    try {
      final tokenRequest = await tokenClient.postUrl(
        Uri.parse('https://oauth2.googleapis.com/token'),
      );
      tokenRequest.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded');
      tokenRequest.write(Uri(queryParameters: {
        'code': code,
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'redirect_uri': _redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': codeVerifier,
      }).query);

      final tokenResponse = await tokenRequest.close();
      final body = await tokenResponse.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (json.containsKey('error')) {
        throw Exception('Token error: ${json['error']}');
      }

      final accessToken = json['access_token'] as String;
      final idToken = json['id_token'] as String?;

      // 5. Логинимся через Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      UserCredential result;

      if (currentUser != null && currentUser.isAnonymous) {
        try {
          result = await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            result =
                await FirebaseAuth.instance.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        result = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      return result;
    } finally {
      tokenClient.close();
    }
  }
}