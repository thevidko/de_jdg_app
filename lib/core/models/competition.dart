class Competition {
  final String id;
  final String name;
  final String location;
  final DateTime dateStart;
  final String? organizer;
  final int
  status; // Předpokládám, že status je int (např. 1 = připravuje se, 2 = běží...)

  Competition({
    required this.id,
    required this.name,
    required this.location,
    required this.dateStart,
    this.organizer,
    required this.status,
  });

  // Factory pro parsování z JSON:API formátu
  factory Competition.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'];
    return Competition(
      id: json['id'],
      name: attributes['name'] ?? 'Neznámá soutěž',
      location: attributes['location'] ?? 'Neznámé místo',
      // Datum může přijít jako string, musíme ho parsovat
      dateStart:
          DateTime.tryParse(attributes['dateStart'] ?? '') ?? DateTime.now(),
      organizer: attributes['organizer'],
      status: attributes['status'] is int
          ? attributes['status']
          : int.tryParse(attributes['status'].toString()) ?? 0,
    );
  }
}
