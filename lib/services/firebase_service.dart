// lib/services/firebase_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:game_stash/models/game.dart';
import 'package:game_stash/services/notification_service.dart';

// ─── Обработчик фоновых push (top-level, обязательно) ───────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.notification?.title}');
}

class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _analytics = FirebaseAnalytics.instance;
  final _messaging = FirebaseMessaging.instance;
  final _googleSignIn = GoogleSignIn();

  StreamSubscription<QuerySnapshot>? _syncSubscription;
  void Function(List<Game>)? onRemoteGamesUpdated;

  // ── Инициализация ──────────────────────────────────────────────────────────

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _setupFCM();

    if (_auth.currentUser != null) {
      _startSync();
    }

    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _startSync();
      } else {
        _stopSync();
      }
    });
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn =>
      _auth.currentUser != null && !(_auth.currentUser!.isAnonymous);
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Войти через Google.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final current = _auth.currentUser;
      UserCredential result;
      if (current != null && current.isAnonymous) {
        try {
          result = await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            result = await _auth.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        result = await _auth.signInWithCredential(credential);
      }

      await logEvent('sign_in', {'method': 'google'});
      return result;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return null;
    }
  }

  /// Войти через Email + пароль.
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await logEvent('sign_in', {'method': 'email'});
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email sign-in error: ${e.code}');
      rethrow; // Прокидываем чтобы показать ошибку в UI
    }
  }

  /// Зарегистрироваться через Email + пароль.
  Future<UserCredential?> registerWithEmail(
      String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await logEvent('sign_up', {'method': 'email'});
      return result;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email register error: ${e.code}');
      rethrow;
    }
  }

  /// Сбросить пароль.
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    _stopSync();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Firestore: синхронизация коллекции ────────────────────────────────────

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _gamesCollection {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('games');
  }

  Future<List<Game>> fetchRemoteGames() async {
    final col = _gamesCollection;
    if (col == null) return [];
    try {
      final snapshot = await col.get();
      return snapshot.docs
          .map((doc) => Game.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Firestore fetch error: $e');
      return [];
    }
  }

  Future<void> uploadGames(List<Game> games) async {
    final col = _gamesCollection;
    if (col == null) return;
    try {
      final batch = _firestore.batch();
      for (final game in games) {
        final ref = col.doc(game.id.toString());
        batch.set(ref, game.toFirestore());
      }
      await batch.commit();
      await logEvent('games_uploaded', {'count': games.length});
    } catch (e) {
      debugPrint('Firestore upload error: $e');
    }
  }

  Future<void> updateGame(Game game) async {
    final col = _gamesCollection;
    if (col == null) return;
    try {
      if (game.status == GameStatus.none) {
        await col.doc(game.id.toString()).delete();
      } else {
        await col.doc(game.id.toString()).set(game.toFirestore());
      }
    } catch (e) {
      debugPrint('Firestore update error: $e');
    }
  }

  void _startSync() {
    _stopSync();
    final col = _gamesCollection;
    if (col == null) return;

    _syncSubscription = col.snapshots().listen((snapshot) {
      final games = snapshot.docs
          .map((doc) => Game.fromFirestore(doc.data()))
          .toList();
      onRemoteGamesUpdated?.call(games);
    }, onError: (e) {
      debugPrint('Firestore sync error: $e');
    });
  }

  void _stopSync() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
  }

  // ── FCM ───────────────────────────────────────────────────────────────────

  Future<void> _setupFCM() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    _messaging.onTokenRefresh.listen(_saveFCMToken);

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        NotificationService.instance.sendImmediateNotification(
          id: message.hashCode,
          title: notification.title ?? 'PlayStash',
          body: notification.body ?? '',
          channelId: 'fcm_channel',
          channelName: 'Push-уведомления',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM tap: ${message.data}');
    });
  }

  Future<void> _saveFCMToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).set(
        {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  // ── Analytics ─────────────────────────────────────────────────────────────

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  Future<void> logGameStatusChanged(Game game, GameStatus status) async {
    await logEvent('game_status_changed', {
      'game_id': game.id,
      'game_title': game.title,
      'status': status.name,
    });
  }

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logSearch(String query) async {
    await _analytics.logSearch(searchTerm: query);
  }

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);
}