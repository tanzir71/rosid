import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';

/// First run / 1 Language (`design/screens/first-run-1-language.png`).
class WelcomeLanguageScreen extends ConsumerWidget {
  const WelcomeLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: SizedBox(
                          height: 190,
                          width: 320,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 14,
                                top: 18,
                                child: Transform.rotate(
                                  angle: -0.1,
                                  child: const RosidPaperThumbnail(
                                    kind: RosidPaperKind.land,
                                    width: 96,
                                    height: 124,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 16,
                                top: 12,
                                child: Transform.rotate(
                                  angle: 0.1,
                                  child: const RosidPaperThumbnail(
                                    kind: RosidPaperKind.receipt,
                                    width: 82,
                                    height: 124,
                                  ),
                                ),
                              ),
                              const Positioned(
                                top: 4,
                                child: RosidPaperThumbnail(
                                  kind: RosidPaperKind.certificate,
                                  width: 100,
                                  height: 128,
                                ),
                              ),
                              Positioned(
                                bottom: 18,
                                child: Transform.rotate(
                                  angle: 0.08,
                                  child: const RosidPaperThumbnail(
                                    kind: RosidPaperKind.id,
                                    width: 72,
                                    height: 92,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 22,
                                bottom: 14,
                                child: RosidStamp(
                                  label: l10n.worksOfflineStamp,
                                  tone: RosidStampTone.accent,
                                  angleRadians: -0.09,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.welcomeHeadlineBn,
                        style: RosidTextTokens.uiTitleLg.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.welcomeSublineEn,
                        style: RosidTextTokens.uiBody.copyWith(
                          color: c.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _LanguageOptionRow(
                        title: l10n.bangla,
                        subtitle: l10n.welcomeBanglaSubtitle,
                        selected: settings.languageCode == 'bn',
                        onTap: () => controller.setLanguage('bn'),
                      ),
                      Divider(color: c.lineSubtle, height: 1),
                      _LanguageOptionRow(
                        title: l10n.english,
                        subtitle: l10n.welcomeEnglishSubtitle,
                        selected: settings.languageCode == 'en',
                        onTap: () => controller.setLanguage('en'),
                      ),
                      Divider(color: c.lineSubtle, height: 1),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  RosidIcon(RosidIcons.shield, size: 18, color: c.goodBase),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.welcomePrivacyLine,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RosidButton(
                key: const ValueKey('welcome-continue-language'),
                label: l10n.continueLabel,
                expand: true,
                onPressed: () => context.push('/welcome/purpose'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOptionRow extends StatelessWidget {
  const _LanguageOptionRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            RosidRadio(selected: selected),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First run / 2 What you need (`design/screens/first-run-2-what-you-need.png`).
/// Also reusable when opened from Settings (`fromSettings: true`).
class WelcomePurposeScreen extends ConsumerStatefulWidget {
  const WelcomePurposeScreen({this.fromSettings = false, super.key});

  final bool fromSettings;

  @override
  ConsumerState<WelcomePurposeScreen> createState() =>
      _WelcomePurposeScreenState();
}

class _WelcomePurposeScreenState extends ConsumerState<WelcomePurposeScreen> {
  late Set<RosidPurpose> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...ref.read(appSettingsProvider).purposes};
  }

  void _toggle(RosidPurpose purpose) {
    setState(() {
      if (_selected.contains(purpose)) {
        _selected.remove(purpose);
      } else {
        _selected.add(purpose);
      }
    });
  }

  Future<void> _continue() async {
    await ref.read(appSettingsProvider.notifier).setPurposes(_selected);
    if (!mounted) return;
    if (widget.fromSettings) {
      context.pop();
    } else {
      context.push('/welcome/camera');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final items = <(RosidPurpose, RosidIcons, String, String)>[
      (
        RosidPurpose.visa,
        RosidIcons.seal,
        l10n.purposeVisaTitle,
        l10n.purposeVisaSub,
      ),
      (
        RosidPurpose.land,
        RosidIcons.land,
        l10n.purposeLandTitle,
        l10n.purposeLandSub,
      ),
      (
        RosidPurpose.receipts,
        RosidIcons.receipt,
        l10n.purposeReceiptsTitle,
        l10n.purposeReceiptsSub,
      ),
      (
        RosidPurpose.study,
        RosidIcons.text,
        l10n.purposeStudyTitle,
        l10n.purposeStudySub,
      ),
      (
        RosidPurpose.office,
        RosidIcons.file,
        l10n.purposeOfficeTitle,
        l10n.purposeOfficeSub,
      ),
      (
        RosidPurpose.family,
        RosidIcons.people,
        l10n.purposeFamilyTitle,
        l10n.purposeFamilySub,
      ),
    ];

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: '', showBack: true),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.welcomePurposeTitle,
                style: RosidTextTokens.uiTitleLg.copyWith(color: c.inkPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomePurposeHelp,
                style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: c.lineSubtle, height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final checked = _selected.contains(item.$1);
                    return InkWell(
                      onTap: () => _toggle(item.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            RosidIcon(
                              item.$2,
                              size: 22,
                              color: checked ? c.accentBase : c.inkSecondary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.$3,
                                    style: RosidTextTokens.uiBodyStrong
                                        .copyWith(color: c.inkPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.$4,
                                    style: RosidTextTokens.uiCaption.copyWith(
                                      color: c.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            RosidCheckbox(checked: checked),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              RosidButton(
                key: const ValueKey('welcome-continue-purpose'),
                label: widget.fromSettings ? l10n.save : l10n.continueLabel,
                expand: true,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First run / 3 Camera (`design/screens/first-run-3-camera.png`).
class WelcomeCameraScreen extends ConsumerStatefulWidget {
  const WelcomeCameraScreen({super.key});

  @override
  ConsumerState<WelcomeCameraScreen> createState() =>
      _WelcomeCameraScreenState();
}

class _WelcomeCameraScreenState extends ConsumerState<WelcomeCameraScreen> {
  bool _busy = false;

  Future<void> _allowCamera() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Triggers the Android camera permission prompt on real hardware;
      // safely completes even when no camera exists (emulator/tests).
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final ctrl = CameraController(
          cameras.first,
          ResolutionPreset.low,
          enableAudio: false,
        );
        try {
          await ctrl.initialize();
        } finally {
          await ctrl.dispose();
        }
      }
    } on Object {
      // Camera permission denied or unavailable; proceed to Home where import works.
    }
    await ref.read(appSettingsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _skipCamera() async {
    if (_busy) return;
    await ref.read(appSettingsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: '', showBack: true),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 208,
                        decoration: BoxDecoration(
                          color: c.cameraScene,
                          borderRadius: BorderRadius.circular(
                            RosidSizeTokens.radiusControl,
                          ),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 170,
                            height: 154,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(170, 154),
                                  painter: _CornerBracketPainter(
                                    color: RosidColorTokens.accentBaseDark,
                                  ),
                                ),
                                Transform.rotate(
                                  angle: -0.05,
                                  child: const RosidPaperThumbnail(
                                    kind: RosidPaperKind.letter,
                                    width: 96,
                                    height: 124,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.welcomeCameraTitle,
                        style: RosidTextTokens.uiTitleLg.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.welcomeCameraBody,
                        style: RosidTextTokens.uiBody.copyWith(
                          color: c.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AssuranceRow(
                        icon: RosidIcons.shield,
                        text: l10n.welcomeAssuranceOffline,
                      ),
                      const SizedBox(height: 14),
                      _AssuranceRow(
                        icon: RosidIcons.lock,
                        text: l10n.welcomeAssuranceLock,
                      ),
                      const SizedBox(height: 14),
                      _AssuranceRow(
                        icon: RosidIcons.backup,
                        text: l10n.welcomeAssuranceBackup,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RosidButton(
                key: const ValueKey('welcome-allow-camera'),
                label: l10n.allowCamera,
                expand: true,
                busy: _busy,
                onPressed: _allowCamera,
              ),
              const SizedBox(height: 8),
              RosidButton(
                key: const ValueKey('welcome-skip-camera'),
                label: l10n.notNowImportPhotos,
                kind: RosidButtonKind.ghost,
                expand: true,
                onPressed: _busy ? null : _skipCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssuranceRow extends StatelessWidget {
  const _AssuranceRow({required this.icon, required this.text});

  final RosidIcons icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: RosidIcon(icon, size: 20, color: c.goodBase),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: RosidTextTokens.uiBody.copyWith(color: c.inkPrimary),
          ),
        ),
      ],
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const len = 16.0;
    const r = 6.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, len),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - r)
        ..quadraticBezierTo(0, size.height, r, size.height)
        ..lineTo(len, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - r, size.height)
        ..quadraticBezierTo(
          size.width,
          size.height,
          size.width,
          size.height - r,
        )
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color;
}
