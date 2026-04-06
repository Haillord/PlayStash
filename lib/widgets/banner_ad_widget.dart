import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import 'dart:async';

const _kBannerAdUnitId = 'R-M-18710519-1';
const _kBannerHiddenUntilKey = 'banner_hidden_until_ms';
const _kBannerHideDuration = Duration(minutes: 2);
const _kCloseButtonDelay = Duration(seconds: 30);

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isVisibilityReady = false;
  bool _isTemporarilyHidden = false;
  bool _canClose = false;

  Timer? _closeButtonTimer;
  Timer? _unhideTimer;

  @override
  void initState() {
    super.initState();
    _restoreVisibilityState();
  }

  int? _cachedScreenWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newWidth = MediaQuery.of(context).size.width.toInt();
    // Загружаем баннер только один раз (или при реальном изменении ширины экрана).
    // Без этой проверки didChangeDependencies вызывал _loadBanner при каждом
    // изменении MediaQuery (системные бары, клавиатура и т.п.).
    if (_isVisibilityReady && !_isTemporarilyHidden && _bannerAd == null) {
      if (_cachedScreenWidth == null || _cachedScreenWidth != newWidth) {
        _cachedScreenWidth = newWidth;
        _loadBanner();
      }
    }
  }

  Future<void> _restoreVisibilityState() async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenUntilMs = prefs.getInt(_kBannerHiddenUntilKey);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (hiddenUntilMs != null && hiddenUntilMs > nowMs) {
      final remaining = Duration(milliseconds: hiddenUntilMs - nowMs);
      _scheduleUnhide(remaining);
      if (mounted) {
        setState(() {
          _isTemporarilyHidden = true;
          _isVisibilityReady = true;
        });
      }
      return;
    }

    await prefs.remove(_kBannerHiddenUntilKey);
    if (mounted) {
      setState(() {
        _isTemporarilyHidden = false;
        _isVisibilityReady = true;
      });
      if (_bannerAd == null) {
        _loadBanner();
      }
    }
  }

  void _scheduleUnhide(Duration duration) {
    _unhideTimer?.cancel();
    _unhideTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _isTemporarilyHidden = false;
      });
      if (_bannerAd == null) {
        _loadBanner();
      }
    });
  }

  void _loadBanner() {
    // Используем закешированную ширину — не читаем MediaQuery повторно.
    final screenWidth = _cachedScreenWidth ?? MediaQuery.of(context).size.width.toInt();

    // В Yandex SDK для Flutter создание объекта BannerAd 
    // с колбэками уже инициирует процесс загрузки.
    _bannerAd = BannerAd(
      adUnitId: _kBannerAdUnitId,
      adSize: BannerAdSize.sticky(width: screenWidth),
      adRequest: const AdRequest(),
      onAdLoaded: () {
        if (!mounted) return;
        _closeButtonTimer?.cancel();
        _closeButtonTimer = Timer(_kCloseButtonDelay, () {
          if (mounted) setState(() => _canClose = true);
        });
        setState(() => _isLoaded = true);
      },
      onAdFailedToLoad: (error) {
        debugPrint('Banner error: ${error.description}');
        if (mounted) {
          setState(() {
            _isLoaded = false;
            _canClose = false;
          });
        }
      },
    );
  }

  Future<void> _hideTemporarily() async {
    final hiddenUntil = DateTime.now().add(_kBannerHideDuration);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBannerHiddenUntilKey, hiddenUntil.millisecondsSinceEpoch);

    _closeButtonTimer?.cancel();
    _bannerAd?.destroy();
    _bannerAd = null;

    if (mounted) {
      setState(() {
        _isTemporarilyHidden = true;
        _isLoaded = false;
        _canClose = false;
      });
    }
    _scheduleUnhide(_kBannerHideDuration);
  }

  @override
  void dispose() {
    _closeButtonTimer?.cancel();
    _unhideTimer?.cancel();
    _bannerAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisibilityReady || _isTemporarilyHidden || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: _isLoaded ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: AdWidget(bannerAd: _bannerAd!),
              ),
              if (_isLoaded && _canClose)
                Positioned(
                  top: 2,
                  right: 2,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _hideTemporarily,
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}