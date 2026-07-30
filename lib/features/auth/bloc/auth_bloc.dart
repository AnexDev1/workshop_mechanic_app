import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/network/odoo_client.dart';
import '../../../core/models/odoo_session.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ── Events ─────────────────────────────────────────────────────────────────
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String serverUrl;
  final String db;
  final String login;
  final String password;
  const LoginRequested({
    required this.serverUrl,
    required this.db,
    required this.login,
    required this.password,
  });
  @override
  List<Object?> get props => [serverUrl, db, login, password];
}

class LogoutRequested extends AuthEvent {}

// ── States ──────────────────────────────────────────────────────────────────
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final OdooSession session;
  const AuthAuthenticated(this.session);
  @override
  List<Object?> get props => [session];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ────────────────────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final OdooClient _client;
  final _secureStorage = const FlutterSecureStorage();
  static const _sessionKey = 'odoo_session';
  static const _cachedOfflineSessionKey = 'cached_offline_session';
  static const _cachedOfflineLoginKey = 'cached_offline_login';
  static const _serverUrlKey = 'odoo_server_url';
  static const _offlinePasswordKey = 'offline_password';

  AuthBloc({required OdooClient client})
      : _client = client,
        super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuth);
    on<LoginRequested>(_onLogin);
    on<LogoutRequested>(_onLogout);
  }

  Future<void> _onCheckAuth(
      CheckAuthStatus event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_serverUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _client.setBaseUrl(savedUrl);
    }
    final sessionJson = prefs.getString(_sessionKey) ??
        prefs.getString(_cachedOfflineSessionKey);
    if (sessionJson != null) {
      try {
        final session = OdooSession.fromJson(jsonDecode(sessionJson));
        _client.setSession(session);
        emit(AuthAuthenticated(session));
        return;
      } catch (_) {}
    }
    emit(AuthUnauthenticated());
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final inputLogin = event.login.trim().toLowerCase();

    try {
      _client.setBaseUrl(event.serverUrl);

      String targetDb = event.db;
      if (targetDb.isEmpty) {
        final dbs = await _client.getDatabases();
        if (dbs.isEmpty) {
          throw Exception('No databases found on this server.');
        }
        targetDb = dbs.first;
      }

      final session = await _client.authenticate(
        db: targetDb,
        login: event.login,
        password: event.password,
      );

      final prefs = await SharedPreferences.getInstance();
      final sessionJson = jsonEncode(session.toJson());
      await prefs.setString(_sessionKey, sessionJson);
      await prefs.setString(_cachedOfflineSessionKey, sessionJson);
      await prefs.setString(_cachedOfflineLoginKey, inputLogin);
      await prefs.setString(_serverUrlKey, event.serverUrl);

      // Save password securely for offline login fallback
      await _secureStorage.write(
          key: _offlinePasswordKey, value: event.password);

      emit(AuthAuthenticated(session));
    } catch (e) {
      // Robust offline fallback login verification
      try {
        final savedPassword =
            await _secureStorage.read(key: _offlinePasswordKey);
        final prefs = await SharedPreferences.getInstance();
        final savedLogin = prefs.getString(_cachedOfflineLoginKey);
        final cachedSessionJson = prefs.getString(_cachedOfflineSessionKey);

        if (savedPassword != null &&
            savedPassword == event.password &&
            savedLogin != null &&
            savedLogin == inputLogin &&
            cachedSessionJson != null) {
          final session = OdooSession.fromJson(jsonDecode(cachedSessionJson));
          await prefs.setString(_sessionKey, cachedSessionJson);
          _client.setSession(session);
          emit(AuthAuthenticated(session));
          return;
        }
      } catch (_) {}

      String errStr = e.toString().replaceFirst('Exception: ', '');
      if (errStr.contains('Connection failed') ||
          errStr.contains('SocketException')) {
        errStr =
            'Network offline or server unreachable.\nIf this is your first time logging in, please connect to your network.\nIf on physical device (SM A155F), enter your PC\'s Wi-Fi IP address.';
      }

      emit(AuthError(errStr));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    emit(AuthUnauthenticated());
  }
}
