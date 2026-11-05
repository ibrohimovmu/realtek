enum HitConfidence {
  person('Odam', 'person'),
  team('Jamoa', 'team'),
  gps('GPS', 'gps');

  final String label;
  final String key;
  const HitConfidence(this.label, this.key);

  static HitConfidence fromKey(String key) {
    return HitConfidence.values.firstWhere(
      (c) => c.key == key,
      orElse: () => HitConfidence.person,
    );
  }
}

class HitEvent {
  final String shooterId;
  final String shooterName;
  final String? targetId; // Specific player ID if resolved by GPS/person
  final String? targetTeam; // Target team (e.g. 'red', 'blue')
  final String weaponId;
  final int damage;
  final double distanceMeters;
  final int timestamp;
  final HitConfidence confidence;

  const HitEvent({
    required this.shooterId,
    required this.shooterName,
    this.targetId,
    this.targetTeam,
    required this.weaponId,
    required this.damage,
    required this.distanceMeters,
    required this.timestamp,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'v': 1,
        't': 'hit',
        'shooterId': shooterId,
        'shooterName': shooterName,
        'targetId': targetId,
        'targetTeam': targetTeam,
        'weaponId': weaponId,
        'damage': damage,
        'dist': distanceMeters,
        'ts': timestamp,
        'conf': confidence.key,
      };

  factory HitEvent.fromJson(Map<String, dynamic> json) {
    return HitEvent(
      shooterId: json['shooterId'] as String? ?? '',
      shooterName: json['shooterName'] as String? ?? 'Noma\'lum',
      targetId: json['targetId'] as String?,
      targetTeam: json['targetTeam'] as String?,
      weaponId: json['weaponId'] as String? ?? 'pistol',
      damage: (json['damage'] as num?)?.toInt() ?? 20,
      distanceMeters: (json['dist'] as num?)?.toDouble() ?? 5.0,
      timestamp: (json['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      confidence: HitConfidence.fromKey(json['conf'] as String? ?? 'person'),
    );
  }
}
