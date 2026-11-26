import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';

enum RosidFieldState { standard, check }

/// Mohor text field (52 px high, 12 px radius, supports default and check states).
class RosidField extends StatelessWidget {
  const RosidField({
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.fieldState = RosidFieldState.standard,
    this.leadingIcon,
    this.trailing,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final RosidFieldState fieldState;
  final RosidIcons? leadingIcon;
  final Widget? trailing;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final isCheck = fieldState == RosidFieldState.check;
    final fillColor = isCheck ? c.warnSoft : c.bgSheet;
    final borderColor = isCheck ? c.warnBase : c.lineSubtle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: RosidTextTokens.uiLabel.copyWith(color: c.inkSecondary),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          keyboardType: keyboardType,
          maxLines: maxLines,
          obscureText: obscureText,
          style: RosidTextTokens.uiBody.copyWith(color: c.inkPrimary),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: fillColor,
            prefixIcon: leadingIcon != null
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: RosidIcon(
                      leadingIcon!,
                      size: 20,
                      color: c.inkSecondary,
                    ),
                  )
                : null,
            suffixIcon: trailing,
            constraints: const BoxConstraints(minHeight: 52),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                RosidSizeTokens.radiusControl,
              ),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                RosidSizeTokens.radiusControl,
              ),
              borderSide: BorderSide(
                color: borderColor,
                width: isCheck ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                RosidSizeTokens.radiusControl,
              ),
              borderSide: BorderSide(
                color: isCheck ? c.warnBase : c.accentBase,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: RosidTextTokens.uiCaption.copyWith(
              color: isCheck ? c.warnBase : c.inkSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Mohor toggle switch with 48x48 minimum touch target.
class RosidToggle extends StatelessWidget {
  const RosidToggle({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final enabled = onChanged != null;
    final trackColor = value
        ? (enabled ? c.accentBase : c.lineSubtle)
        : c.bgSunken;
    final borderColor = value ? Colors.transparent : c.lineStrong;

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
        child: SizedBox(
          width: 56,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
                border: Border.all(color: borderColor),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? c.inkOnAccent : c.bgSheet,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mohor radio indicator (22 px visual ring inside a 48x48 touch area when tappable).
class RosidRadio extends StatelessWidget {
  const RosidRadio({
    required this.selected,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final ring = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? c.accentBase : c.lineStrong,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accentBase,
                ),
              ),
            )
          : null,
    );

    if (onTap == null) return ring;
    return Semantics(
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 48, height: 48, child: Center(child: ring)),
      ),
    );
  }
}

/// Mohor checkbox (rounded 6px square, matching First run / What you need).
class RosidCheckbox extends StatelessWidget {
  const RosidCheckbox({required this.checked, this.onTap, super.key});

  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? c.accentBase : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? c.accentBase : c.lineStrong,
          width: 1.5,
        ),
      ),
      child: checked
          ? Center(
              child: RosidIcon(
                RosidIcons.check,
                size: 16,
                color: c.inkOnAccent,
              ),
            )
          : null,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 48, height: 48, child: Center(child: box)),
    );
  }
}
