import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'update_service.dart';
import 'models/release_model.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService.create(
    owner: 'ZekriDev1',
    repo: 'POS',
  );
  ref.onDispose(() => service.dispose());
  return service;
});

final updateStateProvider = StateProvider<UpdateState>((ref) {
  return const UpdateState(status: UpdateStatus.checking);
});

final updateCheckProvider = FutureProvider.autoDispose<void>((ref) async {
  final service = ref.read(updateServiceProvider);
  final state = await service.checkSilently();
  ref.read(updateStateProvider.notifier).state = state;
});

final latestReleaseProvider = Provider<ReleaseModel?>((ref) {
  final state = ref.watch(updateStateProvider);
  return state.release;
});
