import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../../logs/domain/category.dart';
import '../controllers/categories_controller.dart';
import 'setting_section.dart';

class CategoryManagementSection extends ConsumerWidget {
  const CategoryManagementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesControllerProvider);

    return SettingSection(
      title: 'Categories',
      description: 'Keep log categories tidy and reusable.',
      child: Column(
        children: [
          for (final category in categoriesState.categories) ...[
            _CategoryTile(category: category),
            if (category != categoriesState.categories.last)
              const Divider(height: 10),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _showCategoryEditor(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add category'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(category.name),
      subtitle: Text(
        category.isDefault ? 'Default category' : 'Custom category',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _showCategoryEditor(context, ref, category: category),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: category.id == Category.fallbackCategoryId
                ? null
                : () => _deleteCategory(context, ref, category),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCategoryEditor(
  BuildContext context,
  WidgetRef ref, {
  Category? category,
}) async {
  final controller = TextEditingController(text: category?.name ?? '');
  final submittedName = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(category == null ? 'Add category' : 'Rename category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  controller.dispose();

  if (submittedName == null) {
    return;
  }

  try {
    final notifier = ref.read(categoriesControllerProvider.notifier);
    if (category == null) {
      await notifier.addCategory(submittedName);
    } else {
      await notifier.renameCategory(category, submittedName);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(category == null ? 'Category added.' : 'Category updated.'),
        ),
      );
    }
  } on CategoryException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Future<void> _deleteCategory(
  BuildContext context,
  WidgetRef ref,
  Category category,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Logs in ${category.name} will move to Other before this category is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  try {
    await ref.read(categoriesControllerProvider.notifier).deleteCategory(category);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category deleted.')));
    }
  } on CategoryException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
