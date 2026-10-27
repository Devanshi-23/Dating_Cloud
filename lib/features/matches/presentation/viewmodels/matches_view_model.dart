import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../core/network/pagination.dart';
import '../../domain/entities/match.dart';

class MatchesViewModel extends AsyncNotifier<List<Match>> {
  @override
  Future<List<Match>> build() async {
    final page = await ref
        .watch(matchRepositoryProvider)
        .getMatches(page: const PageRequest(limit: 50));
    return page.items;
  }

  Future<void> unmatch(String matchId) async {
    await ref.read(matchRepositoryProvider).unmatch(matchId);
    ref.invalidateSelf();
  }
}

final matchesViewModelProvider =
    AsyncNotifierProvider.autoDispose<MatchesViewModel, List<Match>>(
      MatchesViewModel.new,
    );
