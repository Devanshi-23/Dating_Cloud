/// Optional profile details collected during onboarding and shown on cards.
/// Wire values are the ones documented in `docs/api/openapi.yaml`.
library;

enum RelationshipGoal {
  longTerm('LONG_TERM', 'Long-term partner'),
  longTermOpenToShort('LONG_TERM_OPEN_TO_SHORT', 'Long-term, open to short'),
  shortTermOpenToLong('SHORT_TERM_OPEN_TO_LONG', 'Short-term, open to long'),
  shortTermFun('SHORT_TERM_FUN', 'Short-term fun'),
  newFriends('NEW_FRIENDS', 'New friends'),
  stillFiguringOut('STILL_FIGURING_OUT', 'Still figuring it out');

  const RelationshipGoal(this.wire, this.label);

  final String wire;
  final String label;

  static RelationshipGoal? fromWire(String? value) {
    for (final goal in values) {
      if (goal.wire == value) return goal;
    }
    return null;
  }
}

enum QuestionSection { lifestyle, aboutYou }

class ProfileOption {
  const ProfileOption(this.id, this.label);

  final String id;
  final String label;
}

class ProfileQuestion {
  const ProfileQuestion({
    required this.id,
    required this.title,
    required this.section,
    required this.options,
  });

  final String id;
  final String title;
  final QuestionSection section;
  final List<ProfileOption> options;
}

/// Single-choice questions. Every answer is optional.
abstract final class ProfileQuestions {
  static const all = [
    ProfileQuestion(
      id: 'drinking',
      title: 'How often do you drink?',
      section: QuestionSection.lifestyle,
      options: [
        ProfileOption('NOT_FOR_ME', 'Not for me'),
        ProfileOption('SOBER', 'Sober'),
        ProfileOption('SOBER_CURIOUS', 'Sober curious'),
        ProfileOption('SPECIAL_OCCASIONS', 'On special occasions'),
        ProfileOption('SOCIAL_WEEKENDS', 'Socially on weekends'),
        ProfileOption('MOST_NIGHTS', 'Most nights'),
      ],
    ),
    ProfileQuestion(
      id: 'smoking',
      title: 'How often do you smoke?',
      section: QuestionSection.lifestyle,
      options: [
        ProfileOption('SOCIAL', 'Social smoker'),
        ProfileOption('WHEN_DRINKING', 'Smoker when drinking'),
        ProfileOption('NON_SMOKER', 'Non-smoker'),
        ProfileOption('SMOKER', 'Smoker'),
        ProfileOption('TRYING_TO_QUIT', 'Trying to quit'),
      ],
    ),
    ProfileQuestion(
      id: 'workout',
      title: 'Do you work out?',
      section: QuestionSection.lifestyle,
      options: [
        ProfileOption('EVERYDAY', 'Everyday'),
        ProfileOption('OFTEN', 'Often'),
        ProfileOption('SOMETIMES', 'Sometimes'),
        ProfileOption('NEVER', 'Never'),
      ],
    ),
    ProfileQuestion(
      id: 'pets',
      title: 'Do you have any pets?',
      section: QuestionSection.lifestyle,
      options: [
        ProfileOption('DOG', 'Dog'),
        ProfileOption('CAT', 'Cat'),
        ProfileOption('BIRD', 'Bird'),
        ProfileOption('FISH', 'Fish'),
        ProfileOption('REPTILE', 'Reptile'),
        ProfileOption('OTHER', 'Other'),
        ProfileOption('NONE_BUT_LOVE', 'Don’t have but love'),
        ProfileOption('WANT', 'Want a pet'),
        ProfileOption('ALLERGIC', 'Allergic to pets'),
      ],
    ),
    ProfileQuestion(
      id: 'communicationStyle',
      title: 'What is your communication style?',
      section: QuestionSection.aboutYou,
      options: [
        ProfileOption('ALWAYS_ONLINE', 'Always online'),
        ProfileOption('BIG_TEXTER', 'Big time texter'),
        ProfileOption('PHONE_CALLER', 'Phone caller'),
        ProfileOption('VIDEO_CHATTER', 'Video chatter'),
        ProfileOption('SLOW_REPLIER', 'Slow to reply'),
        ProfileOption('BAD_TEXTER', 'Bad texter'),
        ProfileOption('IN_PERSON', 'Better in person'),
      ],
    ),
    ProfileQuestion(
      id: 'loveStyle',
      title: 'How do you receive love?',
      section: QuestionSection.aboutYou,
      options: [
        ProfileOption('GESTURES', 'Thoughtful gestures'),
        ProfileOption('PRESENTS', 'Presents'),
        ProfileOption('TOUCH', 'Touch'),
        ProfileOption('COMPLIMENTS', 'Compliments'),
        ProfileOption('TIME_TOGETHER', 'Time together'),
      ],
    ),
    ProfileQuestion(
      id: 'education',
      title: 'What is your education level?',
      section: QuestionSection.aboutYou,
      options: [
        ProfileOption('HIGH_SCHOOL', 'High school'),
        ProfileOption('IN_COLLEGE', 'In college'),
        ProfileOption('BACHELORS', 'Bachelors'),
        ProfileOption('IN_GRAD_SCHOOL', 'In grad school'),
        ProfileOption('MASTERS', 'Masters'),
        ProfileOption('PHD', 'PhD'),
        ProfileOption('TRADE_SCHOOL', 'Trade school'),
      ],
    ),
    ProfileQuestion(
      id: 'zodiac',
      title: 'What is your zodiac sign?',
      section: QuestionSection.aboutYou,
      options: [
        ProfileOption('ARIES', 'Aries'),
        ProfileOption('TAURUS', 'Taurus'),
        ProfileOption('GEMINI', 'Gemini'),
        ProfileOption('CANCER', 'Cancer'),
        ProfileOption('LEO', 'Leo'),
        ProfileOption('VIRGO', 'Virgo'),
        ProfileOption('LIBRA', 'Libra'),
        ProfileOption('SCORPIO', 'Scorpio'),
        ProfileOption('SAGITTARIUS', 'Sagittarius'),
        ProfileOption('CAPRICORN', 'Capricorn'),
        ProfileOption('AQUARIUS', 'Aquarius'),
        ProfileOption('PISCES', 'Pisces'),
      ],
    ),
  ];

