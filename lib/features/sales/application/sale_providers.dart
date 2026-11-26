import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/sale_models.dart';

final saleProvider = FutureProvider.autoDispose.family<Sale, int>(
  (ref, id) => ref.watch(saleRepositoryProvider).sale(id),
);

/// The signed-in user's operations; [role] is `buyer` or `seller`.
final mySalesProvider = FutureProvider.autoDispose.family<List<Sale>, String>(
  (ref, role) => ref.watch(saleRepositoryProvider).mine(role),
);
