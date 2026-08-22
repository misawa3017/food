class AuthUser {
  const AuthUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.providerIds,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final List<String> providerIds;
}
