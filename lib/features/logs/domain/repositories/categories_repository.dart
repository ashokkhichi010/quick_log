import '../category.dart';

abstract class CategoriesRepository {
  Future<List<Category>> fetchCategories();

  Future<void> saveCategory(Category category);

  Future<void> deleteCategory(String categoryId);
}
