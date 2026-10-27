abstract final class RoutePaths {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const onboarding = '/onboarding';
  static const legal = '/legal';
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';
  static const discover = '/discover';
  static const matches = '/matches';
  static const chats = '/chats';
  static const me = '/me';
  static const developerTools = '/me/developer';

  static String conversation(String conversationId) => '$chats/$conversationId';
}
