class Player {
  final String name;
  final double rating;
  final double rd;
  final double vol;
  final String tier;

  Player({
    required this.name,
    required this.rating,
    required this.rd,
    required this.vol,
    required this.tier,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      name: json['name'] ?? 'Unknown',
      rating: (json['rating'] as num).toDouble(),
      rd: (json['rd'] as num).toDouble(),
      vol: (json['vol'] as num).toDouble(),
      tier: json['group_tier'] ?? 'Rookie',
    );
  }

  String get emoji {
    switch (tier.toLowerCase()) {
      case 'grandmaster': return '👑';
      case 'master': return '⭐';
      case 'challenger': return '💪';
      case 'rookie': return '🚀';
      default: return '👤';
    }
  }
}