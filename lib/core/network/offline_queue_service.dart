import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'odoo_client.dart';

class QueuedAction {
  final String id;
  final String method;
  final Map<String, dynamic> params;
  final DateTime timestamp;

  QueuedAction({
    required this.id,
    required this.method,
    required this.params,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'params': params,
        'timestamp': timestamp.toIso8601String(),
      };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
        id: json['id'],
        method: json['method'],
        params: Map<String, dynamic>.from(json['params']),
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class OfflineQueueService {
  static const String _queueKey = 'offline_action_queue';
  final OdooClient _odooClient;

  OfflineQueueService(this._odooClient);

  Future<void> enqueueAction({
    required String method,
    required Map<String, dynamic> params,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queueJson = prefs.getStringList(_queueKey) ?? [];

    final action = QueuedAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: method,
      params: params,
      timestamp: DateTime.now(),
    );

    queueJson.add(jsonEncode(action.toJson()));
    await prefs.setStringList(_queueKey, queueJson);
  }

  Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queueJson = prefs.getStringList(_queueKey) ?? [];
    return queueJson.length;
  }

  Future<void> processQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queueJson = prefs.getStringList(_queueKey) ?? [];
    if (queueJson.isEmpty) return;

    final List<String> remainingQueue = [];

    for (final item in queueJson) {
      try {
        final action = QueuedAction.fromJson(jsonDecode(item));
        if (action.method == 'call_kw') {
          await _odooClient.callKw(
            model: action.params['model'],
            method: action.params['method'],
            args: action.params['args'] ?? [],
            kwargs: action.params['kwargs'] ?? {},
          );
        }
      } catch (e) {
        // Keep in queue if server request fails
        remainingQueue.add(item);
      }
    }

    await prefs.setStringList(_queueKey, remainingQueue);
  }
}
