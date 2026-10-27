import 'package:flutter/material.dart';

import '../../../../core/widgets/app_controls.dart';
import '../../domain/entities/user_profile.dart';

abstract final class ProfileBasics {
  static const _icons = {
    'drinking': Icons.local_bar_outlined,
    'smoking': Icons.smoking_rooms_outlined,
    'workout': Icons.fitness_center_rounded,
    'pets': Icons.pets_outlined,
    'communicationStyle': Icons.chat_bubble_outline_rounded,
    'loveStyle': Icons.favorite_border_rounded,
    'education': Icons.school_outlined,
    'zodiac': Icons.nightlight_outlined,
  };

  /// One chip per known answer, in questionnaire order; unknown ids skipped.
  static List<Widget> chipsFor(Map<String, String> basics) => [
    for (final question in ProfileQuestions.all)
      if (basics[question.id] case final option?)
        if (ProfileQuestions.labelFor(question.id, option) case final label?)
          InfoChip(icon: _icons[question.id], label: label),
  ];
}
