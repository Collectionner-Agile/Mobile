import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/catalog_models.dart';

final collectiblesProvider = FutureProvider<List<Collectible>>((ref) {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(catalogRepositoryProvider).collectibles(cancelToken: cancel);
});

final collectibleProvider = FutureProvider.autoDispose.family<Collectible, int>(
  (ref, id) => ref.watch(catalogRepositoryProvider).collectible(id),
);

final collectibleCommentsProvider = FutureProvider.autoDispose.family<List<Comment>, int>(
  (ref, id) => ref.watch(catalogRepositoryProvider).comments(id),
);

final collectibleReviewsProvider = FutureProvider.autoDispose.family<List<Review>, int>(
  (ref, id) => ref.watch(catalogRepositoryProvider).reviews(id),
);

class CatalogFilter {
  const CatalogFilter({this.search = '', this.category, this.sort = CatalogSort.recent});
  final String search;
  final String? category;
  final CatalogSort sort;

  bool get isActive => search.trim().isNotEmpty || category != null;
}

final catalogFilterProvider = NotifierProvider<CatalogFilterController, CatalogFilter>(CatalogFilterController.new);

class CatalogFilterController extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void search(String value) => state = CatalogFilter(search: value, category: state.category, sort: state.sort);
  void category(String? value) => state = CatalogFilter(search: state.search, category: value, sort: state.sort);
  void sort(CatalogSort value) => state = CatalogFilter(search: state.search, category: state.category, sort: value);
  void clear() => state = CatalogFilter(sort: state.sort);
}

final catalogCategoriesProvider = Provider<List<String>>((ref) {
  final items = ref.watch(collectiblesProvider).value ?? const <Collectible>[];
  final categories = items.map((item) => item.category).whereType<String>().toSet().toList()..sort();
  return categories;
});

final filteredCatalogProvider = Provider<AsyncValue<List<Collectible>>>((ref) {
  final filter = ref.watch(catalogFilterProvider);
  return ref
      .watch(collectiblesProvider)
      .whenData(
        (items) => applyCatalogQuery(items, search: filter.search, category: filter.category, sort: filter.sort),
      );
});
