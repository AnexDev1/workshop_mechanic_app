import '../../../core/network/odoo_client.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/hive_task_cache.dart';
import '../../../core/sync/sync_manager.dart';
import '../domain/models/workshop_task.dart';

class TaskRepository {
  final OdooClient _client;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final HiveTaskCache _taskCache;
  final SyncManager _syncManager = SyncManager();

  TaskRepository({
    required OdooClient client,
    required HiveTaskCache taskCache,
  })  : _client = client,
        _taskCache = taskCache;

  String _myTasksCacheKey(String? statusFilter) =>
      'my_tasks_${_client.session!.uid}_${statusFilter ?? 'all'}';

  String get _availableTasksCacheKey =>
      'available_tasks_${_client.session!.uid}';

  static const List<String> _taskFields = [
    'id',
    'description',
    'status',
    'estimated_hours',
    'notes',
    'status',
    'job_status',
    'is_working',
    'current_log_start',
    'technician_id',
    'workshop_section_id',
    'job_id',
    'notes',
    'mrcv_status',
    'mrcv_ref',
  ];

  List<WorkshopTask> _getCachedMyTasks(String? statusFilter) {
    var cached = _taskCache.getTasks(_myTasksCacheKey(statusFilter));
    if (cached.isEmpty && statusFilter != null && statusFilter != 'all') {
      cached = _taskCache
          .getTasks(_myTasksCacheKey(null))
          .where((task) => task['status'] == statusFilter)
          .toList();
    }
    if (statusFilter != null && statusFilter != 'all') {
      cached = cached.where((task) => task['status'] == statusFilter).toList();
    }
    return cached.map(WorkshopTask.fromOdoo).toList();
  }

  /// Fetch tasks assigned to the logged-in mechanic
  Future<List<WorkshopTask>> getMyTasks({String? statusFilter}) async {
    if (!_syncManager.isOnline) {
      return _getCachedMyTasks(statusFilter);
    }

    final domain = <dynamic>[
      ['technician_id.user_id', '=', _client.session!.uid],
    ];
    if (statusFilter != null && statusFilter != 'all') {
      domain.add(['status', '=', statusFilter]);
    } else {
      domain.add([
        'status',
        'not in',
        ['closed']
      ]);
    }

    try {
      final records = await _client.searchRead(
        model: 'workshop.task',
        domain: domain,
        fields: _taskFields,
        order: 'id desc',
      );

      // Update local cache
      await _taskCache.saveTasks(_myTasksCacheKey(statusFilter), records);

      return records.map(WorkshopTask.fromOdoo).toList();
    } catch (e) {
      return _getCachedMyTasks(statusFilter);
    }
  }

  /// Fetch available tasks in the mechanic's section
  Future<List<WorkshopTask>> getAvailableTasks() async {
    if (!_syncManager.isOnline) {
      return _taskCache
          .getTasks(_availableTasksCacheKey)
          .map(WorkshopTask.fromOdoo)
          .toList();
    }

    try {
      // 1. Get mechanic's section_id
      final records = await _client.searchRead(
        model: 'workshop.technician',
        domain: [
          ['user_id', '=', _client.session!.uid]
        ],
        fields: ['section_id'],
        limit: 1,
      );
      if (records.isEmpty) return [];

      final sectionField = records.first['section_id'];
      if (sectionField is! List || sectionField.isEmpty) return [];
      final sectionId = sectionField[0] as int;

      // 2. Search tasks in this section without a technician
      final tasks = await _client.searchRead(
        model: 'workshop.task',
        domain: [
          ['workshop_section_id', '=', sectionId],
          ['technician_id', '=', false],
          ['status', '=', 'created'],
        ],
        fields: _taskFields,
        order: 'id desc',
      );

      // Filter in Dart to avoid Odoo XML-RPC domain issues with related/un-stored fields
      final filteredTasks = tasks.where((t) {
        final jobStatus = t['job_status'];
        return jobStatus == 'assigned' || jobStatus == 'inprogress';
      }).toList();

      await _taskCache.saveTasks(_availableTasksCacheKey, filteredTasks);

      return filteredTasks.map(WorkshopTask.fromOdoo).toList();
    } catch (e) {
      final cached = _taskCache.getTasks(_availableTasksCacheKey);
      return cached.map(WorkshopTask.fromOdoo).toList();
    }
  }

