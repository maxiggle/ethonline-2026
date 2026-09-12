import 'package:equatable/equatable.dart';

class UserIdentity extends Equatable {
  const UserIdentity({
    required this.id,
    this.email,
    this.name,
    this.avatarUrl,
    this.walletAddress,
    this.isNewUser = false,
  });

  final String id;
  final String? email;
  final String? name;
  final String? avatarUrl;
  final String? walletAddress;
  final bool isNewUser;

  factory UserIdentity.fromJson(Map<String, dynamic> json, {bool isNewUser = false}) {
    return UserIdentity(
      id: json['id'] as String? ?? '',
      email: json['email'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      walletAddress: json['walletAddress'] as String?,
      isNewUser: isNewUser || (json['isNewUser'] as bool? ?? false),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
        'walletAddress': walletAddress,
        'isNewUser': isNewUser,
      };

  @override
  List<Object?> get props => [id, email, name, avatarUrl, walletAddress, isNewUser];
}
