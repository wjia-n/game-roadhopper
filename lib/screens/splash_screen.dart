import 'dart:async';

import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/roadhopper_themes.dart';
import '../theme/street_backdrop.dart';
import 'menu_screen.dart';

/// Launch splash — ONE screen, two moments:
/// 1. WAJIHA company moment (official logo, untouched) — brief beat.
/// 2. Game splash: logo + name + animated loading line + "Credits: WAJIHA".
class SplashScreen extends StatefulWidget {
  final HopperAudio audio;
  final HopperSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    unawaited(widget.audio.prewarm());
    unawaited(widget.audio.startMenuMusic());
    // Moment 1: the company beat.
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _companyDone = true);
    // Moment 2: the game splash with the animated loading line.
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = HopperThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.uiDeep,
      body: StreetBackdrop(
        theme: theme,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _companyDone
                ? _gameSplash(theme, key: const ValueKey('game'))
                : _companySplash(theme, key: const ValueKey('company')),
          ),
        ),
      ),
    );
  }

  /// Moment 1: the official WAJIHA company logo, untouched, full attention.
  Widget _companySplash(HopperThemeDef theme, {Key? key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/wajiha_logo.png',
          width: 170,
          height: 170,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 18),
        Text('WAJIHA', style: Hopper.display(34, theme: theme)),
      ],
    );
  }

  /// Moment 2: game logo + name + animated loading line + credits.
  Widget _gameSplash(HopperThemeDef theme, {Key? key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: theme.accent, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 10),
                blurRadius: 24,
              ),
              BoxShadow(
                color: theme.accentLight.withValues(alpha: 0.25),
                offset: const Offset(0, -2),
                blurRadius: 6,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child:
              Image.asset('assets/roadhopper_logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(height: 22),
        Text('Road Hopper', style: Hopper.display(46, theme: theme)),
        const SizedBox(height: 6),
        Text(
          'DODGE · RIDE · HOP HOME',
          style: Hopper.label(13, theme: theme),
        ),
        const SizedBox(height: 30),
        // Animated loading line.
        SizedBox(
          width: 220,
          child: AnimatedBuilder(
            animation: _loader,
            builder: (_, _) => Column(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.black.withValues(alpha: 0.45),
                    border: Border.all(
                        color: theme.accent.withValues(alpha: 0.5)),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loader.value.clamp(0.02, 1.0).toDouble(),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            theme.accentLight,
                            theme.accent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _loader.value < 1 ? 'Warming up the asphalt…' : 'Ready!',
                  style: Hopper.body(13,
                      theme: theme,
                      color: theme.ivory.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 44),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/wajiha_logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              'Credits: WAJIHA',
              style: Hopper.label(14, theme: theme),
            ),
          ],
        ),
      ],
    );
  }
}