  /// Claim an available task
  Future<void> takeTask(int taskId) async {
    if (_syncManager.isOnline) {
      try {
        await _client.callKw(
          model: 'workshop.task',
          method: 'action_take_task',
          args: [
            [taskId]
          ],
        );
        return;
      } catch (_) {}
    }
    await _dbHelper.queueAction('claim', taskId);
  }

  /// Start the timer for a task
  Future<void> startTimer(int taskId) async {
    if (_syncManager.isOnline) {
      try {
        await _client.callKw(
          model: 'workshop.task',
          method: 'action_start_timer',
          args: [
            [taskId]
          ],
        );
        await _cacheTaskStarted(taskId);
        return;
      } catch (_) {}
    }
    await _dbHelper.queueAction('start_timer', taskId);
    await _cacheTaskStarted(taskId);
  }

  /// Stop the timer for a task
  Future<void> stopTimer(int taskId) async {
    if (_syncManager.isOnline) {
      try {
        await _client.callKw(
          model: 'workshop.task',
          method: 'action_stop_timer',
          args: [
            [taskId]
          ],
        );
        await _cacheTaskStopped(taskId);
        return;
      } catch (_) {}
    }
    await _dbHelper.queueAction('stop_timer', taskId);
    await _cacheTaskStopped(taskId);
  }

  /// Get the mechanic's MRCV requests
  Future<List<Map<String, dynamic>>> getMyMrcvRequests() async {
    final uid = _client.session?.uid;
    if (uid == null) return [];

    return await _client.searchRead(
      model: 'mrcv.header',
      domain: [
        ['create_uid', '=', uid]
      ],
      fields: ['name', 'state', 'workshop_order_id', 'create_date'],
      order: 'create_date desc',
    );
  }

  /// Get the mechanic's outsource requests
  Future<List<Map<String, dynamic>>> getMyOutsourceRequests() async {
    final uid = _client.session?.uid;
    if (uid == null) return [];

    return await _client.searchRead(
      model: 'workshop.outsource.request',
      domain: [
        ['requester_id', '=', uid]
      ],
      fields: ['name', 'state', 'workshop_order_id', 'date'],
      order: 'date desc',
    );
  }

  /// Mark a task as done (Section Check)
  Future<void> markTaskDone(int taskId) async {
    if (_syncManager.isOnline) {
      try {
        await _client.callKw(
          model: 'workshop.task',
          method: 'action_done',
          args: [
            [taskId]
          ],
        );
        await _cacheTaskCompleted(taskId);
        return;
      } catch (_) {}
    }
    await _dbHelper.queueAction('mark_done', taskId);
    await _cacheTaskCompleted(taskId);
  }

