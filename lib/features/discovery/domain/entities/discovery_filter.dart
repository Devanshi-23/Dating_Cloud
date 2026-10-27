class DiscoveryFilter {
  const DiscoveryFilter({
    this.minAge = 18,
    this.maxAge = 60,
    this.maxDistanceKm = 50,
  }) : assert(minAge >= 18 && minAge <= maxAge);

  final int minAge;
  final int maxAge;
  final int maxDistanceKm;

  Map<String, dynamic> toQuery() => {
    'minAge': minAge,
    'maxAge': maxAge,
    'distanceKm': maxDistanceKm,
  };
}
