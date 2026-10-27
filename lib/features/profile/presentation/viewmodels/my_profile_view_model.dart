import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../domain/entities/user_profile.dart';

class MyProfileViewModel extends AsyncNotifier<MyProfile> {
  @override
  Future<MyProfile> build() =>
      ref.watch(profileRepositoryProvider).getMyProfile();
}

final myProfileViewModelProvider =
    AsyncNotifierProvider.autoDispose<MyProfileViewModel, MyProfile>(
      MyProfileViewModel.new,
    );
