import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/roadhopper_themes.dart';
import '../theme/street_backdrop.dart';

/// PRO creators — custom crossing theme AND custom hopper colors.
/// [hopperMode] switches from theme colors to frog body/belly colors.
/// Live preview, persisted per color; picking a color applies the custom
/// selection automatically.
class CustomThemeScreen extends StatefulWidget {
  final HopperAudio audio;
  final HopperSettings settings;
  final bool hopperMode;

  const CustomThemeScreen({
    super.key,
    required this.audio,
    required this.settings,
    this.hopperMode = false,
  });

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  HopperThemeDef get _t => HopperThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  // Curated nature palette — no neon, no cyberpunk.
  static const List<Color> palette = [
    Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF1B5E20),
    Color(0xFF8D6E63), Color(0xFF6D4C41), Color(0xFF4E342E),
    Color(0xFF37474F), Color(0xFF546E7A), Color(0xFF263238),
    Color(0xFF0277BD), Color(0xFF0288D1), Color(0xFF01579B),
    Color(0xFFF9A825), Color(0xFFFFB300), Color(0xFFFF8F00),
    Color(0xFFEF6C00), Color(0xFFE65100), Color(0xFFBF360C),
    Color(0xFFC62828), Color(0xFFAD1457), Color(0xFF6A1B9A),
    Color(0xFF283593), Color(0xFF1565C0), Color(0xFF00838F),
    Color(0xFF00695C), Color(0xFF2E7D32), Color(0xFF558B2F),
    Color(0xFFF5F5DC), Color(0xFFE8E0C8), Color(0xFFD7CCC8),
    Color(0xFF9CCC65), Color(0xFFAED581), Color(0xFF33691E),
    Color(0xFFFFCC80), Color(0xFFFFAB91), Color(0xFFBCAAA4),
  ];

  List<(String, String)> get _rows => widget.hopperMode
      ? const [
          ('Frog body', 'hopperBody'),
          ('Frog belly', 'hopperBelly'),
        ]
      : const [
          ('Bank grass', 'bank'),
          ('Road asphalt', 'road'),
          ('River water', 'river'),
          ('Accent', 'accent'),
        ];

  Color _currentFor(String key) {
    final s = widget.settings;
    if (widget.hopperMode) {
      return key == 'hopperBody'
          ? Color(s.customHopperBody)
          : Color(s.customHopperBelly);
    }
    return Color(s.customColors[key] ?? 0xFF000000);
  }

  Future<void> _pick(String key, String label) async {
    final current = _currentFor(key);
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _t.panel,
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick $label', style: Hopper.display(20, theme: _t)),
              const SizedBox(height: 14),
              SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: palette.length,
                  itemBuilder: (_, i) {
                    final c = palette[i];
                    final selected = c.value == current.value;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop(c);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selected
                                ? _t.accentLight
                                : Colors.black.withValues(alpha: 0.4),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              StreetButton(
                label: 'Cancel',
                width: 160,
                fontSize: 15,
                theme: _t,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      widget.audio.click();
      final s = widget.settings;
      if (widget.hopperMode) {
        final body = key == 'hopperBody'
            ? chosen.value
            : s.customHopperBody;
        final belly = key == 'hopperBelly'
            ? chosen.value
            : s.customHopperBelly;
        await s.setCustomHopper(body, belly);
        await s.setHopperStyle(10);
      } else {
        await s.setCustomColor(key, chosen.value);
        await s.setTheme('custom');
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final title = widget.hopperMode ? 'Hopper Creator' : 'Theme Creator';
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
          title: Text(title, style: Hopper.display(22, theme: t)),
          centerTitle: true,
          actions: [
            if (!widget.hopperMode)
              TextButton(
                onPressed: () async {
                  widget.audio.click();
                  await s.resetCustomColors();
                  if (mounted) setState(() {});
                },
                child: Text('Reset', style: Hopper.label(13, theme: t)),
              ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Column(
                children: [
                  // Live preview.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: t.uiDeep.withValues(alpha: 0.7),
                      border: Border.all(color: t.accent, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text('Live preview',
                            style: Hopper.label(13, theme: t)),
                        const SizedBox(height: 12),
                        if (widget.hopperMode)
                          CustomPaint(
                            size: const Size(120, 120),
                            painter: _FrogPreviewPainter(
                              body: Color(s.customHopperBody),
                              belly: Color(s.customHopperBelly),
                            ),
                          )
                        else
                          _ThemePreview(theme: s.customTheme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final r in _rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: GestureDetector(
                        onTap: () => _pick(r.$2, r.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: t.uiDeep.withValues(alpha: 0.6),
                            border: Border.all(
                                color: t.accent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentFor(r.$2),
                                  border: Border.all(
                                      color: t.accentLight, width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(r.$1,
                                    style: Hopper.body(15, theme: t)),
                              ),
                              Icon(Icons.palette,
                                  color: t.accentLight, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  StreetButton(
                    label: widget.hopperMode
                        ? 'Use This Hopper'
                        : 'Use This Theme',
                    width: 260,
                    theme: t,
                    onTap: () async {
                      widget.audio.click();
                      if (widget.hopperMode) {
                        await s.setHopperStyle(10);
                      } else {
                        await s.setTheme('custom');
                      }
                      if (mounted) Navigator.of(context).pop();
                    },
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

/// Live strip preview of the custom crossing theme.
class _ThemePreview extends StatelessWidget {
  final HopperThemeDef theme;
  const _ThemePreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: theme.accent.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
              height: 44,
              color: theme.bank,
              alignment: Alignment.center,
              child: Text('Bank', style: Hopper.label(11, theme: theme))),
          Container(
              height: 30,
              color: theme.road,
              alignment: Alignment.center,
              child: Text('Road', style: Hopper.label(11, theme: theme))),
          Container(
              height: 44,
              color: theme.river,
              alignment: Alignment.center,
              child: Text('River', style: Hopper.label(11, theme: theme))),
        ],
      ),
    );
  }
}

/// Live preview of the custom frog.
class _FrogPreviewPainter extends CustomPainter {
  final Color body;
  final Color belly;
  _FrogPreviewPainter({required this.body, required this.belly});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 6);
    final r = size.width * 0.3;
    canvas.drawOval(
        Rect.fromCenter(
            center: c + const Offset(1, 5), width: r * 1.7, height: r * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.drawCircle(c, r, Paint()..color = body);
    canvas.drawCircle(c + Offset(0, r * 0.3), r * 0.62,
        Paint()..color = belly);
    for (final sd in [-1, 1]) {
      final e = c + Offset(sd * r * 0.42, -r * 0.62);
      canvas.drawCircle(e, r * 0.3, Paint()..color = Colors.white);
      canvas.drawCircle(e, r * 0.14, Paint()..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