  Future<void> _cacheTaskStarted(int taskId) {
    return _taskCache.updateTask(
      _client.session!.uid,
      taskId,
      {
        'status': 'working',
        'is_working': true,
        'current_log_start': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> _cacheTaskStopped(int taskId) {
    return _taskCache.updateTask(
      _client.session!.uid,
      taskId,
      {
        'is_working': false,
        'current_log_start': false,
      },
    );
  }

  Future<void> _cacheTaskCompleted(int taskId) {
    return _taskCache.updateTask(
      _client.session!.uid,
      taskId,
      {
        'status': 'completed',
        'is_working': false,
        'current_log_start': false,
      },
    );
  }

  /// Submit an Outsource Request from the app
  Future<void> requestOutsource({
    required int taskId,
    required int jobId,
    required String reason,
    double? estimatedCost,
  }) async {
    await _client.callKw(
      model: 'workshop.outsource.request',
      method: 'create',
      args: [
        {
          'workshop_order_id': jobId,
          'task_id': taskId,
          'reason': reason,
          'estimated_cost': estimatedCost ?? 0.0,
        }
      ],
    );
  }

  /// Mobile Check-In with GPS coordinates. Returns true if synced live, false if queued offline.
  Future<bool> checkIn(double lat, double lng) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    if (_syncManager.isOnline) {
      try {
        await _client.callKw(
          model: 'workshop.duty.log',
          method: 'action_mobile_check_in',
          args: [lat, lng, timestamp],
        );
        await _taskCache.saveDutyStatus(_client.session!.uid, true);
        return true;
      } catch (e) {
        // Fallback to queue if RPC fails due to connectivity
        await _dbHelper.queueAction(
          'check_in',
          0,
          payload: '{"lat": $lat, "lng": $lng, "timestamp": "$timestamp"}',
        );
        await _taskCache.saveDutyStatus(_client.session!.uid, true);
        return false;
      }
    } else {
      await _dbHelper.queueAction(
        'check_in',
        0,
        payload: '{"lat": $lat, "lng": $lng, "timestamp": "$timestamp"}',
      );
      await _taskCache.saveDutyStatus(_client.session!.uid, true);
      return false;
    }
  }

  /// Mobile Check-Out with GPS coordinates. Returns true if synced live, false if queued offline.
  Future<bool> checkOut(double lat, double lng) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    if (_syncManager.isOnline) {
      try {
        await _client.callKw(
          model: 'workshop.duty.log',
          method: 'action_mobile_check_out',
          args: [lat, lng, timestamp],
        );
        await _taskCache.saveDutyStatus(_client.session!.uid, false);
        return true;
      } catch (e) {
        await _dbHelper.queueAction(
          'check_out',
          0,
          payload: '{"lat": $lat, "lng": $lng, "timestamp": "$timestamp"}',
        );
        await _taskCache.saveDutyStatus(_client.session!.uid, false);
        return false;
      }
    } else {
      await _dbHelper.queueAction(
        'check_out',
        0,
        payload: '{"lat": $lat, "lng": $lng, "timestamp": "$timestamp"}',
      );
      await _taskCache.saveDutyStatus(_client.session!.uid, false);
      return false;
    }
  }

  /// Fetch duty status for logged in mechanic
  Future<Map<String, dynamic>> getDutyStatus() async {
    if (_syncManager.isOnline) {
      try {
        final res = await _client.callKw(
          model: 'workshop.duty.log',
          method: 'get_duty_status',
        );
        final status = Map<String, dynamic>.from(res);
        await _taskCache.saveDutyStatus(
          _client.session!.uid,
          status['is_checked_in'] == true,
        );
        return status;
      } catch (_) {}
    }
    return {
      'is_checked_in': _taskCache.getDutyStatus(_client.session!.uid),
    };
  }

  Future<int> getPendingSyncCount() => _syncManager.getPendingCount();

  Future<SyncResult> syncPendingActions() => _syncManager.manualSync();

  /// Create an MRCV material request from the mobile app
  Future<void> createMrcvRequest({
    required int jobId,
    required int warehouseId,
    required int productId,
    required double quantity,
    String? reason,
  }) async {
    await _client.callKw(
      model: 'mrcv.header',
      method: 'action_create_from_mobile',
      args: [jobId, warehouseId, productId, quantity, reason],
    );
  }

  /// Get available warehouses for MRCV creation
  Future<Map<String, dynamic>> getMrcvContext(int jobId) async {
    final result = await _client.callKw(
      model: 'mrcv.header',
      method: 'get_mobile_mrcv_context',
      args: [
        [jobId]
      ],
    );
    return result as Map<String, dynamic>;
  }

  /// Search products with available stock in a specific warehouse
  Future<List<Map<String, dynamic>>> searchWarehouseProducts(
      int locationId, String query) async {
    final domain = <dynamic>[
      ['location_id', 'child_of', locationId],
      ['quantity', '>', 0],
    ];
    if (query.isNotEmpty) {
      domain.add(['product_id.name', 'ilike', query]);
    }

    final records = await _client.searchRead(
      model: 'stock.quant',
      domain: domain,
      fields: ['product_id', 'quantity'],
      limit: 50,
    );

    final Map<int, Map<String, dynamic>> products = {};
    for (var r in records) {
      final prodField = r['product_id'];
      if (prodField is! List || prodField.isEmpty) continue;

      final pId = prodField[0] as int;
      final pName = prodField[1] as String;
      final qty = (r['quantity'] as num?)?.toDouble() ?? 0.0;

      if (products.containsKey(pId)) {
        products[pId]!['quantity'] =
            (products[pId]!['quantity'] as double) + qty;
      } else {
        products[pId] = {'id': pId, 'name': pName, 'quantity': qty};
      }
    }

    return products.values.toList();
  }

  /// Get active time log for a task (for live timer)
  Future<Map<String, dynamic>?> getActiveLog(int taskId) async {
    final logs = await _client.searchRead(
      model: 'workshop.time.log',
      domain: [
        ['task_id', '=', taskId],
        ['mechanic_id', '=', _client.session!.uid],
        ['stop_time', '=', false],
      ],
      fields: ['id', 'start_time', 'task_id'],
      limit: 1,
    );
    return logs.isNotEmpty ? logs.first : null;
  }

  /// Get mechanic daily working vs idle time performance metrics
  Future<Map<String, dynamic>> getMechanicPerformance() async {
    final fallbackName =
        _client.session?.userName ?? _client.session?.login ?? 'Technician';
    if (_client.session == null) {
      return {
        'name': fallbackName,
        'section': 'Workshop',
        'working_hours': 0.0,
        'idle_hours': 0.0,
        'efficiency': 0.0,
      };
    }
    try {
      final records = await _client.searchRead(
        model: 'workshop.technician',
        domain: [
          ['user_id', '=', _client.session!.uid]
        ],
        fields: [
          'id',
          'name',
          'task_time_today',
          'idle_time_today',
          'section_id'
        ],
        limit: 1,
      );
      if (records.isNotEmpty) {
        final rec = records.first;
        final working = (rec['task_time_today'] as num?)?.toDouble() ?? 0.0;
        final idle = (rec['idle_time_today'] as num?)?.toDouble() ?? 0.0;
        final total = working + idle;
        final efficiency =
            total > 0 ? (working / total * 100).roundToDouble() : 0.0;

        String? section;
        if (rec['section_id'] is List &&
            (rec['section_id'] as List).length == 2) {
          section = (rec['section_id'] as List)[1] as String;
        }

        return {
          'name': rec['name'] is String && (rec['name'] as String).isNotEmpty
              ? rec['name']
              : fallbackName,
          'section': section ?? 'Workshop',
          'working_hours': working,
          'idle_hours': idle,
          'efficiency': efficiency,
        };
      } else {
        final logs = await _client.searchRead(
          model: 'workshop.time.log',
          domain: [
            ['mechanic_id', '=', _client.session!.uid],
          ],
          fields: ['duration', 'task_id'],
        );
        double working = 0.0;
        double idle = 0.0;
        for (final l in logs) {
          final dur = (l['duration'] as num?)?.toDouble() ?? 0.0;
          if (l['task_id'] != null && l['task_id'] != false) {
            working += dur;
          } else {
            idle += dur;
          }
        }
        final total = working + idle;
        final efficiency =
            total > 0 ? (working / total * 100).roundToDouble() : 0.0;
        return {
          'name': fallbackName,
          'section': 'Workshop',
          'working_hours': working,
          'idle_hours': idle,
          'efficiency': efficiency,
        };
      }
    } catch (_) {}
    return {
      'name': fallbackName,
      'section': 'Workshop',
      'working_hours': 0.0,
      'idle_hours': 0.0,
      'efficiency': 0.0,
    };
  }
}
