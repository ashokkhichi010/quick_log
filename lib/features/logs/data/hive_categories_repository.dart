import 'package:hive/hive.dart';

import '../domain/category.dart';
import '../domain/repositories/categories_repository.dart';

class HiveCategoriesRepository implements CategoriesRepository {
  const HiveCategoriesRepository(this._box);

  final Box<Category> _box;

  @override
  Future<List<Category>> fetchCategories() async {
    final categories = _box.values.toList();
    categories.sort((left, right) {
      if (left.isDefault != right.isDefault) {
        return left.isDefault ? -1 : 1;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return categories;
  }

  @override
  Future<void> saveCategory(Category category) async {
    await _box.put(category.id, category);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    await _box.delete(categoryId);
  }
}
