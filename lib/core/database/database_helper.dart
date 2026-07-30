import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'mechanic_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tasks table to cache available and active tasks
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY,
        description TEXT,
        status TEXT,
        job_status TEXT,
        estimated_hours REAL,
        notes TEXT,
        is_working INTEGER,
        current_log_start TEXT,
        technician_id INTEGER,
        workshop_section_id INTEGER,
        job_id_id INTEGER,
        job_id_name TEXT,
        mrcv_status TEXT,
        mrcv_ref TEXT,
        is_my_task INTEGER
      )
    ''');

    // Sync Queue table to store offline actions
    await db.execute('''
      CREATE TABLE sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT,
        task_id INTEGER,
        payload TEXT,
        created_at TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');
  }

  // --- Task Cache Methods ---

  Future<void> cacheTasks(List<Map<String, dynamic>> tasks) async {
    final db = await database;
    final batch = db.batch();

    // Clear existing cache (or we could upsert)
    batch.delete('tasks');

    for (var task in tasks) {
      batch.insert(
          'tasks',
          {
            'id': task['id'],
            'description': task['description'],
            'status': task['status'],
            'job_status': task['job_status'],
            'estimated_hours': task['estimated_hours'],
            'notes': task['notes'] is bool ? null : task['notes'],
            'is_working': task['is_working'] == true ? 1 : 0,
            'current_log_start': task['current_log_start'] is bool
                ? null
                : task['current_log_start'],
            'technician_id': (task['technician_id'] is List &&
                    task['technician_id'].isNotEmpty)
                ? task['technician_id'][0]
                : null,
            'workshop_section_id': (task['workshop_section_id'] is List &&
                    task['workshop_section_id'].isNotEmpty)
                ? task['workshop_section_id'][0]
                : null,
            'job_id_id': (task['job_id'] is List && task['job_id'].isNotEmpty)
                ? task['job_id'][0]
                : null,
            'job_id_name': (task['job_id'] is List && task['job_id'].length > 1)
                ? task['job_id'][1]
                : null,
            'mrcv_status':
                task['mrcv_status'] is bool ? null : task['mrcv_status'],
            'mrcv_ref': task['mrcv_ref'] is bool ? null : task['mrcv_ref'],
            'is_my_task': task['is_my_task'] == true ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedTasks() async {
    final db = await database;
    final maps = await db.query('tasks');

    // Convert back to format expected by fromJson
    return maps.map((map) {
      return {
        'id': map['id'],
        'description': map['description'],
        'status': map['status'],
        'job_status': map['job_status'],
        'estimated_hours': map['estimated_hours'],
        'notes': map['notes'],
        'is_working': map['is_working'] == 1,
        'current_log_start': map['current_log_start'],
        'technician_id':
            map['technician_id'] != null ? [map['technician_id'], ''] : false,
        'workshop_section_id': map['workshop_section_id'] != null
            ? [map['workshop_section_id'], '']
            : false,
        'job_id': map['job_id_id'] != null
            ? [map['job_id_id'], map['job_id_name'] ?? '']
            : false,
        'mrcv_status': map['mrcv_status'],
        'mrcv_ref': map['mrcv_ref'],
        'is_my_task': map['is_my_task'] == 1,
      };
    }).toList();
  }

  // --- Sync Queue Methods ---

  Future<int> queueAction(String actionType, int taskId,
      {String payload = ''}) async {
    final db = await database;
    return await db.insert('sync_queue', {
      'action_type': actionType,
      'task_id': taskId,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await database;
    return await db.query('sync_queue',
        where: 'status = ?', whereArgs: ['pending'], orderBy: 'created_at ASC');
  }

  Future<int> getPendingActionCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM sync_queue WHERE status = 'pending'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markActionCompleted(int id) async {
    final db = await database;
    await db.update('sync_queue', {'status': 'completed'},
        where: 'id = ?', whereArgs: [id]);
  }
}
