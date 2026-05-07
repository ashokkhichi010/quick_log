import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../logs/domain/category.dart';
import '../../../logs/domain/repositories/categories_repository.dart';
import '../../../logs/domain/repositories/entries_repository.dart';

class CategoriesState {
  const CategoriesState({required this.categories, required this.isLoading});

  const CategoriesState.initial() : categories = const [], isLoading = true;

  final List<Category> categories;
  final bool isLoading;

  CategoriesState copyWith({List<Category>? categories, bool? isLoading}) {
    return CategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CategoriesController extends StateNotifier<CategoriesState> {
  CategoriesController({
    required CategoriesRepository repository,
    required EntriesRepository entriesRepository,
    required Uuid uuid,
  }) : _repository = repository,
       _entriesRepository = entriesRepository,
       _uuid = uuid,
       super(const CategoriesState.initial()) {
    loadCategories();
  }

  final CategoriesRepository _repository;
  final EntriesRepository _entriesRepository;
  final Uuid _uuid;

  Future<void> loadCategories() async {
    final categories = await _repository.fetchCategories();
    state = state.copyWith(categories: categories, isLoading: false);
  }

  Future<void> addCategory(String name) async {
    final normalized = _validateName(name);
    _ensureUnique(normalized);
    await _repository.saveCategory(
      Category(id: _uuid.v4(), name: normalized, isDefault: false),
    );
    await loadCategories();
  }

  Future<void> renameCategory(Category category, String nextName) async {
    final normalized = _validateName(nextName);
    _ensureUnique(normalized, currentCategoryId: category.id);
    await _repository.saveCategory(category.copyWith(name: normalized));
    await loadCategories();
  }

  Future<void> deleteCategory(Category category) async {
    if (category.id == Category.fallbackCategoryId) {
      throw const CategoryException('The fallback category cannot be deleted.');
    }

    await _entriesRepository.reassignCategory(
      fromCategoryId: category.id,
      toCategoryId: Category.fallbackCategoryId,
    );
    await _repository.deleteCategory(category.id);
    await loadCategories();
  }

  String _validateName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const CategoryException('Category name cannot be empty.');
    }
    return normalized;
  }

  void _ensureUnique(String name, {String? currentCategoryId}) {
    final exists = state.categories.any(
      (item) =>
          item.id != currentCategoryId &&
          item.name.toLowerCase() == name.toLowerCase(),
    );

    if (exists) {
      throw const CategoryException('Category already exists.');
    }
  }
}

class CategoryException implements Exception {
  const CategoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
