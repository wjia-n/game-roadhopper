import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/roadhopper_themes.dart';
import '../theme/street_backdrop.dart';

/// Road Hopper PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final HopperAudio audio;
  final HopperSettings settings;
  final HopperStore store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  HopperThemeDef get _t => HopperThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.lastThanks.addListener(_onThanks);
  }

  
  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Hopper.body(15, theme: _t)),
        backgroundColor: _t.uiDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _IosGoldStarScreen(store: widget.store);
    }
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
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
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Road Hopper PRO', style: Hopper.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                                    _TipsCard(
                    theme: t,
                    store: store,
                    audio: widget.audio,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.


// ---------------------------------------------------------------------------
class _TipsCard extends StatelessWidget {
  final HopperThemeDef theme;
  final HopperStore store;
  final HopperAudio audio;
  const _TipsCard(
      {required this.theme, required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    final tips = [
      store.coffeeProduct,
      store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.uiDeep.withValues(alpha: 0.75),
        border: Border.all(color: theme.accent, width: 2),
      ),
      child: Column(
        children: [
          Text('Tip the Maker', style: Hopper.display(20, theme: theme)),
          const SizedBox(height: 8),
          Text(
            'Road Hopper is free forever. A small tip keeps new games coming!',
            style: Hopper.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: Hopper.body(13,
                  theme: theme,
                  color: theme.ivory.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            )
          else if (tips.isEmpty)
            Text('Tips coming soon.',
                style: Hopper.body(13,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.6)))
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _TipChip(
                    theme: theme,
                    label:
                        '${p.id == HopperStore.chocolateId ? '🍫' : '☕'} ${p.price}',
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final HopperThemeDef theme;
  final String label;
  final VoidCallback onTap;
  const _TipChip(
      {required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(
              color: theme.accent.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Text(label, style: Hopper.label(14, theme: theme)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// iOS-only Gold Star screen: exactly one button, plus a badge once owned.
/// The game stays fully unlocked; the star is cosmetic only.
/// Android keeps the original screen below, byte-identical.
class _IosGoldStarScreen extends StatelessWidget {
  final HopperStore store;
  const _IosGoldStarScreen({required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Gold Star'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'This game is fully unlocked.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: store.goldStarOwned,
                  builder: (_, owned, _) => Text(
                    owned
                        ? '⭐ Gold Star earned — thank you!'
                        : 'Get a Gold Star to show your support!',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                if (!store.storeReady)
                  Text(store.error ?? 'Available after store setup.',
                      textAlign: TextAlign.center)
                else if (store.starProduct == null)
                  const Text('Gold Star coming soon.',
                      textAlign: TextAlign.center)
                else
                  ValueListenableBuilder<bool>(
                    valueListenable: store.goldStarOwned,
                    builder: (_, owned, _) => owned
                        ? const Text('⭐', style: TextStyle(fontSize: 48))
                        : ElevatedButton(
                            onPressed: () =>
                                store.buyStar(store.starProduct!),
                            child: Text(
                                '⭐ Gold Star ${store.starProduct!.price}'),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
