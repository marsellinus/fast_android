import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  String companyName = 'PT. NAMA PERUSAHAAN';
  String appName = 'FAST';
  int baudRate = 115200;
  int ageWarningThreshold = 60;
  int dailyTestLimit = 3;
  int chartLimit = 500;
  int tableLimit = 500;
  String adminPin = '1234';
  String paramedisPin = 'paramedis123';
  bool autoConnect = true;
  bool autoBackup = true;
  String downloadPath = '/storage/emulated/0/Download';

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> load() async {
    try {
      final f = await _file;
      if (await f.exists()) {
        final content = await f.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        
        companyName = map['company_name'] ?? 'PT. NAMA PERUSAHAAN';
        appName = map['app_name']?.toString() ?? 'FAST';
        baudRate = map['baudrate'] is int ? map['baudrate'] : int.tryParse(map['baudrate']?.toString() ?? '115200') ?? 115200;
        ageWarningThreshold = map['age_warning_threshold'] is int ? map['age_warning_threshold'] : int.tryParse(map['age_warning_threshold']?.toString() ?? '60') ?? 60;
        dailyTestLimit = map['daily_test_limit'] is int ? map['daily_test_limit'] : int.tryParse(map['daily_test_limit']?.toString() ?? '3') ?? 3;
        chartLimit = map['chart_limit'] is int ? map['chart_limit'] : int.tryParse(map['chart_limit']?.toString() ?? '500') ?? 500;
        tableLimit = map['table_limit'] is int ? map['table_limit'] : int.tryParse(map['table_limit']?.toString() ?? '500') ?? 500;
        adminPin = map['admin_pin']?.toString() ?? '1234';
        paramedisPin = map['paramedis_pin']?.toString() ?? 'paramedis123';
        autoConnect = map['auto_connect'] == true;
        autoBackup = map['auto_backup'] == true;
        downloadPath = map['download_path']?.toString() ?? '/storage/emulated/0/Download';
      }
    } catch (e) {
      debugPrint('SettingsService.load failed: $e');
    }
  }

  Future<void> save() async {
    try {
      final f = await _file;
      final map = {
        'company_name': companyName,
        'app_name': appName,
        'baudrate': baudRate,
        'age_warning_threshold': ageWarningThreshold,
        'daily_test_limit': dailyTestLimit,
        'chart_limit': chartLimit,
        'table_limit': tableLimit,
        'admin_pin': adminPin,
        'paramedis_pin': paramedisPin,
        'auto_connect': autoConnect,
        'auto_backup': autoBackup,
        'download_path': downloadPath,
      };
      await f.writeAsString(jsonEncode(map), flush: true);
    } catch (e) {
      debugPrint('SettingsService.save failed: $e');
    }
  }
}
