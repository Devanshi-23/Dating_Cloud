class DialCode {
  const DialCode(this.countryCode, this.code, this.label);

  final String countryCode;
  final String code;
  final String label;
}

abstract final class PhoneNumberRules {
  static final _e164 = RegExp(r'^\+[1-9]\d{7,14}$');

  static const dialCodes = [
    DialCode('IN', '+91', 'India'),
    DialCode('US', '+1', 'United States'),
    DialCode('GB', '+44', 'United Kingdom'),
    DialCode('AE', '+971', 'United Arab Emirates'),
    DialCode('SG', '+65', 'Singapore'),
    DialCode('AU', '+61', 'Australia'),
  ];

  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-()]'), '');

  static bool isValid(String raw) => _e164.hasMatch(normalize(raw));

  /// Joins a dial code and a national number, dropping a leading trunk `0`.
  static String combine(String dialCode, String nationalNumber) {
    final digits = normalize(nationalNumber).replaceFirst(RegExp(r'^0+'), '');
    return '$dialCode$digits';
  }
}
