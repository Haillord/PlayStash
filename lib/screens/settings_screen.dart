import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_tracker/providers/providers.dart';
import 'package:game_tracker/services/api_service.dart';
import 'package:game_tracker/services/storage_service.dart';
import 'package:game_tracker/theme/app_theme.dart';
import 'package:game_tracker/utils/constants.dart';
import 'package:game_tracker/widgets/glass_app_bar.dart';

// ─── Константы секции ─────────────────────────────────────────────────────────
const _kSectionAlphaLight = 0.4;
const _kSectionAlphaDark = 0.08;
const _kSectionBorderAlphaLight = 0.6;
const _kSectionBorderAlphaDark = 0.15;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Синхронный — SharedPreferences уже в памяти после init()
  late String _cacheSize;

  OverlayEntry? _rippleOverlay;

  @override
  void initState() {
    super.initState();
    _cacheSize = _readCacheSize();
  }

  // ── Подсчёт размера кэша ─────────────────────────────────────────────────
  String _readCacheSize() {
    final bytes = LocalStorageService.getCacheSize();
    if (bytes == 0) return '0 МБ';
    final mb = bytes / 1024 / 1024;
    if (mb < 0.1) return '${(bytes / 1024).toStringAsFixed(0)} КБ';
    return '${mb.toStringAsFixed(1)} МБ';
  }

  // ── Очистка кэша: диалог подтверждения + try/catch ───────────────────────
  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Strings.clearCache),
        content: Text('${Strings.cacheDeleted} ($_cacheSize)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              Strings.clear,
              style: TextStyle(color: kErrorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await LocalStorageService.clearCache();
      await GameRepository.clearAllCaches();
      if (mounted) {
        setState(() => _cacheSize = '0 МБ');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.cacheCleared),
            backgroundColor: kSuccessColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Strings.errorClearCache}: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Экспорт коллекции с try/catch ────────────────────────────────────────
  Future<void> _exportCollection() async {
    try {
      final games = await LocalStorageService.getMyGames();
      if (mounted) {
        await LocalStorageService.exportCollection(context, games);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Strings.errorExport}: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Ripple-анимация при переключении темы ────────────────────────────────
  Future<void> _toggleThemeWithRipple(Offset tapPosition) async {
    HapticFeedback.lightImpact();

    final isDark = ref.read(themeModeProvider) == AppThemeMode.dark;
    final rippleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final size = MediaQuery.of(context).size;
    final maxRadius = [
      tapPosition.distance,
      Offset(size.width - tapPosition.dx, tapPosition.dy).distance,
      Offset(tapPosition.dx, size.height - tapPosition.dy).distance,
      Offset(size.width - tapPosition.dx, size.height - tapPosition.dy).distance,
    ].reduce((a, b) => a > b ? a : b) * 1.1;

    _rippleOverlay = OverlayEntry(
      builder: (_) => _RippleOverlay(
        origin: tapPosition,
        color: rippleColor,
        maxRadius: maxRadius,
        onComplete: () {
          _rippleOverlay?.remove();
          _rippleOverlay = null;
        },
      ),
    );

    Overlay.of(context).insert(_rippleOverlay!);

    await Future.delayed(const Duration(milliseconds: 180));
    ref.read(themeModeProvider.notifier).toggle();
  }

  @override
  void dispose() {
    _rippleOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == AppThemeMode.dark;

    final textColor = isDark ? Colors.white : kTextColorLight;
    final textColorSecondary =
        isDark ? Colors.white70 : kTextColorSecondaryLight;

    return Scaffold(
      appBar: GlassAppBar(title: Strings.settings, isDark: isDark),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewPadding.bottom + 16,
        ),
        children: [
          // ── Внешний вид ────────────────────────────────────────────────
          _buildSection(
            title: Strings.appearance,
            isDark: isDark,
            children: [
              GestureDetector(
                onTapDown: (d) => _toggleThemeWithRipple(d.globalPosition),
                child: AbsorbPointer(
                  child: SwitchListTile(
                    title: Text(Strings.darkTheme,
                        style: TextStyle(color: textColor)),
                    subtitle: Text(Strings.themeToggle,
                        style: TextStyle(color: textColorSecondary)),
                    value: isDark,
                    onChanged: (_) {},
                    activeColor: kNeonGreen,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Данные ─────────────────────────────────────────────────────
          _buildSection(
            title: Strings.data,
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: kErrorColor),
                title: Text(Strings.clearCache,
                    style: TextStyle(color: textColor)),
                subtitle: Text(
                  '${Strings.cacheDeleted} · $_cacheSize',
                  style: TextStyle(color: textColorSecondary),
                ),
                onTap: _clearCache,
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: const Icon(Icons.backup, color: kNeonGreen),
                title: Text(Strings.exportCollection,
                    style: TextStyle(color: textColor)),
                subtitle: Text(Strings.saveCollection,
                    style: TextStyle(color: textColorSecondary)),
                onTap: _exportCollection,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── О приложении ───────────────────────────────────────────────
          _buildSection(
            title: Strings.aboutApp,
            isDark: isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.info, color: kNeonGreen),
                title: Text(Strings.version,
                    style: TextStyle(color: textColor)),
                subtitle: Text(Strings.versionInfo,
                    style: TextStyle(color: textColorSecondary)),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: const Icon(Icons.api, color: kNeonPurple),
                title: Text(Strings.dataSources,
                    style: TextStyle(color: textColor)),
                subtitle: Text(Strings.dataSourcesInfo,
                    style: TextStyle(color: textColorSecondary)),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: isDark ? _kSectionAlphaDark : _kSectionAlphaLight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: isDark
                ? _kSectionBorderAlphaDark
                : _kSectionBorderAlphaLight,
          ),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : kTextColorLight,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

// ─── Ripple overlay ───────────────────────────────────────────────────────────
class _RippleOverlay extends StatefulWidget {
  final Offset origin;
  final Color color;
  final double maxRadius;
  final VoidCallback onComplete;

  const _RippleOverlay({
    required this.origin,
    required this.color,
    required this.maxRadius,
    required this.onComplete,
  });

  @override
  State<_RippleOverlay> createState() => _RippleOverlayState();
}

class _RippleOverlayState extends State<_RippleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _radius;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _radius = Tween<double>(begin: 0, end: widget.maxRadius).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    // Волна начинает гаснуть на 60% анимации
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );
    _ctrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _RipplePainter(
          origin: widget.origin,
          color: widget.color,
          radius: _radius.value,
          opacity: _opacity.value,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Offset origin;
  final Color color;
  final double radius;
  final double opacity;

  const _RipplePainter({
    required this.origin,
    required this.color,
    required this.radius,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(origin, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.radius != radius || old.opacity != opacity;
}