import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/roadhopper_themes.dart';
import '../theme/street_backdrop.dart';
import 'pro_screen.dart';

/// Settings — sound, PRO, appearance, support, about. Theme-aware.
class SettingsScreen extends StatefulWidget {
  final HopperAudio audio;
  final HopperSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final HopperStore _store = HopperStore();

  HopperThemeDef get _t => HopperThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.proPurchased.addListener(_onPro);
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      _store.proPurchased.value = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: widget.audio,
        settings: widget.settings,
        store: _store,
      ),
    ))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final audio = widget.audio;
    return StreetBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Hopper.display(22, theme: t)),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Sound', t),
                SettingRow(
                  theme: t,
                  label: 'Music',
                  control: HopperToggle(
                    theme: t,
                    value: s.musicOn,
                    onChanged: (v) async {
                      audio.click();
                      await s.setMusic(v);
                      audio.configure(
                          musicOn: s.musicOn,
                          sfxOn: s.sfxOn,
                          volume: s.volume);
                      if (v) {
                        audio.startMenuMusic();
                      } else {
                        audio.stopMusic();
                      }
                    },
                  ),
                ),
                SettingRow(
                  theme: t,
                  label: 'Sound effects',
                  control: HopperToggle(
                    theme: t,
                    value: s.sfxOn,
                    onChanged: (v) async {
                      await s.setSfx(v);
                      audio.configure(
                          musicOn: s.musicOn,
                          sfxOn: s.sfxOn,
                          volume: s.volume);
                      if (v) audio.click();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text('Volume', style: Hopper.body(16, theme: t)),
                BeadSlider(
                  theme: t,
                  value: s.volume,
                  onChanged: (v) async {
                    await s.setVolume(v);
                    audio.configure(
                        musicOn: s.musicOn,
                        sfxOn: s.sfxOn,
                        volume: s.volume);
                  },
                ),
                const SizedBox(height: 10),
                _SectionTitle('Road Hopper PRO', t),
                SettingRow(
                  theme: t,
                  label: s.isPro ? 'PRO active ✦' : 'Unlock PRO',
                  control: GestureDetector(
                    onTap: _openPro,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: s.isPro
                            ? t.accent.withValues(alpha: 0.85)
                            : Colors.black.withValues(alpha: 0.3),
                        border:
                            Border.all(color: t.accentLight, width: 2),
                      ),
                      child: Text(
                        s.isPro ? '✦ PRO' : 'View',
                        style: Hopper.label(13,
                            theme: t,
                            color: s.isPro ? t.uiDeep : t.ivory),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('Appearance', t),
                Text('Crossing theme', style: Hopper.body(16, theme: t)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final th in HopperThemes.all)
                      GestureDetector(
                        onTap: () async {
                          audio.click();
                          final locked = HopperThemes.isProTheme(th.id) &&
                              !s.isPro;
                          if (locked) {
                            _openPro();
                            return;
                          }
                          await s.setTheme(th.id);
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: s.themeId == th.id
                                      ? th.accentLight
                                      : th.accent.withValues(alpha: 0.3),
                                  width: s.themeId == th.id ? 3 : 1.5,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Expanded(
                                      flex: 3,
                                      child: Container(color: th.bank)),
                                  Expanded(
                                      flex: 2,
                                      child: Container(color: th.road)),
                                  Expanded(
                                      flex: 3,
                                      child: Container(color: th.river)),
                                ],
                              ),
                            ),
                            if (HopperThemes.isProTheme(th.id) &&
                                !s.isPro)
                              Container(
                                width: 64,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black
                                      .withValues(alpha: 0.55),
                                ),
                                child: Icon(Icons.lock,
                                    color: t.accentLight, size: 18),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Hopper style', style: Hopper.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final st in HopperStyles.all)
                      _MiniChip(
                        theme: t,
                        label:
                            '${HopperStyles.isPro(st.id) && !s.isPro ? '🔒 ' : ''}${st.name}',
                        selected: s.hopperStyle == st.id,
                        onTap: () async {
                          audio.click();
                          if (HopperStyles.isPro(st.id) && !s.isPro) {
                            _openPro();
                            return;
                          }
                          await s.setHopperStyle(st.id);
                        },
                      ),
                    _MiniChip(
                      theme: t,
                      label: '${!s.isPro ? '🔒 ' : ''}My Hopper',
                      selected: s.hopperStyle == 10,
                      onTap: () async {
                        audio.click();
                        if (!s.isPro) {
                          _openPro();
                          return;
                        }
                        await s.setHopperStyle(10);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionTitle('Support', t),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: t.uiDeep.withValues(alpha: 0.65),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Road Hopper is 100% free. Tips keep the hops coming!',
                        style: Hopper.body(14, theme: t),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Builder(builder: (_) {
                        final tips = [
                          _store.coffeeProduct,
                          _store.chocolateProduct,
                        ].whereType<ProductDetails>().toList();
                        if (!_store.storeReady) {
                          return Text(
                            _store.error ?? 'Loading…',
                            style: Hopper.body(13,
                                theme: t,
                                color: t.ivory.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                          );
                        }
                        if (tips.isEmpty) {
                          return Text('Tips coming soon.',
                              style: Hopper.body(13,
                                  theme: t,
                                  color: t.ivory.withValues(alpha: 0.6)));
                        }
                        return Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in tips)
                              _MiniChip(
                                theme: t,
                                label: p.id == HopperStore.chocolateId
                                    ? '🍫 ${p.price}'
                                    : '☕ ${p.price}',
                                selected: false,
                                onTap: () {
                                  audio.click();
                                  _store.buyTip(p);
                                },
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('About', t),
                Text(
                  'Road Hopper — the roadside crossing arcade.\nVersion 1.0.0 • Made with 💚 by WAJIHA',
                  style: Hopper.body(13,
                      theme: t, color: t.ivory.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final HopperThemeDef theme;
  const _SectionTitle(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: Hopper.display(19, theme: theme)),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final HopperThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MiniChip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Hopper.label(13,
              theme: theme,
              color: selected ? theme.uiDeep : theme.ivory),
        ),
      ),
    );
  }
}
