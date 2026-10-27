enum LegalDocument { terms, privacy }

abstract final class LegalDocuments {
  /// Sent with onboarding so the server records which terms were accepted.
  static const currentTermsVersion = '2026-01';
}
