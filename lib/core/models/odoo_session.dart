import 'package:equatable/equatable.dart';

class OdooSession extends Equatable {
  final int uid;
  final String db;
  final String login;
  final String sessionId;
  final String? userName;
  final String? avatarUrl;

  const OdooSession({
    required this.uid,
    required this.db,
    required this.login,
    required this.sessionId,
    this.userName,
    this.avatarUrl,
  });

  OdooSession copyWith({
    int? uid,
    String? db,
    String? login,
    String? sessionId,
    String? userName,
    String? avatarUrl,
  }) {
    return OdooSession(
      uid: uid ?? this.uid,
      db: db ?? this.db,
      login: login ?? this.login,
      sessionId: sessionId ?? this.sessionId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'db': db,
        'login': login,
        'session_id': sessionId,
        'user_name': userName,
        'avatar_url': avatarUrl,
      };

  factory OdooSession.fromJson(Map<String, dynamic> json) => OdooSession(
        uid: json['uid'] as int,
        db: json['db'] as String,
        login: json['login'] as String,
        sessionId: json['session_id'] as String,
        userName: json['user_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  @override
  List<Object?> get props => [uid, db, login, sessionId];
}
