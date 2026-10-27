/// Thrown at startup when the build configuration is invalid or unsafe.
class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}
