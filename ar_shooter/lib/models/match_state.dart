enum BombStatus {
  unplanted('O\'rnatilmagan'),
  arming('Faollashtirilmoqda...'),
  armed('BOMBA FAOLLASHDI!'),
  defusing('Zararsizlantirilmoqda...'),
  defused('BOMBA ZARARSIZLANTIRILDI!'),
  exploded('BOMBA PORTLADI!');

  final String label;
  const BombStatus(this.label);
}

class BombState {
  final double latitude;
  final double longitude;
  final BombStatus status;
  final int armTimerSec;
  final int defuseTimerSec;
  final int explodeCountdownSec;
  final String? plantedBy;
  final String? defusedBy;

  const BombState({
    required this.latitude,
    required this.longitude,
    required this.status,
    this.armTimerSec = 10,
    this.defuseTimerSec = 10,
    this.explodeCountdownSec = 45,
    this.plantedBy,
    this.defusedBy,
  });

  bool get isActive => status == BombStatus.arming || status == BombStatus.armed || status == BombStatus.defusing;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'type': 'bomb_sync',
        'lat': latitude,
        'lon': longitude,
        'st': status.name,
        'arm': armTimerSec,
        'def': defuseTimerSec,
        'exp': explodeCountdownSec,
        'plantedBy': plantedBy,
        'defusedBy': defusedBy,
      };

  factory BombState.fromJson(Map<String, dynamic> json) => BombState(
        latitude: (json['lat'] as num?)?.toDouble() ?? 41.3111,
        longitude: (json['lon'] as num?)?.toDouble() ?? 69.2797,
        status: BombStatus.values.firstWhere(
          (s) => s.name == json['st'],
          orElse: () => BombStatus.unplanted,
        ),
        armTimerSec: (json['arm'] as num?)?.toInt() ?? 10,
        defuseTimerSec: (json['def'] as num?)?.toInt() ?? 10,
        explodeCountdownSec: (json['exp'] as num?)?.toInt() ?? 45,
        plantedBy: json['plantedBy']?.toString(),
        defusedBy: json['defusedBy']?.toString(),
      );
}
