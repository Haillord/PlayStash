// lib/screens/auth_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_stash/providers/auth_provider.dart';
import 'package:game_stash/services/firebase_service.dart';
import 'package:game_stash/utils/constants.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(authUserProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      backgroundColor: isDark ? kBgColorDark : kBgColorLight,
      appBar: AppBar(
        title: const Text('Аккаунт'),
        backgroundColor: isDark ? kBgColorDark : kCardColorLight,
        foregroundColor: isDark ? kTextColorDark : kTextColorLight,
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) {
          if (user != null && !user.isAnonymous) {
            return _SignedInView(
              displayName: user.displayName ?? user.email ?? 'Пользователь',
              email: user.email ?? '',
              photoUrl: user.photoURL,
              syncStatus: syncStatus,
              isDark: isDark,
              onSignOut: () async {
                await FirebaseService.instance.signOut();
                if (mounted) Navigator.pop(context);
              },
            );
          }
          return _SignInView(isDark: isDark);
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: kAccent)),
        error: (_, __) =>
            const Center(child: Text('Ошибка загрузки')),
      ),
    );
  }
}

// ── Форма входа / регистрации ─────────────────────────────────────────────────

class _SignInView extends StatefulWidget {
  final bool isDark;
  const _SignInView({required this.isDark});

  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false; // false = вход, true = регистрация
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isRegister) {
        await FirebaseService.instance.registerWithEmail(email, pass);
      } else {
        await FirebaseService.instance.signInWithEmail(email, pass);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = _authError(e.code));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await FirebaseService.instance.signInWithGoogle();
    if (mounted) setState(() => _loading = false);
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Пользователь не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      case 'email-already-in-use':
        return 'Email уже используется';
      case 'weak-password':
        return 'Слишком простой пароль (минимум 6 символов)';
      case 'invalid-email':
        return 'Неверный формат email';
      case 'too-many-requests':
        return 'Слишком много попыток. Попробуй позже';
      default:
        return 'Ошибка: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.cloud_sync_rounded,
            size: 72,
            color: kAccent.withValues(alpha: 0.75),
          ),
          const SizedBox(height: 20),
          Text(
            'Синхронизация коллекции',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? kTextColorDark : kTextColorLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Твоя коллекция будет доступна\nна всех устройствах',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? kTextColorSecondaryDark : kTextColorSecondaryLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // ── Google ────────────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _loading ? null : _submitGoogle,
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Войти через Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: Divider(
                      color: isDark ? kBorderColorDark : kBorderColorLight)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('или',
                    style: TextStyle(
                        color: isDark
                            ? kTextColorSecondaryDark
                            : kTextColorSecondaryLight,
                        fontSize: 13)),
              ),
              Expanded(
                  child: Divider(
                      color: isDark ? kBorderColorDark : kBorderColorLight)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Email ─────────────────────────────────────────────────────────
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('Email', isDark),
            style:
                TextStyle(color: isDark ? kTextColorDark : kTextColorLight),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: _inputDecoration('Пароль', isDark).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: isDark ? kTextColorSecondaryDark : kTextColorSecondaryLight,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            style:
                TextStyle(color: isDark ? kTextColorDark : kTextColorLight),
            onSubmitted: (_) => _submitEmail(),
          ),

          // ── Ошибка ────────────────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kErrorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: kErrorColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(_error!,
                  style:
                      const TextStyle(color: kErrorColor, fontSize: 13)),
            ),
          ],

          const SizedBox(height: 16),

          // ── Кнопка входа / регистрации ────────────────────────────────────
          if (_loading)
            const Center(child: CircularProgressIndicator(color: kAccent))
          else
            ElevatedButton(
              onPressed: _submitEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? kSurfaceColorDark : kSurfaceColorLight,
                foregroundColor: isDark ? kTextColorDark : kTextColorLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: isDark ? kBorderColorDark : kBorderColorLight),
                ),
              ),
              child: Text(
                  _isRegister ? 'Зарегистрироваться' : 'Войти по Email'),
            ),

          // ── Переключение вход / регистрация ───────────────────────────────
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _isRegister = !_isRegister;
              _error = null;
            }),
            child: Text(
              _isRegister
                  ? 'Уже есть аккаунт? Войти'
                  : 'Нет аккаунта? Зарегистрироваться',
              style: TextStyle(
                  color: kAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),

          // ── Сброс пароля ──────────────────────────────────────────────────
          if (!_isRegister)
            TextButton(
              onPressed: () async {
                final email = _emailCtrl.text.trim();
                if (email.isEmpty) {
                  setState(() => _error = 'Введи email для сброса пароля');
                  return;
                }
                await FirebaseService.instance.resetPassword(email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Письмо для сброса пароля отправлено'),
                  ));
                }
              },
              child: Text(
                'Забыл пароль?',
                style: TextStyle(
                    color: isDark
                        ? kTextColorSecondaryDark
                        : kTextColorSecondaryLight,
                    fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color:
              isDark ? kTextColorSecondaryDark : kTextColorSecondaryLight),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: isDark ? kBorderColorDark : kBorderColorLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: isDark ? kBorderColorDark : kBorderColorLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
    );
  }
}

// ── Вид "вошёл" ───────────────────────────────────────────────────────────────

class _SignedInView extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final SyncStatus syncStatus;
  final bool isDark;
  final VoidCallback onSignOut;

  const _SignedInView({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.syncStatus,
    required this.isDark,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 48,
            backgroundColor: kAccent.withValues(alpha: 0.2),
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? const Icon(Icons.person, size: 48, color: kAccent)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? kTextColorDark : kTextColorLight,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? kTextColorSecondaryDark
                    : kTextColorSecondaryLight,
              ),
            ),
          ],
          const SizedBox(height: 32),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _syncIcon(syncStatus),
                const SizedBox(width: 12),
                Text(
                  _syncLabel(syncStatus),
                  style: TextStyle(
                      color: isDark ? kTextColorDark : kTextColorLight),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, color: kErrorColor),
              label: const Text('Выйти из аккаунта',
                  style: TextStyle(color: kErrorColor)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kErrorColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _syncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
        );
      case SyncStatus.done:
        return const Icon(Icons.cloud_done, color: kSuccessColor, size: 20);
      case SyncStatus.error:
        return const Icon(Icons.cloud_off, color: kErrorColor, size: 20);
      default:
        return const Icon(Icons.cloud_outlined, color: kAccent, size: 20);
    }
  }

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Синхронизация...';
      case SyncStatus.done:
        return 'Коллекция синхронизирована';
      case SyncStatus.error:
        return 'Ошибка синхронизации';
      default:
        return 'Синхронизация включена';
    }
  }
}