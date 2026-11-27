import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/safety/app_lock_service.dart';

/// Full-screen bilingual App Lock screen (Mohor style, built from shared tokens).
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _pin = '';
  bool _checking = false;
  bool _wrongPin = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final ok = await ref.read(biometricAuthenticatorProvider).isAvailable();
    if (mounted) {
      setState(() => _biometricAvailable = ok);
    }
  }

  Future<void> _submitPin() async {
    if (_checking || _pin.length < 4) return;
    setState(() {
      _checking = true;
      _wrongPin = false;
    });
    final ok = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithPin(_pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _checking = false;
        _wrongPin = true;
        _pin = '';
      });
    } else {
      setState(() => _checking = false);
    }
  }

  Future<void> _tryBiometric() async {
    if (_checking) return;
    final reason = context.l10n.appLockTitle;
    await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithBiometrics(reason: reason);
  }

  void _appendDigit(String digit) {
    if (_checking || _pin.length >= 6) return;
    setState(() {
      _wrongPin = false;
      _pin += digit;
    });
  }

  void _backspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return Scaffold(
      key: const ValueKey('app-lock-screen'),
      backgroundColor: c.bgCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 44).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: RosidIcon(
                        RosidIcons.lock,
                        size: 26,
                        color: c.accentBase,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.appLockTitle,
                      style: RosidTextTokens.uiTitle.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _wrongPin ? l10n.appLockWrongPin : l10n.appLockEnterPin,
                      key: const ValueKey('app-lock-status'),
                      style: RosidTextTokens.uiBody.copyWith(
                        color: _wrongPin ? c.badBase : c.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 6; i++)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _pin.length
                                  ? c.accentBase
                                  : c.bgSunken,
                              border: Border.all(
                                color: _wrongPin
                                    ? c.badBase
                                    : (i < _pin.length
                                          ? c.accentBase
                                          : c.lineStrong),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 16),
                    _PinKeypad(
                      locale: locale,
                      onDigit: _appendDigit,
                      onBackspace: _backspace,
                      onSubmit: _pin.length >= 4 ? _submitPin : null,
                    ),
                    const SizedBox(height: 14),
                    RosidButton(
                      key: const ValueKey('app-lock-unlock-btn'),
                      label: l10n.appLockTitle,
                      expand: true,
                      onPressed: _pin.length >= 4 && !_checking
                          ? _submitPin
                          : null,
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 10),
                      RosidButton(
                        key: const ValueKey('app-lock-fingerprint-btn'),
                        label: l10n.appLockUseFingerprint,
                        kind: RosidButtonKind.outline,
                        expand: true,
                        onPressed: _tryBiometric,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.locale,
    required this.onDigit,
    required this.onBackspace,
    this.onSubmit,
  });

  final Locale locale;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    Widget keyBtn(String digit) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: InkWell(
          key: ValueKey('pin-key-$digit'),
          onTap: () => onDigit(digit),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.bgSheet,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.lineSubtle),
            ),
            child: Text(
              localizeDigits(digit, locale),
              style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
            ),
          ),
        ),
      ),
    );

    return Column(
      children: [
        for (final row in rows) Row(children: [for (final d in row) keyBtn(d)]),
        Row(
          children: [
            const Expanded(child: SizedBox(height: 54)),
            keyBtn('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: InkWell(
                  key: const ValueKey('pin-key-back'),
                  onTap: onBackspace,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.bgSunken,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: RosidIcon(
                      RosidIcons.chevronLeft,
                      size: 22,
                      color: c.inkPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Modal bottom sheet to set or change the 4–6 digit App lock PIN.
Future<String?> showPinSetupSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _PinSetupSheet(),
  );
}

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet();

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final a = _pin1.text.trim();
    final b = _pin2.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(a)) {
      setState(() => _error = l10n.appLockPinHint);
      return;
    }
    if (a != b) {
      setState(() => _error = l10n.appLockPinMismatch);
      return;
    }
    Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appLockSetPinTitle,
              style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('pin-setup-first'),
              controller: _pin1,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.appLockEnterPin,
                hintText: l10n.appLockPinHint,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('pin-setup-confirm'),
              controller: _pin2,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: l10n.appLockConfirmPinTitle,
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: RosidTextTokens.uiCaption.copyWith(color: c.badBase),
              ),
            ],
            const SizedBox(height: 16),
            RosidButton(
              key: const ValueKey('pin-setup-save'),
              label: l10n.save,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
