import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/settings_repository.dart';
import 'package:rosid/features/expenses/expenses_repository.dart';

final _categoriesListProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(settingsRepositoryProvider).categories(),
);

/// Editable receipt categories screen (`/settings/categories`).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _editOrAdd(
    BuildContext context,
    WidgetRef ref, {
    Category? existing,
  }) async {
    final enCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final bnCtrl = TextEditingController(text: existing?.nameBn ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null ? ctx.l10n.addCategoryAction : ctx.l10n.edit,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('category-en-input'),
              controller: enCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: ctx.l10n.categoryNameEnHint,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('category-bn-input'),
              controller: bnCtrl,
              decoration: InputDecoration(
                labelText: ctx.l10n.categoryNameBnHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('category-save-btn'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    );
    final en = enCtrl.text.trim();
    final bn = bnCtrl.text.trim().isEmpty ? en : bnCtrl.text.trim();
    enCtrl.dispose();
    bnCtrl.dispose();
    if (ok != true || en.isEmpty) return;

    final repo = ref.read(settingsRepositoryProvider);
    if (existing == null) {
      await repo.addCategory(en, bn);
    } else {
      await repo.updateCategory(existing, en, bn);
    }
    ref
      ..invalidate(_categoriesListProvider)
      ..invalidate(monthlyExpensesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final listAsync = ref.watch(_categoriesListProvider);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: l10n.categoriesLabel, showBack: true),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.loadFailed)),
        data: (categories) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            for (final cat in categories) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: RosidIcon(
                  RosidIcons.tag,
                  size: 20,
                  color: c.inkSecondary,
                ),
                title: Text(
                  cat.nameEn,
                  style: RosidTextTokens.uiBodyStrong.copyWith(
                    color: c.inkPrimary,
                  ),
                ),
                subtitle: Text(
                  cat.nameBn,
                  style: RosidTextTokens.uiCaption.copyWith(
                    color: c.inkSecondary,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: RosidIcon(
                        RosidIcons.edit,
                        size: 18,
                        color: c.inkSecondary,
                      ),
                      onPressed: () => _editOrAdd(context, ref, existing: cat),
                    ),
                    if (!cat.isDefault)
                      IconButton(
                        icon: RosidIcon(
                          RosidIcons.trash,
                          size: 18,
                          color: c.badBase,
                        ),
                        onPressed: () async {
                          await ref
                              .read(settingsRepositoryProvider)
                              .deleteCategory(cat);
                          ref
                            ..invalidate(_categoriesListProvider)
                            ..invalidate(monthlyExpensesProvider);
                        },
                      ),
                  ],
                ),
              ),
              Divider(color: c.lineSubtle, height: 1),
            ],
            const SizedBox(height: 16),
            RosidButton(
              key: const ValueKey('add-category-btn'),
              label: l10n.addCategoryAction,
              icon: RosidIcons.plus,
              kind: RosidButtonKind.tonal,
              onPressed: () => _editOrAdd(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
