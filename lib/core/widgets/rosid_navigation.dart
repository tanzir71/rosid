import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';

enum RosidNavTab { home, library, bundles, expenses }

/// Floating Mohor navigation dock + scan action button (matching `home.png`).
class RosidNavDock extends StatelessWidget {
  const RosidNavDock({
    required this.activeTab,
    required this.showExpenses,
    required this.onSelectTab,
    required this.onScanPressed,
    required this.homeLabel,
    required this.libraryLabel,
    required this.bundlesLabel,
    required this.expensesLabel,
    required this.scanTooltip,
    super.key,
  });

  final RosidNavTab activeTab;
  final bool showExpenses;
  final ValueChanged<RosidNavTab> onSelectTab;
  final VoidCallback onScanPressed;
  final String homeLabel;
  final String libraryLabel;
  final String bundlesLabel;
  final String expensesLabel;
  final String scanTooltip;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final items = <(RosidNavTab, RosidIcons, String)>[
      (RosidNavTab.home, RosidIcons.home, homeLabel),
      (RosidNavTab.library, RosidIcons.papers, libraryLabel),
      (RosidNavTab.bundles, RosidIcons.bundle, bundlesLabel),
      if (showExpenses)
        (RosidNavTab.expenses, RosidIcons.wallet, expensesLabel),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: c.bgSheet,
                  borderRadius: BorderRadius.circular(
                    RosidSizeTokens.radiusPill,
                  ),
                  border: Border.all(color: c.lineSubtle),
                  boxShadow: RosidShadowTokens.elevDock,
                ),
                child: Row(
                  children: [
                    for (final item in items)
                      Expanded(
                        child: _DockItem(
                          icon: item.$2,
                          label: item.$3,
                          active: activeTab == item.$1,
                          onTap: () => onSelectTab(item.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: scanTooltip,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: RosidShadowTokens.elevDock,
                ),
                child: Material(
                  color: c.accentBase,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    key: const ValueKey('dock-scan-button'),
                    onTap: onScanPressed,
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Center(
                        child: RosidIcon(
                          RosidIcons.scan,
                          size: 26,
                          color: c.inkOnAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final RosidIcons icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final fg = active ? c.accentInk : c.inkSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? c.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
              ),
              child: RosidIcon(icon, size: 20, color: fg),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RosidTextTokens.uiMicro.copyWith(
                color: fg,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mohor top bar with optional back arrow, title/wordmark, and trailing widgets.
class RosidTopBar extends StatelessWidget implements PreferredSizeWidget {
  const RosidTopBar({
    required this.title,
    this.showBack = false,
    this.onBack,
    this.leading,
    this.trailing = const [],
    this.isWordmark = false,
    super.key,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? leading;
  final List<Widget> trailing;
  final bool isWordmark;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (showBack)
              IconButton(
                key: const ValueKey('rosid-top-bar-back'),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                icon: RosidIcon(RosidIcons.back, size: 24, color: c.inkPrimary),
              )
            else
              const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (isWordmark
                            ? RosidTextTokens.uiTitleLg
                            : RosidTextTokens.uiTitle)
                        .copyWith(color: c.inkPrimary),
              ),
            ),
            for (final action in trailing) ...[
              const SizedBox(width: 8),
              action,
            ],
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Standard paper row for Home recent list and Library.
class RosidPaperRow extends StatelessWidget {
  const RosidPaperRow({
    required this.title,
    required this.subtitle,
    required this.kind,
    this.trailingTop,
    this.pillLabel,
    this.pillTone = RosidTone.accent,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final RosidPaperKind kind;
  final String? trailingTop;
  final String? pillLabel;
  final RosidTone pillTone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            RosidPaperThumbnail(kind: kind, width: 44, height: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trailingTop != null)
                  Text(
                    trailingTop!,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                if (pillLabel != null) ...[
                  const SizedBox(height: 4),
                  RosidPill(label: pillLabel!, tone: pillTone),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum RosidCheckStatus { done, check, missing }

/// Checklist item row for Bundle / Checklist (status: done, check, missing).
class RosidCheckRow extends StatelessWidget {
  const RosidCheckRow({
    required this.title,
    required this.subtitle,
    required this.status,
    this.actionLabel,
    this.onAction,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final RosidCheckStatus status;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final (icon, iconColor, subColor) = switch (status) {
      RosidCheckStatus.done => (
        RosidIcons.checkCircle,
        c.goodBase,
        c.inkSecondary,
      ),
      RosidCheckStatus.check => (RosidIcons.alert, c.warnBase, c.warnBase),
      RosidCheckStatus.missing => (
        RosidIcons.file,
        c.inkTertiary,
        c.inkSecondary,
      ),
    };

    return InkWell(
      onTap: onTap ?? onAction,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            RosidIcon(icon, size: 22, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RosidTextTokens.uiCaption.copyWith(color: subColor),
                  ),
                ],
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(48, 40),
                ),
                child: Text(
                  actionLabel!,
                  style: RosidTextTokens.uiLabel.copyWith(
                    color: c.accentBase,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else
              RosidIcon(
                RosidIcons.chevronRight,
                size: 18,
                color: c.inkTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

enum RosidReaderTab { scan, text, english }

/// Three-tab reader switcher (Scan, Text, English).
class RosidReaderTabs extends StatelessWidget {
  const RosidReaderTabs({
    required this.active,
    required this.onChanged,
    required this.scanLabel,
    required this.textLabel,
    required this.englishLabel,
    super.key,
  });

  final RosidReaderTab active;
  final ValueChanged<RosidReaderTab> onChanged;
  final String scanLabel;
  final String textLabel;
  final String englishLabel;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final tabs = [
      (RosidReaderTab.scan, scanLabel),
      (RosidReaderTab.text, textLabel),
      (RosidReaderTab.english, englishLabel),
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bgSunken,
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(tab.$1),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active == tab.$1 ? c.bgSheet : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: active == tab.$1
                        ? RosidShadowTokens.elevSheet
                        : null,
                  ),
                  child: Text(
                    tab.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RosidTextTokens.uiLabel.copyWith(
                      color: active == tab.$1 ? c.inkPrimary : c.inkSecondary,
                      fontWeight: active == tab.$1
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