  static List<ProfileQuestion> inSection(QuestionSection section) => [
    for (final q in all)
      if (q.section == section) q,
  ];

  /// Label for a stored answer, or `null` if either id is unknown (e.g. a
  /// newer server value), so callers can skip it.
  static String? labelFor(String questionId, String optionId) {
    for (final q in all) {
      if (q.id != questionId) continue;
      for (final o in q.options) {
        if (o.id == optionId) return o.label;
      }
    }
    return null;
  }

  /// Drops unknown questions and options.
  static Map<String, String> sanitize(Map<String, String> answers) => {
    for (final MapEntry(:key, :value) in answers.entries)
      if (labelFor(key, value) != null) key: value,
  };
}

class ProfilePrompt {
  const ProfilePrompt(this.id, this.text);

  final String id;
  final String text;
}

class PromptAnswer {
  const PromptAnswer({required this.promptId, required this.answer});

  final String promptId;
  final String answer;

  String? get question => ProfilePrompts.textFor(promptId);
}

abstract final class ProfilePrompts {
  static const all = [
    ProfilePrompt('SIMPLE_PLEASURES', 'My simple pleasures are…'),
    ProfilePrompt('PERFECT_SUNDAY', 'My perfect Sunday looks like…'),
    ProfilePrompt('TOGETHER_WE_COULD', 'Together, we could…'),
    ProfilePrompt('GREEN_FLAG', 'The green flag I look for is…'),
    ProfilePrompt('FIRST_DATE', 'My ideal first date is…'),
    ProfilePrompt('TWO_TRUTHS', 'Two truths and a lie…'),
  ];

  static String? textFor(String id) {
    for (final p in all) {
      if (p.id == id) return p.text;
    }
    return null;
  }
}
