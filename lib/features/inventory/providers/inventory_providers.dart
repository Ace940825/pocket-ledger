import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../data/inventory_repository.dart';

final Provider<InventoryRepository> inventoryRepositoryProvider =
    Provider<InventoryRepository>(
  (Ref ref) => InventoryRepository(ref.watch(appDatabaseProvider)),
);

final StreamProvider<List<InventoryItem>> inventoryListProvider =
    StreamProvider<List<InventoryItem>>(
  (Ref ref) => ref
      .watch(inventoryRepositoryProvider)
      .watch(ref.watch(currentBookIdProvider)),
);
