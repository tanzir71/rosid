import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';

enum RosidButtonKind { primary, tonal, outline, ghost }

/// Standard Mohor action button (52 px high, 12 px radius).
class RosidButton extends StatelessWidget {
  const RosidButton({
    required this.label,
    required this.onPressed,
    this.kind = RosidButtonKind.primary,
    this.icon,
    this.expand = false,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final RosidButtonKind kind;
  final RosidIcons? icon;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final disabled = onPressed == null || busy;

    final Color bg;
    final Color fg;
    final BorderSide? border;

    switch (kind) {
      case RosidButtonKind.primary:
        bg = disabled ? c.lineSubtle : c.accentBase;
        fg = disabled ? c.inkTertiary : c.inkOnAccent;
        border = null;
      case RosidButtonKind.tonal:
        bg = disabled ? c.bgSunken : c.accentSoft;
        fg = disabled ? c.inkTertiary : c.accentInk;
        border = null;
      case RosidButtonKind.outline:
        bg = c.bgSheet;
        fg = disabled ? c.inkTertiary : c.inkPrimary;
        border = BorderSide(color: disabled ? c.lineSubtle : c.lineStrong);
      case RosidButtonKind.ghost:
        bg = Colors.transparent;
        fg = disabled ? c.inkTertiary : c.accentBase;
        border = null;
    }

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          RosidIcon(icon!, size: 20, color: fg),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RosidTextTokens.uiBodyStrong.copyWith(color: fg),
          ),
        ),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 52,
        minWidth: expand ? double.infinity : 48,
      ),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          side: border ?? BorderSide.none,
        ),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Selectable filter or option chip (36 px high, pill radius).
class RosidChip extends StatelessWidget {
  const RosidChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final RosidIcons? icon;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final bg = selected ? c.accentSoft : c.bgSheet;
    final fg = selected ? c.accentInk : c.inkPrimary;
    final border = selected ? c.accentBase : c.lineSubtle;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38, minWidth: 48),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  RosidIcon(icon!, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(label, style: RosidTextTokens.uiLabel.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum RosidTone { neutral, accent, good, warn, bad }

/// Compact status pill (neutral, accent, good, warn, bad).
class RosidPill extends StatelessWidget {
  const RosidPill({
    required this.label,
    this.tone = RosidTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final RosidTone tone;
  final RosidIcons? icon;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final (bg, fg) = switch (tone) {
      RosidTone.neutral => (c.bgSunken, c.inkSecondary),
      RosidTone.accent => (c.accentSoft, c.accentInk),
      RosidTone.good => (c.goodSoft, c.goodBase),
      RosidTone.warn => (c.warnSoft, c.warnBase),
      RosidTone.bad => (c.badSoft, c.badBase),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              RosidIcon(icon!, size: 14, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: RosidTextTokens.uiMicro.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum RosidStampTone { accent, good, bad }

/// Office rubber stamp motif (DRAFT, SAVED, WORKS OFFLINE).
/// Use sparingly: at most one stamp per screen.
class RosidStamp extends StatelessWidget {
  const RosidStamp({
    required this.label,
    this.tone = RosidStampTone.accent,
    this.angleRadians = -0.07,
    super.key,
  });

  final String label;
  final RosidStampTone tone;
  final double angleRadians;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final color = switch (tone) {
      RosidStampTone.accent => c.accentBase,
      RosidStampTone.good => c.goodBase,
      RosidStampTone.bad => c.badBase,
    };

    return Transform.rotate(
      angle: angleRadians,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPaper),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                label.toUpperCase(),
                style: RosidTextTokens.uiStamp.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
