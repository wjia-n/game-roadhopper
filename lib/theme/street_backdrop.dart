import 'package:flutter/material.dart';
import 'roadhopper_themes.dart';

/// Road Hopper design system — roadside-diorama physicality.
/// Chunky, pressable controls with real depth: bevels, drop shadows, subtle
/// ambient occlusion. No neon, no cyberpunk, no generic Material look.
class Hopper {
  static TextStyle display(double size, {Color? color, HopperThemeDef? theme}) =>
      TextStyle(
        fontFamily: 'serif',
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? theme?.accentLight ?? const Color(0xFFFFD47A),
        letterSpacing: 1.0,
        shadows: const [
          Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, HopperThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.ivory ?? const Color(0xFFF7F3E6),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, HopperThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? theme?.accentLight ?? const Color(0xFFFFD47A),
        letterSpacing: 1.2,
      );

  static ThemeData theme([HopperThemeDef? t]) {
    t ??= HopperThemes.byId('meadow');
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.uiDeep,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: t.accent,
        onPrimary: t.uiDeep,
        secondary: t.accentLight,
        onSecondary: t.uiDeep,
        surface: t.panel,
        onSurface: t.ivory,
        error: t.carColors[0],
        onError: t.ivory,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.panel),
    );
  }
}

/// Roadside backdrop: dark asphalt-toned base with a grass-edge strip at the
/// bottom and a soft vignette — theme-aware.
class StreetBackdrop extends StatelessWidget {
  final Widget child;
  final HopperThemeDef? theme;
  const StreetBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? HopperThemes.byId('meadow');
    return Container(
      decoration: BoxDecoration(color: t.uiDeep),
      child: CustomPaint(
        painter: _StreetPainter(t),
        child: child,
      ),
    );
  }
}

class _StreetPainter extends CustomPainter {
  final HopperThemeDef t;
  _StreetPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Vignette.
    final vignette = RadialGradient(
      center: const Alignment(0, -0.3),
      radius: 1.2,
      colors: [
        t.uiMid.withValues(alpha: 0.6),
        t.uiDeep.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.55),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(Offset.zero & size,
        Paint()..shader = vignette.createShader(Offset.zero & size));
    // Faint asphalt texture dashes drifting down the sides.
    final dash = Paint()
      ..color = t.ivory.withValues(alpha: 0.05)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 8; i++) {
      final y = size.height * (i + 0.5) / 8;
      canvas.drawLine(Offset(14, y), Offset(14, y + 26), dash);
      canvas.drawLine(
          Offset(size.width - 14, y + 13), Offset(size.width - 14, y + 39), dash);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky, physically-pressable button with bevel + drop shadow.
class StreetButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final HopperThemeDef? theme;
  final IconData? icon;

  const StreetButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 250,
    this.fontSize = 19,
    this.theme,
    this.icon,
  });

  @override
  State<StreetButton> createState() => _StreetButtonState();
}

class _StreetButtonState extends State<StreetButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? HopperThemes.byId('meadow');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [t.accentLight, t.accent, t.accentDark]
                : [
                    t.panel.withValues(alpha: 0.8),
                    t.uiMid.withValues(alpha: 0.8)
                  ],
          ),
          border: Border.all(
              color: enabled
                  ? t.ivory.withValues(alpha: 0.65)
                  : t.muted.withValues(alpha: 0.4),
              width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: _pressed ? 0.0 : 0.18),
              offset: const Offset(0, 2),
              blurRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon,
                  color: enabled ? t.uiDeep : t.muted.withValues(alpha: 0.6),
                  size: widget.fontSize + 4),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: Hopper.display(widget.fontSize,
                    color: enabled
                        ? t.uiDeep
                        : t.muted.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round icon button with physical press feedback (in-game controls).
class PebbleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final HopperThemeDef? theme;
  final String? tooltip;

  const PebbleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 58,
    this.theme,
    this.tooltip,
  });

  @override
  State<PebbleButton> createState() => _PebbleButtonState();
}

class _PebbleButtonState extends State<PebbleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? HopperThemes.byId('meadow');
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.size,
        height: widget.size,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 1.1,
            colors: [t.accentLight, t.accent, t.accentDark],
          ),
          border: Border.all(
              color: t.ivory.withValues(alpha: 0.55), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: Offset(0, _pressed ? 2 : 5),
              blurRadius: _pressed ? 3 : 8,
            ),
          ],
        ),
        child: Icon(widget.icon,
            color: t.uiDeep, size: widget.size * 0.48),
      ),
    );
  }
}

/// A chunky toggle switch.
class HopperToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final HopperThemeDef? theme;
  const HopperToggle(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? HopperThemes.byId('meadow');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? t.accentDark : t.uiDeep,
          border: Border.all(color: t.accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accentLight, t.accent, t.accentDark],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A volume slider with a chunky bead thumb.
class BeadSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final HopperThemeDef? theme;
  const BeadSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? HopperThemes.byId('meadow');
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.uiDeep,
        thumbShape: _BeadThumb(t),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  final HopperThemeDef t;
  const _BeadThumb(this.t);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(center + const Offset(0, 2), 12,
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [t.accentLight, t.accent, t.accentDark],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

/// A labeled settings row.
class SettingRow extends StatelessWidget {
  final String label;
  final Widget control;
  final HopperThemeDef? theme;
  const SettingRow(
      {super.key, required this.label, required this.control, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? HopperThemes.byId('meadow');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: t.uiDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Hopper.body(16, theme: t))),
          control,
        ],
      ),
    );
  }
}

/// A section header plaque.
class SectionPlaque extends StatelessWidget {
  final String title;
  final HopperThemeDef? theme;
  const SectionPlaque({super.key, required this.title, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? HopperThemes.byId('meadow');
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: t.accent.withValues(alpha: 0.5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(title, style: Hopper.label(14, theme: t)),
          ),
          Expanded(child: Divider(color: t.accent.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}
