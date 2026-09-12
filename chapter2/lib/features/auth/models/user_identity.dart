import 'package:equatable/equatable.dart';

class UserIdentity extends Equatable {
  const UserIdentity({
    required this.id,
    this.email,
    this.name,
    this.avatarUrl,
    this.walletAddress,
  });

  final String id;
  final String? email;
  final String? name;
  final String? avatarUrl;
  final String? walletAddress;

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    return UserIdentity(
      id: json['id'] as String? ?? '',
      email: json['email'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      walletAddress: json['walletAddress'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
        'walletAddress': walletAddress,
      };

  @override
  List<Object?> get props => [id, email, name, avatarUrl, walletAddress];
}
