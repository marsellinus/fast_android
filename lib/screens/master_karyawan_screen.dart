import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/db_helper.dart';
import '../widgets/glass_card.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/settings_service.dart';

class MasterKaryawanScreen extends StatefulWidget {
  final String mode;
  const MasterKaryawanScreen({super.key, required this.mode});

  @override
  State<MasterKaryawanScreen> createState() => _MasterKaryawanScreenState();
}

class _MasterKaryawanScreenState extends State<MasterKaryawanScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  bool _isKontraktor = false;
  bool _isProcessing = false; // FIX: cegah double-tap saat simpan/hapus berjalan
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await DBHelper().getAllKaryawan(isKontraktor: _isKontraktor);
      // FIX: cek `mounted` setelah await — mencegah setState() dipanggil
      // pada widget yang sudah di-dispose (misal user menekan back sesaat
      // sebelum query database selesai).
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final messenger = ScaffoldMessenger.of(context);
      final tables = await DBHelper().getTables();
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $e\nTables: $tables'), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 10)),
      );
    }
  }

  Future<void> _importBatch() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null) return;

      setState(() {
        _isLoading = true;
        _isProcessing = true;
      });

      final bytes = result.files.single.bytes ?? await File(result.files.single.path!).readAsBytes();
      final filename = result.files.single.name.toLowerCase();

      int count = 0;

      if (filename.endsWith('.csv')) {
        // Parse CSV
        final content = String.fromCharCodes(bytes);
        final lines = content.split('\n');
        if (lines.isEmpty) throw 'File CSV kosong';

        // Get headers
        final headers = lines.first.split(',').map((h) => h.trim().toLowerCase().replaceAll('"', '')).toList();
        
        // Find indices
        int idxNama = headers.indexWhere((h) => h == 'nama');
        int idxNik = headers.indexWhere((h) => h == 'nik');
        int idxUsia = headers.indexWhere((h) => h == 'usia');
        int idxJk = headers.indexWhere((h) => h == 'jenis_kelamin' || h == 'gender' || h == 'jenis kelamin');
        int idxJabatan = headers.indexWhere((h) => h == 'jabatan' || h == 'bagian');
        int idxInfo = headers.indexWhere((h) => h == 'info_pekerjaan' || h == 'divisi' || h == 'departemen' || h == 'contractor' || h == 'perusahaan/bagian');
        int idxTglLahir = headers.indexWhere((h) => h.contains('tanggal_lahir') || h.contains('tanggal lahir'));

        if (idxNama == -1 || idxNik == -1) {
          throw 'Header file minimal harus memiliki kolom "nama" dan "nik"';
        }

        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          final values = line.split(',').map((v) => v.trim().replaceAll('"', '')).toList();
          if (values.length <= idxNama || values.length <= idxNik) continue;

          final nama = values[idxNama];
          final nik = values[idxNik].toUpperCase();
          if (nama.isEmpty || nik.isEmpty) continue;

          final String usia = idxUsia != -1 && values.length > idxUsia ? values[idxUsia] : '';
          final String jk = idxJk != -1 && values.length > idxJk ? values[idxJk] : 'Laki-laki';
          final String jabatan = idxJabatan != -1 && values.length > idxJabatan ? values[idxJabatan] : '';
          final String info = idxInfo != -1 && values.length > idxInfo ? values[idxInfo] : '';
          final String tglLahir = idxTglLahir != -1 && values.length > idxTglLahir ? values[idxTglLahir] : '';

          final row = {
            'nama': nama,
            'nik': nik,
            'usia': usia,
            'jenis_kelamin': jk,
            'jabatan': jabatan,
            'info_pekerjaan': info,
            'tanggal_lahir': tglLahir,
          };

          await DBHelper().upsertKaryawan(row, isKontraktor: _isKontraktor);
          count++;
        }
      } else {
        // Parse XLSX
        final excel = Excel.decodeBytes(bytes);
        if (excel.tables.isEmpty) throw 'File Excel kosong';

        final sheetName = excel.tables.keys.first;
        final sheet = excel.tables[sheetName]!;

        if (sheet.maxRows < 2) throw 'File Excel tidak memiliki data';

        // Get headers from first row
        final firstRow = sheet.rows.first;
        final headers = firstRow.map((cell) => cell?.value?.toString().trim().toLowerCase().replaceAll(' ', '_') ?? '').toList();

        int idxNama = headers.indexWhere((h) => h == 'nama');
        int idxNik = headers.indexWhere((h) => h == 'nik');
        int idxUsia = headers.indexWhere((h) => h == 'usia');
        int idxJk = headers.indexWhere((h) => h == 'jenis_kelamin' || h == 'gender' || h == 'jenis kelamin');
        int idxJabatan = headers.indexWhere((h) => h == 'jabatan' || h == 'bagian');
        int idxInfo = headers.indexWhere((h) => h == 'info_pekerjaan' || h == 'divisi' || h == 'departemen' || h == 'contractor' || h == 'perusahaan/bagian');
        int idxTglLahir = headers.indexWhere((h) => h.contains('tanggal_lahir') || h.contains('tanggal lahir'));

        if (idxNama == -1 || idxNik == -1) {
          throw 'Header Excel minimal harus memiliki kolom "Nama" dan "NIK"';
        }

        for (int i = 1; i < sheet.maxRows; i++) {
          final rowData = sheet.rows[i];
          if (rowData.isEmpty) continue;

          final String nama = idxNama != -1 && rowData.length > idxNama ? rowData[idxNama]?.value?.toString().trim() ?? '' : '';
          final String nik = idxNik != -1 && rowData.length > idxNik ? rowData[idxNik]?.value?.toString().trim().toUpperCase() ?? '' : '';

          if (nama.isEmpty || nik.isEmpty) continue;

          final String usia = idxUsia != -1 && rowData.length > idxUsia ? rowData[idxUsia]?.value?.toString().trim() ?? '' : '';
          final String jk = idxJk != -1 && rowData.length > idxJk ? rowData[idxJk]?.value?.toString().trim() ?? 'Laki-laki' : 'Laki-laki';
          final String jabatan = idxJabatan != -1 && rowData.length > idxJabatan ? rowData[idxJabatan]?.value?.toString().trim() ?? '' : '';
          final String info = idxInfo != -1 && rowData.length > idxInfo ? rowData[idxInfo]?.value?.toString().trim() ?? '' : '';
          final String tglLahir = idxTglLahir != -1 && rowData.length > idxTglLahir ? rowData[idxTglLahir]?.value?.toString().trim() ?? '' : '';

          final row = {
            'nama': nama,
            'nik': nik,
            'usia': usia,
            'jenis_kelamin': jk,
            'jabatan': jabatan,
            'info_pekerjaan': info,
            'tanggal_lahir': tglLahir,
          };

          await DBHelper().upsertKaryawan(row, isKontraktor: _isKontraktor);
          count++;
        }
      }

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil mengimpor $count data ${_isKontraktor ? 'Kontraktor' : 'Karyawan'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengimpor file: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });
      }
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

  Future<void> _downloadTemplate() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Add template headers
      sheetObject.appendRow([
        TextCellValue('NIK'),
        TextCellValue('Nama'),
        TextCellValue('Usia'),
        TextCellValue('Jenis Kelamin'),
        TextCellValue('Jabatan'),
        TextCellValue('Info Pekerjaan'),
      ]);

      // Add dummy data rows
      sheetObject.appendRow([
        TextCellValue('12345678'),
        TextCellValue('Budi Santoso'),
        TextCellValue('30'),
        TextCellValue('Laki-laki'),
        TextCellValue('Operator'),
        TextCellValue('Divisi Pertambangan'),
      ]);
      sheetObject.appendRow([
        TextCellValue('87654321'),
        TextCellValue('Siti Aminah'),
        TextCellValue('28'),
        TextCellValue('Perempuan'),
        TextCellValue('Admin'),
        TextCellValue('Divisi HRD'),
      ]);

      final fileBytes = excel.save();
      if (fileBytes == null) throw 'Gagal membuat file template Excel';

      final filename = 'Template_Master_${_isKontraktor ? "Kontraktor" : "Karyawan"}.xlsx';
      final savedDirectly = await _saveToPublicDownload(filename, fileBytes);
      if (savedDirectly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berkas template berhasil disimpan ke folder Download/$filename'), backgroundColor: Colors.green),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(fileBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: filename)],
        subject: 'Template Master ${_isKontraktor ? "Kontraktor" : "Karyawan"} RATIG',
        text: 'Berikut adalah berkas template Excel untuk impor data master ${_isKontraktor ? "kontraktor" : "karyawan"} RATIG.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat template: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _exportMaster() async {
    try {
      if (_data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data untuk diexport'), backgroundColor: Colors.orangeAccent),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _isProcessing = true;
      });

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Add headers
      sheetObject.appendRow([
        TextCellValue('NIK'),
        TextCellValue('Nama'),
        TextCellValue('Usia'),
        TextCellValue('Jenis Kelamin'),
        TextCellValue('Jabatan'),
        TextCellValue('Info Pekerjaan'),
      ]);

      // Add actual data
      for (final row in _data) {
        sheetObject.appendRow([
          TextCellValue(row['nik']?.toString() ?? ''),
          TextCellValue(row['nama']?.toString() ?? ''),
          TextCellValue(row['usia']?.toString() ?? ''),
          TextCellValue(row['jenis_kelamin']?.toString() ?? ''),
          TextCellValue(row['jabatan']?.toString() ?? ''),
          TextCellValue(row['info_pekerjaan']?.toString() ?? ''),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) throw 'Gagal membuat file Excel Export';

      final filename = 'Backup_Master_${_isKontraktor ? "Kontraktor" : "Karyawan"}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final savedDirectly = await _saveToPublicDownload(filename, fileBytes);
      if (savedDirectly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berkas backup berhasil disimpan ke folder Download/$filename'), backgroundColor: Colors.green),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(fileBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: filename)],
        subject: 'Backup Master ${_isKontraktor ? "Kontraktor" : "Karyawan"} RATIG',
        text: 'Berikut adalah berkas backup Excel untuk data master ${_isKontraktor ? "kontraktor" : "karyawan"} RATIG.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor data: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _data;
    final q = _searchQuery.toLowerCase();
    return _data.where((r) =>
        (r['nama'] ?? '').toString().toLowerCase().contains(q) ||
        (r['nik'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  Future<void> _showAddDialog({Map<String, dynamic>? existing}) async {
    // FIX: sebelumnya `existing?['usia']` / `existing?['tanggal_lahir']`
    // langsung dipakai sebagai `text:` TextEditingController. Kolom SQLite
    // bertipe dinamis — kalau nilainya tersimpan sebagai int (bukan String),
    // ini akan crash saat dialog Edit dibuka. Sekarang selalu di-`toString()`
    // dulu dengan aman lewat helper kecil di bawah.
    String asText(dynamic v) => v == null ? '' : v.toString();

    final nikCtrl     = TextEditingController(text: asText(existing?['nik']));
    final namaCtrl    = TextEditingController(text: asText(existing?['nama']));
    final usiaCtrl    = TextEditingController(text: asText(existing?['usia']));
    final jabatanCtrl = TextEditingController(text: asText(existing?['jabatan']));
    final infoKerjaCtrl = TextEditingController(text: asText(existing?['info_pekerjaan']));
    String jk = (existing?['jenis_kelamin'] as String?) ?? 'Laki-laki';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setInner) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            existing == null ? 'Tambah ${_isKontraktor ? 'Kontraktor' : 'Karyawan'}' : 'Edit ${_isKontraktor ? 'Kontraktor' : 'Karyawan'}',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nikCtrl, 'NIK'),
                _dialogField(namaCtrl, 'Nama Lengkap'),
                Row(
                  children: [
                    Expanded(child: _dialogField(usiaCtrl, 'Usia', isNum: true)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: jk,
                        items: ['Laki-laki', 'Perempuan'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: GoogleFonts.inter(color: Colors.white)))).toList(),
                        onChanged: (v) => setInner(() => jk = v ?? jk),
                        decoration: _dialogDeco('Gender'),
                        dropdownColor: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                _dialogField(jabatanCtrl, 'Jabatan'),
                _dialogField(infoKerjaCtrl, 'Info Pekerjaan / Divisi'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: GoogleFonts.inter(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F2FE),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final nik = nikCtrl.text.trim().toUpperCase();
                final nama = namaCtrl.text.trim();

                // FIX: sebelumnya kalau kosong, tombol Simpan cuma `return`
                // tanpa penjelasan apa pun — terasa seperti tombol tidak
                // berfungsi. Sekarang user diberi tahu field mana yang wajib.
                if (nik.isEmpty || nama.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('NIK dan Nama Lengkap wajib diisi!'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                final rowData = {
                  'nik':            nik,
                  'nama':           nama,
                  'usia':           usiaCtrl.text.trim(),
                  'jenis_kelamin':  jk,
                  'jabatan':        jabatanCtrl.text.trim(),
                  'info_pekerjaan': infoKerjaCtrl.text.trim(),
                };

                if (existing != null) rowData['id'] = existing['id'];

                // FIX: bungkus operasi DB dengan try/catch supaya kalau gagal
                // (misal NIK duplikat/constraint unik), user dapat pesan
                // error yang jelas alih-alih exception mentah yang terasa
                // seperti aplikasi macet.
                try {
                  await DBHelper().upsertKaryawan(rowData, isKontraktor: _isKontraktor);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Gagal menyimpan data: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: Text('Simpan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Hapus Data?', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Data master ini akan dihapus secara permanen.', style: GoogleFonts.inter(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    try {
      await DBHelper().deleteKaryawan(id, isKontraktor: _isKontraktor);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus data: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          )
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Master Data', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF00F2FE)),
                      tooltip: 'Tambah Data',
                      onPressed: _isProcessing ? null : () => _showAddDialog(),
                    ),
                     IconButton(
                      icon: const Icon(Icons.upload_file_rounded, color: Color(0xFFF5AF19)),
                      tooltip: 'Import Excel/CSV',
                      onPressed: _isProcessing || _isLoading ? null : _importBatch,
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Color(0xFF00F2FE)),
                      tooltip: 'Unduh Template Excel',
                      onPressed: _isProcessing || _isLoading ? null : _downloadTemplate,
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Color(0xFF10B981)),
                      tooltip: 'Ekspor Data Master',
                      onPressed: _isProcessing || _isLoading ? null : _exportMaster,
                    ),
                  ],
                ),
              ),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () { if (_isKontraktor && !_isLoading) { setState(() => _isKontraktor = false); _load(); } },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isKontraktor ? const Color(0xFF00F2FE).withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text('KARYAWAN', style: GoogleFonts.inter(color: !_isKontraktor ? const Color(0xFF00F2FE) : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () { if (!_isKontraktor && !_isLoading) { setState(() => _isKontraktor = true); _load(); } },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isKontraktor ? const Color(0xFFF5AF19).withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text('KONTRAKTOR', style: GoogleFonts.inter(color: _isKontraktor ? const Color(0xFFF5AF19) : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari Nama / NIK...',
                    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F2FE)))
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.folder_open_rounded, color: Colors.white24, size: 64),
                                const SizedBox(height: 16),
                                Text('Belum ada ${_isKontraktor ? 'kontraktor' : 'karyawan'} terdaftar', style: GoogleFonts.inter(color: Colors.white38)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final item = _filtered[i];
                              final namaStr = (item['nama'] ?? '-').toString();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GlassCard(
                                  padding: EdgeInsets.zero,
                                  opacity: 0.05,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                  child: ListTile(
                                    onTap: () => Navigator.pop(context, item),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: (_isKontraktor ? const Color(0xFFF5AF19) : const Color(0xFF00F2FE)).withValues(alpha: 0.15),
                                      child: Text(
                                        namaStr.isNotEmpty ? namaStr[0].toUpperCase() : '?',
                                        style: TextStyle(color: _isKontraktor ? const Color(0xFFF5AF19) : const Color(0xFF00F2FE), fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ),
                                    title: Text(namaStr, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('NIK: ${item['nik']}  •  ${item['jabatan'] ?? '-'}', style: GoogleFonts.inter(color: Colors.blueGrey[300], fontSize: 12)),
                                          const SizedBox(height: 2),
                                          Text('${item['jenis_kelamin'] ?? '-'}  •  ${item['info_pekerjaan'] ?? '-'}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF00F2FE), size: 24),
                                          tooltip: 'Pilih untuk Tes',
                                          onPressed: () => Navigator.pop(context, item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                                          onPressed: _isProcessing ? null : () => _showAddDialog(existing: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: _isProcessing ? null : () => _delete(item['id'] as int),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, {bool isNum = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        decoration: _dialogDeco(label, hint: hint),
      ),
    );
  }

  InputDecoration _dialogDeco(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
    labelStyle: GoogleFonts.inter(color: Colors.blueGrey[400], fontSize: 12),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.05),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
  );
}
