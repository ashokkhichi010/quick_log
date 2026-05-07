class Category {
  const Category({
    required this.id,
    required this.name,
    required this.isDefault,
  });

  static const fallbackCategoryId = 'default-other';

  static const seededCategories = <Category>[
    Category(id: 'default-iot', name: 'IoT', isDefault: true),
    Category(id: 'default-flutter', name: 'Flutter', isDefault: true),
    Category(id: 'default-learning', name: 'Learning', isDefault: true),
    Category(
      id: 'default-communication',
      name: 'Communication',
      isDefault: true,
    ),
    Category(id: fallbackCategoryId, name: 'Other', isDefault: true),
  ];

  final String id;
  final String name;
  final bool isDefault;

  Category copyWith({String? id, String? name, bool? isDefault}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static Category fallbackCategory() {
    return seededCategories.firstWhere((item) => item.id == fallbackCategoryId);
  }
}
