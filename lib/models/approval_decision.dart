class ApprovalDecision {
  ApprovalDecision({
    required this.id,
    required this.journeyId,
    required this.decision,
    required this.approverName,
    required this.approverRole,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String journeyId;
  final String decision;
  final String approverName;
  final String approverRole;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory ApprovalDecision.fromJson(Map<String, dynamic> json) {
    return ApprovalDecision(
      id: (json['id'] ?? '').toString(),
      journeyId: (json['journey_id'] ?? '').toString(),
      decision: (json['decision'] ?? 'pending').toString(),
      approverName: (json['approver_name'] ?? '').toString(),
      approverRole: (json['approver_role'] ?? '').toString(),
      comment: json['comment']?.toString(),
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
      'journey_id': journeyId,
      'decision': decision,
      'approver_name': approverName,
      'approver_role': approverRole,
      'comment': comment,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}
