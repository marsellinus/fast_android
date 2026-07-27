import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/settings_service.dart';
import '../widgets/glass_card.dart';
import '../database/db_helper.dart';

class SettingsScreen extends StatefulWidget {
  final String mode;
  const SettingsScreen({super.key, this.mode = 'SHE Officer'});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();

  late TextEditingController _companyController;
  late TextEditingController _appNameController;
  late TextEditingController _ageController;
  late TextEditingController _dailyLimitController;
  late TextEditingController _chartLimitController;
  late TextEditingController _tableLimitController;
  late TextEditingController _downloadPathController;
  late int _selectedBaudRate;
  late bool _autoConnect;
  late bool _autoBackup;

  String _dbPath = 'Loading...';
  String _excelPath = 'Loading...';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _companyController = TextEditingController(text: _settings.companyName);
    _appNameController = TextEditingController(text: _settings.appName);
    _ageController = TextEditingController(text: _settings.ageWarningThreshold.toString());
    _dailyLimitController = TextEditingController(text: _settings.dailyTestLimit.toString());
    _chartLimitController = TextEditingController(text: _settings.chartLimit.toString());
    _tableLimitController = TextEditingController(text: _settings.tableLimit.toString());
    _downloadPathController = TextEditingController(text: _settings.downloadPath);
    _selectedBaudRate = _settings.baudRate;
    _autoConnect = _settings.autoConnect;
    _autoBackup = _settings.autoBackup;
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    final docDir = await getApplicationDocumentsDirectory();
    setState(() {
      _dbPath = '${docDir.path}/ratig.db';
      _excelPath = '${docDir.path}/settings.json';
    });
  }

  @override
  void dispose() {
    _companyController.dispose();
    _appNameController.dispose();
    _ageController.dispose();
    _dailyLimitController.dispose();
    _chartLimitController.dispose();
    _tableLimitController.dispose();
    _downloadPathController.dispose();
    super.dispose();
  }

  Future<void> _saveAll() async {
    final company = _companyController.text.trim();
    if (company.isEmpty) {
      _showError('Nama perusahaan tidak boleh kosong!');
      return;
    }

    final appName = _appNameController.text.trim();
    if (appName.isEmpty) {
      _showError('Nama aplikasi tidak boleh kosong!');
      return;
    }

    final downloadPath = _downloadPathController.text.trim();
    if (downloadPath.isEmpty) {
      _showError('Folder hasil ekspor tidak boleh kosong!');
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age <= 0 || age > 120) {
      _showError('Batas usia tidak valid (1-120 tahun)!');
      return;
    }

    final dailyLimit = int.tryParse(_dailyLimitController.text.trim());
    if (dailyLimit == null || dailyLimit <= 0) {
      _showError('Batas tes harian tidak valid!');
      return;
    }

    final chartLimit = int.tryParse(_chartLimitController.text.trim());
    if (chartLimit == null || chartLimit <= 0) {
      _showError('Batas chart tidak valid!');
      return;
    }

    final tableLimit = int.tryParse(_tableLimitController.text.trim());
    if (tableLimit == null || tableLimit <= 0) {
      _showError('Batas tabel tidak valid!');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      _settings.companyName = company;
      _settings.appName = appName;
      _settings.ageWarningThreshold = age;
      _settings.dailyTestLimit = dailyLimit;
      _settings.chartLimit = chartLimit;
      _settings.tableLimit = tableLimit;
      _settings.baudRate = _selectedBaudRate;
      _settings.autoConnect = _autoConnect;
      _settings.autoBackup = _autoBackup;
      _settings.downloadPath = downloadPath;

      await _settings.save();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan berhasil disimpan!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Gagal menyimpan pengaturan: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickDownloadDirectory() async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        setState(() {
          _downloadPathController.text = selectedDirectory;
        });
      }
    } catch (e) {
      _showError('Gagal memilih folder: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _changeAdminPin() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Ubah PIN Hapus Data', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldController,
                  obscureText: obscureOld,
                  decoration: InputDecoration(
                    labelText: 'PIN Lama',
                    labelStyle: GoogleFonts.inter(color: Colors.white54),
                    suffixIcon: IconButton(
                      icon: Icon(obscureOld ? Icons.visibility : Icons.visibility_off, color: Colors.white30),
                      onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'PIN Baru',
                    labelStyle: GoogleFonts.inter(color: Colors.white54),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off, color: Colors.white30),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi PIN Baru',
                    labelStyle: GoogleFonts.inter(color: Colors.white54),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FE), foregroundColor: Colors.black),
              onPressed: () {
                final oldPin = oldController.text.trim();
                final newPin = newController.text.trim();
                final confirmPin = confirmController.text.trim();

                if (oldPin != _settings.adminPin && oldPin != 'ITPSHE#2026') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN Lama salah!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                if (newPin.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN Baru tidak boleh kosong!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                if (newPin != confirmPin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Konfirmasi PIN baru tidak sesuai!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }

                _settings.adminPin = newPin;
                _settings.save();
                Navigator.pop(ctx, true);
              },
              child: const Text('Ubah'),
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN Hapus Data berhasil diperbarui!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _changeParamedisPin() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Ubah PIN Mode Paramedis', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldController,
                  obscureText: obscureOld,
                  decoration: InputDecoration(
                    labelText: 'PIN Paramedis Lama',
                    labelStyle: GoogleFonts.inter(color: Colors.white54),
                    suffixIcon: IconButton(
                      icon: Icon(obscureOld ? Icons.visibility : Icons.visibility_off, color: Colors.white30),
                      onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'PIN Paramedis Baru',
                    labelStyle: GoogleFonts.inter(color: Colors.white54),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off, color: Colors.white30),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi PIN Paramedis Baru',
                    labelStyle: GoogleFonts.inter(color: Colors.white54),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FE), foregroundColor: Colors.black),
              onPressed: () {
                final oldPin = oldController.text;
                final newPin = newController.text;
                final confirmPin = confirmController.text;

                if (oldPin != _settings.paramedisPin && oldPin != 'ITPSHE#2026') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN Paramedis Lama salah!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                if (newPin.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN Baru tidak boleh kosong!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                if (newPin != confirmPin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Konfirmasi PIN baru tidak sesuai!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }

                _settings.paramedisPin = newPin;
                _settings.save();
                Navigator.pop(ctx, true);
              },
              child: const Text('Ubah'),
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN Paramedis berhasil diperbarui!'), backgroundColor: Colors.green),
      );
    }
  }

  Future<bool> _saveToPublicDownload(String filename, List<int> bytes) async {
    if (!Platform.isAndroid) return false;
    try {
      final pathStr = SettingsService().downloadPath;
      final dir = Directory(pathStr);
      if (await dir.exists()) {
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        return true;
      }
    } catch (e) {
      debugPrint("Gagal simpan langsung ke Download: $e");
    }
    return false;
  }

  Future<void> _backupDatabase() async {
    setState(() => _isProcessing = true);
    try {
      final dbPath = await DBHelper().getDatabaseFilePath();
      final file = File(dbPath);
      if (!await file.exists()) {
        throw 'File database tidak ditemukan!';
      }

      final dbBytes = await file.readAsBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'ratig_backup_$ts.db';
      final savedDirectly = await _saveToPublicDownload(filename, dbBytes);
      if (savedDirectly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database berhasil disimpan ke folder Download/$filename'), backgroundColor: Colors.green),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final backupPath = '${tempDir.path}/$filename';
      final backupFile = await file.copy(backupPath);

      final xFile = XFile(backupFile.path, mimeType: 'application/octet-stream');
      await Share.shareXFiles([xFile], subject: 'RATIG Database Backup');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil membagikan backup database!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor database: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreDatabase() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null) return;

      final fileBytes = result.files.single.bytes ?? await File(result.files.single.path!).readAsBytes();

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Pulihkan Database?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('Tindakan ini akan menimpa seluruh data (baru & lama) dengan data dari file backup yang Anda pilih. Lanjutkan?', style: GoogleFonts.inter(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.white30))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pulihkan'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isProcessing = true);

      await DBHelper().restoreDatabase(fileBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database berhasil dipulihkan!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengimpor database: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text('⚙ Pengaturan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0B0F19)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isProcessing
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F2FE)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Umum & Instansi'),
                      _buildGeneralCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Koneksi & Serial'),
                      _buildSerialCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Keamanan (PIN)'),
                      _buildSecurityCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Backup & Pulihkan Database'),
                      _buildBackupRestoreCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Informasi Berkas'),
                      _buildInfoCard(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F2FE),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: const Color(0xFF00F2FE).withValues(alpha: 0.4),
                          ),
                          onPressed: _saveAll,
                          icon: const Icon(Icons.save, size: 24),
                          label: Text('Simpan Pengaturan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF00F2FE)),
      ),
    );
  }

  Widget _buildGeneralCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      child: Column(
        children: [
          TextField(
            controller: _companyController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nama Perusahaan',
              labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.business, color: Colors.white30, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _appNameController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nama Aplikasi',
              labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.app_shortcut_rounded, color: Colors.white30, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Batas Usia Peringatan (Tahun)',
              labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.warning_amber_rounded, color: Colors.white30, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dailyLimitController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Batas Tes Harian per Pekerja (kali/hari)',
              labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.repeat_one_rounded, color: Colors.white30, size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chartLimitController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Max Baris Grafik',
                    labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.show_chart_rounded, color: Colors.white30, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.02),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _tableLimitController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Max Baris Tabel',
                    labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.table_rows_rounded, color: Colors.white30, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.02),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _downloadPathController,
            readOnly: true,
            onTap: _pickDownloadDirectory,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Folder Hasil Ekspor & Backup',
              labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(Icons.folder_open_rounded, color: Colors.white30, size: 20),
              suffixIcon: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.create_new_folder_rounded, color: Color(0xFF00F2FE)),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerialCard() {
    final baudRates = [9600, 19200, 38400, 57600, 115200];
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed, color: Colors.white70),
                  const SizedBox(width: 12),
                  Text('Baud Rate', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
                ],
              ),
              DropdownButton<int>(
                value: _selectedBaudRate,
                dropdownColor: const Color(0xFF1E1B4B),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                underline: const SizedBox(),
                items: baudRates
                    .map((rate) => DropdownMenuItem<int>(
                          value: rate,
                          child: Text(rate.toString()),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedBaudRate = val);
                  }
                },
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          SwitchListTile(
            title: Text('Auto-connect Serial', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
            subtitle: Text('Hubungkan otomatis ke hardware saat terdeteksi', style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
            value: _autoConnect,
            activeThumbColor: const Color(0xFF00F2FE),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _autoConnect = val),
          ),
          const Divider(color: Colors.white10, height: 24),
          SwitchListTile(
            title: Text('Auto-backup Harian', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
            subtitle: Text('Ekspor otomatis database berkala', style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
            value: _autoBackup,
            activeThumbColor: const Color(0xFF00F2FE),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _autoBackup = val),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAdminPin() async {
    final masterCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Reset PIN Hapus Data', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan Kunci Otorisasi Master (Master Key) untuk mereset PIN Hapus Data ke default (1234):', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: masterCtrl,
              obscureText: true,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Kunci Otorisasi Master', hintStyle: TextStyle(color: Colors.white30)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FE), foregroundColor: Colors.black),
            onPressed: () {
              if (masterCtrl.text.trim() == 'ITPSHE#2026') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunci Otorisasi Master salah!'), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _settings.adminPin = '1234';
      await _settings.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Hapus Data berhasil di-reset ke default (1234)!'), backgroundColor: Colors.green));
    }
  }

  Future<void> _resetParamedisPin() async {
    final masterCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Reset PIN Mode Paramedis', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan Kunci Otorisasi Master (Master Key) untuk mereset PIN Paramedis ke default (paramedis123):', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: masterCtrl,
              obscureText: true,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Kunci Otorisasi Master', hintStyle: TextStyle(color: Colors.white30)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FE), foregroundColor: Colors.black),
            onPressed: () {
              if (masterCtrl.text.trim() == 'ITPSHE#2026') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunci Otorisasi Master salah!'), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _settings.paramedisPin = 'paramedis123';
      await _settings.save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Mode Paramedis berhasil di-reset ke default (paramedis123)!'), backgroundColor: Colors.green));
    }
  }

  Widget _buildSecurityCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PIN Hapus Data', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Batas keamanan hapus riwayat tes', style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _resetAdminPin,
                    child: Text('Lupa PIN?', style: GoogleFonts.inter(color: const Color(0xFF00F2FE), fontSize: 12, decoration: TextDecoration.underline)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF00F2FE),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF00F2FE), width: 1),
                    ),
                    onPressed: _changeAdminPin,
                    child: const Text('Ubah PIN'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PIN Mode Paramedis', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Akses login khusus paramedis', style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _resetParamedisPin,
                    child: Text('Lupa PIN?', style: GoogleFonts.inter(color: const Color(0xFF00F2FE), fontSize: 12, decoration: TextDecoration.underline)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF00F2FE),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF00F2FE), width: 1),
                    ),
                    onPressed: _changeParamedisPin,
                    child: const Text('Ubah PIN'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackupRestoreCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ekspor Database (Backup)', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Mencadangkan seluruh data hasil tes & master karyawan', style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF00F2FE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFF00F2FE), width: 1),
                ),
                onPressed: _backupDatabase,
                icon: const Icon(Icons.backup_rounded, size: 16),
                label: const Text('Backup'),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Impor Database (Restore)', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Memulihkan data lama/baru dari file backup .db', style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.withValues(alpha: 0.1),
                  foregroundColor: Colors.orangeAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Colors.orangeAccent, width: 1),
                ),
                onPressed: _restoreDatabase,
                icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
                label: const Text('Restore'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_settings.appName, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF00F2FE))),
          const SizedBox(height: 4),
          Text('Dikembangkan Oleh: Marsellinus, Khilqi, dan Idris', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purpleAccent)),
          const Divider(color: Colors.white10, height: 24),
          _buildInfoRow('Path Database', _dbPath),
          const Divider(color: Colors.white10, height: 24),
          _buildInfoRow('Path Config/Settings', _excelPath),
          const Divider(color: Colors.white10, height: 24),
          _buildInfoRow('Versi Aplikasi', 'RATIG Mobile v2.0 (Flutter)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white30)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.robotoMono(fontSize: 13, color: Colors.white70),
          softWrap: true,
        ),
      ],
    );
  }
}
