import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() => _instance;
  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'ratig.db');
    debugPrint("DBHelper: _initDB path=$path");
    return await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        debugPrint("DBHelper: onCreate version=$version");
        await _createDB(db, version);
      },
      onUpgrade: (db, oldV, newV) async {
        debugPrint("DBHelper: onUpgrade old=$oldV, new=$newV");
        await _upgradeDB(db, oldV, newV);
      },
      onOpen: (db) async {
        debugPrint("DBHelper: onOpen database opened");
        try {
          await _upgradeDB(db, 0, 5);
          debugPrint("DBHelper: onOpen schema migration completed");
        } catch (e, s) {
          debugPrint("DBHelper: onOpen schema migration failed: $e\n$s");
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Identik init_db() di RATIG.py
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_karyawan (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        nama            TEXT,
        nik             TEXT UNIQUE,
        usia            TEXT,
        jabatan         TEXT,
        jenis_kelamin   TEXT,
        tanggal_lahir   TEXT,
        info_pekerjaan  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_kontraktor (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        nama            TEXT,
        nik             TEXT UNIQUE,
        usia            TEXT,
        jabatan         TEXT,
        jenis_kelamin   TEXT,
        tanggal_lahir   TEXT,
        info_pekerjaan  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS results (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal             TEXT,
        nama                TEXT,
        nik                 TEXT,
        usia                TEXT,
        jenis_kelamin       TEXT,
        jabatan             TEXT,
        contractor          TEXT,
        plan                TEXT,
        divisi              TEXT,
        mode                TEXT,
        trial               TEXT,
        reaction_time       REAL,
        t1 REAL, t2 REAL, t3 REAL,
        t4 REAL, t5 REAL, t6 REAL,
        avg_reaction        REAL,
        status              TEXT,
        fatigue_level       TEXT,
        td_sistol           REAL,
        td_diastol          REAL,
        nadi                REAL,
        alcohol_test        REAL,
        kesimpulan_sistol   TEXT,
        kesimpulan_diastol  TEXT,
        kesimpulan_nadi     TEXT,
        keputusan           TEXT,
        rekomendasi         TEXT,
        keterangan          TEXT,
        kesimpulan_alkohol  TEXT,
        keluhan             TEXT,
        diagnosis_awal      TEXT,
        tindakan_medis      TEXT,
        pemberian_obat      TEXT
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_nik     ON results(nik)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tanggal ON results(tanggal)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fatigue ON results(fatigue_level)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mk_nik  ON master_karyawan(nik)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mk2_nik ON master_kontraktor(nik)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // 1. Pastikan tabel master_karyawan ada
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_karyawan (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        nama            TEXT,
        nik             TEXT UNIQUE,
        usia            TEXT,
        jabatan         TEXT,
        jenis_kelamin   TEXT,
        tanggal_lahir   TEXT,
        info_pekerjaan  TEXT
      )
    ''');

    // 2. Pastikan tabel master_kontraktor ada
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_kontraktor (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        nama            TEXT,
        nik             TEXT UNIQUE,
        usia            TEXT,
        jabatan         TEXT,
        jenis_kelamin   TEXT,
        tanggal_lahir   TEXT,
        info_pekerjaan  TEXT
      )
    ''');

    // 3. Pastikan tabel results ada
    await db.execute('''
      CREATE TABLE IF NOT EXISTS results (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal             TEXT,
        nama                TEXT,
        nik                 TEXT,
        usia                TEXT,
        jenis_kelamin       TEXT,
        jabatan             TEXT,
        contractor          TEXT,
        plan                TEXT,
        divisi              TEXT,
        mode                TEXT,
        trial               TEXT,
        reaction_time       REAL,
        t1 REAL, t2 REAL, t3 REAL,
        t4 REAL, t5 REAL, t6 REAL,
        avg_reaction        REAL,
        status              TEXT,
        fatigue_level       TEXT,
        td_sistol           REAL,
        td_diastol          REAL,
        nadi                REAL,
        alcohol_test        REAL,
        kesimpulan_sistol   TEXT,
        kesimpulan_diastol  TEXT,
        kesimpulan_nadi     TEXT,
        keputusan           TEXT,
        rekomendasi         TEXT,
        keterangan          TEXT,
        kesimpulan_alkohol  TEXT,
        keluhan             TEXT,
        diagnosis_awal      TEXT,
        tindakan_medis      TEXT,
        pemberian_obat      TEXT
      )
    ''');

    // 4. Migrasi kolom master_karyawan jika ada yang belum ada
    final mkCols = (await db.rawQuery("PRAGMA table_info(master_karyawan)"))
        .map((c) => c['name'] as String).toSet();
    for (final col in ['nama', 'nik', 'usia', 'jabatan', 'jenis_kelamin', 'tanggal_lahir', 'info_pekerjaan']) {
      if (!mkCols.contains(col)) {
        try { await db.execute('ALTER TABLE master_karyawan ADD COLUMN $col TEXT'); } catch (_) {}
      }
    }

    // 5. Migrasi kolom master_kontraktor jika ada yang belum ada
    final mkoCols = (await db.rawQuery("PRAGMA table_info(master_kontraktor)"))
        .map((c) => c['name'] as String).toSet();
    for (final col in ['nama', 'nik', 'usia', 'jabatan', 'jenis_kelamin', 'tanggal_lahir', 'info_pekerjaan']) {
      if (!mkoCols.contains(col)) {
        try { await db.execute('ALTER TABLE master_kontraktor ADD COLUMN $col TEXT'); } catch (_) {}
      }
    }

    // 6. Migrasi kolom results jika ada yang belum ada
    final resCols = (await db.rawQuery("PRAGMA table_info(results)"))
        .map((c) => c['name'] as String).toSet();
    final resMig = {
      'contractor': 'TEXT', 'plan': 'TEXT', 'trial': 'TEXT',
      'reaction_time': 'REAL', 'status': 'TEXT',
      'jenis_kelamin': 'TEXT', 'kesimpulan_alkohol': 'TEXT',
      'keluhan': 'TEXT', 'diagnosis_awal': 'TEXT',
      'tindakan_medis': 'TEXT', 'pemberian_obat': 'TEXT',
      'td_sistol': 'REAL', 'td_diastol': 'REAL', 'nadi': 'REAL',
      'alcohol_test': 'REAL', 'kesimpulan_sistol': 'TEXT',
      'kesimpulan_diastol': 'TEXT', 'kesimpulan_nadi': 'TEXT',
      'keputusan': 'TEXT', 'rekomendasi': 'TEXT', 'keterangan': 'TEXT',
    };
    for (final e in resMig.entries) {
      if (!resCols.contains(e.key)) {
        try { await db.execute('ALTER TABLE results ADD COLUMN ${e.key} ${e.value}'); } catch (_) {}
      }
    }

    // 7. Buat indeks jika belum ada
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_nik     ON results(nik)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_tanggal ON results(tanggal)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_fatigue ON results(fatigue_level)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_mk_nik  ON master_karyawan(nik)'); } catch (_) {}
    try { await db.execute('CREATE INDEX IF NOT EXISTS idx_mk2_nik ON master_kontraktor(nik)'); } catch (_) {}
  }

  Future<T> _runSafe<T>(Future<T> Function(Database db) action) async {
    final db = await database;
    try {
      return await action(db);
    } catch (e) {
      if (e.toString().contains('no such table')) {
        debugPrint("DBHelper: 'no such table' detected, running schema repair...");
        try {
          await _upgradeDB(db, 0, 4);
        } catch (repairErr) {
          debugPrint("DBHelper: schema repair failed: $repairErr");
        }
        return await action(db);
      }
      rethrow;
    }
  }

  // ── RESULTS ────────────────────────────────────────────────────────

  Future<int> insertResult(Map<String, dynamic> row) async {
    return await _runSafe((db) => db.insert('results', row));
  }

  /// Insert hasil tes dengan deteksi duplikat multi-field (nik, tanggal, avg_reaction, t1, t2)
  /// dan otomatis sync/upsert ke master_karyawan (identik RATIG.py)
  Future<bool> insertResultWithDuplicateCheck(Map<String, dynamic> row) async {
    return await _runSafe((db) async {
      final nik = (row['nik'] ?? '').toString().trim().toUpperCase();
      if (nik.isEmpty || nik == 'NULL' || nik == 'NONE' || nik == 'NAN') {
        return false; // Skip NIK kosong / tidak valid
      }

      final tanggal = (row['tanggal'] ?? '').toString().trim();
      final avg = (row['avg_reaction'] as num?)?.toDouble() ?? 0.0;
      final t1 = (row['t1'] as num?)?.toDouble() ?? 0.0;
      final t2 = (row['t2'] as num?)?.toDouble() ?? 0.0;

      // Cek apakah data dengan NIK, tanggal, avg, t1, t2 yang sama sudah ada di DB
      final existing = await db.query(
        'results',
        where: 'UPPER(nik) = ? AND tanggal = ? AND ABS(COALESCE(avg_reaction,0) - ?) < 0.01 AND ABS(COALESCE(t1,0) - ?) < 0.01 AND ABS(COALESCE(t2,0) - ?) < 0.01',
        whereArgs: [nik, tanggal, avg, t1, t2],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return false; // Duplikat persis, lewati
      }

      // Insert ke tabel results
      await db.insert('results', row);

      // Auto-sync / upsert master data jika informasi karyawan tersedia
      final nama = (row['nama'] ?? '').toString().trim();
      if (nama.isNotEmpty) {
        final contractor = (row['contractor'] ?? '').toString().trim();
        final isKontraktor = contractor.isNotEmpty;
        final masterRow = {
          'nama': nama,
          'nik': nik,
          'usia': (row['usia'] ?? '').toString(),
          'jenis_kelamin': (row['jenis_kelamin'] ?? 'Laki-laki').toString(),
          'jabatan': (row['jabatan'] ?? '').toString(),
          'info_pekerjaan': isKontraktor ? contractor : (row['divisi'] ?? row['plan'] ?? '').toString(),
        };
        await upsertKaryawan(masterRow, isKontraktor: isKontraktor);
      }

      return true;
    });
  }

  Future<List<Map<String, dynamic>>> getAllResults() async {
    return await _runSafe((db) => db.query('results', orderBy: 'id DESC'));
  }

  Future<List<Map<String, dynamic>>> getResultsByNik(String nik) async {
    return await _runSafe((db) => db.query('results',
        where: 'nik = ?', whereArgs: [nik], orderBy: 'tanggal ASC'));
  }

  /// Hitung tes harian per NIK — identik RATIG.py
  Future<int> getTodayTestCount(String nik) async {
    return await _runSafe((db) async {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final result = await db.rawQuery(
        "SELECT COUNT(id) as cnt FROM results WHERE nik=? AND tanggal LIKE ?",
        [nik, '$today%'],
      );
      if (result.isNotEmpty) {
        return (result.first['cnt'] as num?)?.toInt() ?? 0;
      }
      return 0;
    });
  }

  /// Cek duplikat: 1x per hari per NIK — identik RATIG.py
  Future<bool> isAlreadyTestedToday(String nik) async {
    final cnt = await getTodayTestCount(nik);
    return cnt >= 1;
  }

  /// Update medis: gunakan COALESCE agar tidak overwrite data yang sudah ada
  Future<int> updateMedis(int id, Map<String, dynamic> data) async {
    return await _runSafe((db) async {
      final filtered = <String, dynamic>{};
      data.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) filtered[k] = v;
      });
      if (filtered.isEmpty) return 0;
      return await db.update('results', filtered, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> deleteResult(int id) async {
    return await _runSafe((db) => db.delete('results', where: 'id = ?', whereArgs: [id]));
  }

  Future<void> deleteAll() async {
    await _runSafe((db) => db.delete('results'));
  }

  Future<void> deleteResults(List<int> ids) async {
    if (ids.isEmpty) return;
    await _runSafe((db) async {
      final placeholders = ids.map((_) => '?').join(',');
      await db.rawDelete(
          'DELETE FROM results WHERE id IN ($placeholders)', ids);
    });
  }

  /// Filter riwayat — semua parameter opsional, mirip _apply_filter() RATIG.py
  Future<List<Map<String, dynamic>>> getFilteredResults({
    String? tanggalDari,
    String? tanggalSampai,
    String? jabatan,
    String? fatigueLevel,
    String? keputusan,
    String? searchNamaNik,
  }) async {
    return await _runSafe((db) async {
      final List<String> conditions = [];
      final List<dynamic> args = [];

      if (tanggalDari != null && tanggalDari.isNotEmpty) {
        conditions.add('DATE(tanggal) >= ?');
        args.add(tanggalDari);
      }
      if (tanggalSampai != null && tanggalSampai.isNotEmpty) {
        conditions.add('DATE(tanggal) <= ?');
        args.add(tanggalSampai);
      }
      if (jabatan != null && jabatan.isNotEmpty) {
        conditions.add('LOWER(jabatan) LIKE ?');
        args.add('%${jabatan.toLowerCase()}%');
      }
      if (fatigueLevel != null &&
          fatigueLevel.isNotEmpty &&
          fatigueLevel != 'Semua') {
        conditions.add('fatigue_level = ?');
        args.add(fatigueLevel);
      }
      if (keputusan != null &&
          keputusan.isNotEmpty &&
          keputusan != 'Semua') {
        conditions.add('keputusan = ?');
        args.add(keputusan);
      }
      if (searchNamaNik != null && searchNamaNik.isNotEmpty) {
        conditions.add('(LOWER(nama) LIKE ? OR LOWER(nik) LIKE ?)');
        args.add('%${searchNamaNik.toLowerCase()}%');
        args.add('%${searchNamaNik.toLowerCase()}%');
      }

      final where =
          conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
      return await db.rawQuery(
          'SELECT * FROM results $where ORDER BY id DESC', args);
    });
  }

  /// Jumlah tes per hari — 14 hari terakhir, untuk grafik batang
  Future<List<Map<String, dynamic>>> getDailyCount({int days = 14}) async {
    return await _runSafe((db) async {
      return await db.rawQuery('''
        SELECT DATE(tanggal) as date, COUNT(*) as count
        FROM results
        WHERE DATE(tanggal) >= DATE('now', '-${days - 1} days')
        GROUP BY DATE(tanggal)
        ORDER BY date ASC
      ''');
    });
  }

  /// Distribusi fatigue per jabatan/divisi — untuk grafik divisi
  Future<List<Map<String, dynamic>>> getFatigueByDivisi() async {
    return await _runSafe((db) async {
      return await db.rawQuery('''
        SELECT COALESCE(NULLIF(jabatan,''), 'Tidak Diketahui') as divisi,
               fatigue_level,
               COUNT(*) as count
        FROM results
        GROUP BY divisi, fatigue_level
        ORDER BY divisi ASC, fatigue_level ASC
      ''');
    });
  }

  // ── MASTER KARYAWAN ────────────────────────────────────────────────

  Future<int> upsertKaryawan(Map<String, dynamic> row, {bool isKontraktor = false}) async {
    return await _runSafe((db) {
      final table = isKontraktor ? 'master_kontraktor' : 'master_karyawan';
      return db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, dynamic>>> getAllKaryawan({bool isKontraktor = false}) async {
    return await _runSafe((db) {
      final table = isKontraktor ? 'master_kontraktor' : 'master_karyawan';
      return db.query(table, orderBy: 'nama ASC');
    });
  }

  /// Autofill: cek master_karyawan → master_kontraktor → results (identik Python)
  Future<Map<String, dynamic>?> autofillByNik(String nik) async {
    return await _runSafe((db) async {
      // 1. Cari di master_karyawan
      var res = await db.rawQuery(
        "SELECT nama, usia, tanggal_lahir, jenis_kelamin, jabatan, info_pekerjaan as divisi "
        "FROM master_karyawan WHERE nik=? LIMIT 1", [nik]);
      if (res.isNotEmpty) return res.first;

      // 2. Cari di master_kontraktor
      res = await db.rawQuery(
        "SELECT nama, usia, tanggal_lahir, jenis_kelamin, jabatan, info_pekerjaan as divisi "
        "FROM master_kontraktor WHERE nik=? LIMIT 1", [nik]);
      if (res.isNotEmpty) return res.first;

      // 3. Fallback: ambil dari riwayat tes terakhir
      res = await db.rawQuery(
        "SELECT nama, usia, null as tanggal_lahir, jenis_kelamin, jabatan, divisi "
        "FROM results WHERE nik=? ORDER BY id DESC LIMIT 1", [nik]);
      if (res.isNotEmpty) return res.first;

      return null;
    });
  }

  Future<List<String>> getAllNiks() async {
    return await _runSafe((db) async {
      final r1 = await db.rawQuery(
          "SELECT DISTINCT nik FROM results WHERE nik IS NOT NULL AND nik!=''");
      final r2 = await db.rawQuery(
          "SELECT DISTINCT nik FROM master_karyawan WHERE nik IS NOT NULL AND nik!=''");
      final r3 = await db.rawQuery(
          "SELECT DISTINCT nik FROM master_kontraktor WHERE nik IS NOT NULL AND nik!=''");
      final all = <String>{};
      for (final r in [...r1, ...r2, ...r3]) {
        all.add(r['nik'] as String);
      }
      return all.toList()..sort();
    });
  }

  Future<int> deleteKaryawan(int id, {bool isKontraktor = false}) async {
    return await _runSafe((db) {
      final table = isKontraktor ? 'master_kontraktor' : 'master_karyawan';
      return db.delete(table, where: 'id = ?', whereArgs: [id]);
    });
  }

  // ── STATISTIK ──────────────────────────────────────────────────────

  Future<Map<String, int>> getFatigueSummary() async {
    return await _runSafe((db) async {
      final rows = await db.rawQuery(
          "SELECT fatigue_level, COUNT(*) as cnt FROM results GROUP BY fatigue_level");
      final Map<String, int> summary = {
        'Normal': 0, 'Fatigue Ringan': 0, 'Fatigue Sedang': 0, 'Fatigue Berat': 0,
      };
      for (final r in rows) {
        final key = r['fatigue_level'] as String? ?? '';
        if (summary.containsKey(key)) {
          summary[key] = (r['cnt'] as int?) ?? 0;
        }
      }
      return summary;
    });
  }

  /// Cek apakah karyawan mengalami Fatigue Berat 3x berturut-turut (identik Python)
  Future<bool> checkConsecutiveBerat(String nik) async {
    return await _runSafe((db) async {
      final rows = await db.rawQuery(
          "SELECT fatigue_level FROM results WHERE nik=? ORDER BY id DESC LIMIT 3", [nik]);
      if (rows.length < 3) return false;
      return rows.every((r) => r['fatigue_level'] == 'Fatigue Berat');
    });
  }

  Future<List<String>> getTables() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      return tables.map((t) => t['name'] as String).toList();
    } catch (e) {
      return ['Error: $e'];
    }
  }

  Future<void> recreateDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      String path = join(await getDatabasesPath(), 'ratig.db');
      await deleteDatabase(path);
      _database = await _initDB();
      debugPrint("DBHelper: Database recreated successfully");
    } catch (e) {
      debugPrint("DBHelper: Failed to recreate database: $e");
    }
  }

  Future<String> getDatabaseFilePath() async {
    return join(await getDatabasesPath(), 'ratig.db');
  }

  Future<void> restoreDatabase(Uint8List bytes) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    String path = join(await getDatabasesPath(), 'ratig.db');
    final file = File(path);
    await file.writeAsBytes(bytes);
    _database = await _initDB();
  }
}
