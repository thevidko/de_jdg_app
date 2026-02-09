class User {
  final String id;
  final String name;
  final String surname;

  User({required this.id, required this.name, required this.surname});

  String get fullName => '$name $surname';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      surname: json['surname'] ?? '',
    );
  }
}
