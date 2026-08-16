class ProductJourneyStep {
  const ProductJourneyStep({
    required this.id,
    required this.state,
    required this.actor,
    required this.initBy,
    required this.loa,
    this.timestamp,
  });

  final String id;
  final String state;
  final String actor;
  final String initBy;
  final String loa;
  final DateTime? timestamp;

  factory ProductJourneyStep.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];

    return ProductJourneyStep(
      id: json['id'] as String,
      state: json['state'] as String,
      actor: json['actor'] as String,
      initBy: json['initBy'] as String,
      loa: json['loa'] as String,
      timestamp: rawTimestamp == null
          ? null
          : DateTime.parse(rawTimestamp as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state': state,
      'actor': actor,
      'initBy': initBy,
      'loa': loa,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
}
