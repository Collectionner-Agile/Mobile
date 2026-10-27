import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/community_models.dart';

final communitiesProvider = FutureProvider<List<Community>>((ref) {
  // Re-fetch when the user changes so `isJoined` reflects the session.
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(communityRepositoryProvider).communities();
});

final communitySearchProvider = FutureProvider.autoDispose.family<List<Community>, String>((ref, term) async {
  // The screen debounces typing; this provider only maps the term to a request.
  if (term.trim().isEmpty) return ref.watch(communitiesProvider.future);
  return ref.watch(communityRepositoryProvider).search(term.trim());
});

final communityProvider = FutureProvider.autoDispose.family<Community, int>((ref, id) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(communityRepositoryProvider).community(id);
});

final communityFeedProvider = FutureProvider.autoDispose.family<List<FeedItem>, ({int id, String query})>(
  (ref, args) => ref.watch(communityRepositoryProvider).feed(args.id, query: args.query),
);

final myCommunitiesProvider = FutureProvider<List<Community>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(const []);
  return ref.watch(communityRepositoryProvider).joinedBy(user.id);
});

final postProvider = FutureProvider.autoDispose.family<Post, int>(
  (ref, id) => ref.watch(communityRepositoryProvider).post(id),
);

final postCommentsProvider = FutureProvider.autoDispose.family<List<Comment>, int>(
  (ref, id) => ref.watch(communityRepositoryProvider).postComments(id),
);
