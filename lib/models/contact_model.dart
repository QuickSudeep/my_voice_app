class Contact {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isEmergency;

  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    this.isEmergency = false,
  });

  /// Returns the initials to display as avatar
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Contact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relation,
    bool? isEmergency,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      isEmergency: isEmergency ?? this.isEmergency,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relation': relation,
    'isEmergency': isEmergency,
  };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    relation: json['relation'] as String? ?? '',
    isEmergency: json['isEmergency'] as bool? ?? false,
  );
}
