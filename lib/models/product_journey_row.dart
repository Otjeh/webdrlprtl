class ProductJourneyRow {
  ProductJourneyRow({
    required this.id,
    required this.productId,
    required this.state,
    required this.actor,
    required this.initiator,
    required this.loa,
    required this.status,
    this.approvedBy,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String productId;
  final String state;
  final String actor;
  final String initiator;
  final String loa;
  final String status;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory ProductJourneyRow.fromJson(Map<String, dynamic> json) {
    return ProductJourneyRow(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      actor: (json['actor'] ?? '').toString(),
      initiator: (json['initiator'] ?? json['initBy'] ?? '').toString(),
      loa: (json['loa'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      approvedBy: json['approved_by']?.toString(),
      createdAt: DateTime.parse(
        (json['created_at'] ?? DateTime.now().toUtc().toIso8601String())
            .toString(),
      ),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'state': state,
      'actor': actor,
      'initiator': initiator,
      'loa': loa,
      'status': status,
      'approved_by': approvedBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}
