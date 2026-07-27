import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import '../database/db_helper.dart';
import '../widgets/glass_card.dart';
import '../services/settings_service.dart';
import 'medis_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String mode;
  const HistoryScreen({super.key, required this.mode});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _data = [];
  Set<int> _selectedIds = {};
  bool _isLoading = true;
  bool _isExporting = false;
  Set<String> _warningNiks = {};

  // Filter state
  final _searchCtrl = TextEditingController();
  final _dariCtrl = TextEditingController();
  final _sampaiCtrl = TextEditingController();
  final _jabatanCtrl = TextEditingController();
  String _fatigueFilter = 'Semua';
  String _keputusanFilter = 'Semua';
  bool _filterActive = false;

  static const _fatigueLevels = ['Semua', 'Normal', 'Fatigue Ringan', 'Fatigue Sedang', 'Fatigue Berat'];
  static const _keputusanOptions = [
    'Semua', 'Diizinkan bekerja', 'Diizinkan bekerja, dengan catatan',
    'Tidak diizinkan bekerja', 'Rujuk ke Faskes'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _dariCtrl.dispose();
    _sampaiCtrl.dispose();
    _jabatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _selectedIds.clear(); });
    final data = await DBHelper().getFilteredResults(
      tanggalDari: _dariCtrl.text.trim(),
      tanggalSampai: _sampaiCtrl.text.trim(),
      jabatan: _jabatanCtrl.text.trim(),
      fatigueLevel: _fatigueFilter,
      keputusan: _keputusanFilter,
      searchNamaNik: _searchCtrl.text.trim(),
    );
    final warningNiks = <String>{};
    final niks = data.map((e) => e['nik'].toString()).toSet();
    for (final nik in niks) {
      if (nik.isNotEmpty && await DBHelper().checkConsecutiveBerat(nik)) {
        warningNiks.add(nik);
      }
    }
    if (!mounted) return;
    setState(() {
      _data = data;
      _warningNiks = warningNiks;
      _isLoading = false;
    });
  }

  void _resetFilter() {
    _dariCtrl.clear();
    _sampaiCtrl.clear();
    _jabatanCtrl.clear();
    _searchCtrl.clear();
    setState(() {
      _fatigueFilter = 'Semua';
      _keputusanFilter = 'Semua';
      _filterActive = false;
    });
    _load();
  }

  void _applyFilter() {
    setState(() { _filterActive = true; });
    _load();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF00F2FE)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.text = picked.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final pinCtrl = TextEditingController();
    bool obscure = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('🔐 Konfirmasi Hapus', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Hapus ${_selectedIds.length} data terpilih?', style: GoogleFonts.inter(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: obscure,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'PIN Admin',
                labelStyle: GoogleFonts.inter(color: Colors.white54),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.white30),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                if (pinCtrl.text.trim() != SettingsService().adminPin && pinCtrl.text.trim() != 'ITPSHE#2026') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN Admin salah!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await DBHelper().deleteResults(_selectedIds.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedIds.length} data berhasil dihapus'), backgroundColor: Colors.green),
      );
      _load();
    }
  }

  Future<void> _deleteAll() async {
    if (_data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk dihapus!')),
      );
      return;
    }
    final pinCtrl = TextEditingController();
    bool obscure = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B4B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('🗑 Hapus Semua Data', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Aksi ini akan menghapus SEMUA ${_data.length} data riwayat yang tampil saat ini dan tidak dapat dibatalkan!',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: obscure,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'PIN Admin',
                labelStyle: GoogleFonts.inter(color: Colors.white54),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.white30),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                if (pinCtrl.text.trim() != SettingsService().adminPin && pinCtrl.text.trim() != 'ITPSHE#2026') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN Admin salah!'), backgroundColor: Colors.redAccent),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Hapus Semua'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final ids = _data.map((e) => e['id'] as int).toList();
      await DBHelper().deleteResults(ids);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ids.length} data berhasil dihapus'), backgroundColor: Colors.green),
      );
      _load();
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

  Future<void> _exportToExcel() async {
    if (_isExporting) return;
    if (_data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk diekspor!')));
      return;
    }
    setState(() => _isExporting = true);
    try {
      var excel = Excel.createExcel();
      Sheet ws = excel['Riwayat RATIG'];
      excel.setDefaultSheet('Riwayat RATIG');
      final headers = [
        'No', 'Tanggal', 'Nama', 'NIK', 'Usia', 'Jenis Kelamin', 'Bagian',
        'Kontraktor', 'Plan', 'TD Sistol', 'TD Diastol', 'Nadi', 'Kadar Alkohol',
        'T1', 'T2', 'T3', 'T4', 'T5', 'T6',
        'Total HFT', 'Rata-rata HFT', 'Kesimpulan (Fatigue)',
        'Kesimpulan (Sistol)', 'Kesimpulan (Diastol)', 'Kesimpulan (Nadi)',
        'Keputusan', 'Rekomendasi', 'Keterangan', 'Kesimpulan (Alkohol)'
      ];

      ws.appendRow(headers.map((e) => TextCellValue(e)).toList());

      // Header Styling (#2C3E50, bold white text, centered)
      final headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString("#2C3E50"),
        fontColorHex: ExcelColor.fromHexString("#FFFFFF"),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
      for (int col = 0; col < headers.length; col++) {
        var cell = ws.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.cellStyle = headerStyle;
      }

      final ageThreshold = SettingsService().ageWarningThreshold;

      // Color maps identik RATIG.py
      final Map<String, List<String>> colorMap = {
        "Normal":            ["#FFFFFF", "#000000"], // Putih
        "Fatigue Ringan":    ["#2ECC71", "#000000"], // Hijau
        "Fatigue Sedang":    ["#F1C40F", "#000000"], // Kuning
        "Fatigue Berat":     ["#E74C3C", "#FFFFFF"], // Merah

        "Hipotensi":         ["#D9E1F2", "#1F4E78"], // Soft Blue
        "Bradikardia":       ["#D9E1F2", "#1F4E78"],
        "Hypertensi Ringan": ["#2ECC71", "#000000"],
        "Takikardia Ringan": ["#2ECC71", "#000000"],
        "Hypertensi Sedang": ["#F1C40F", "#000000"],
        "Takikardia Sedang": ["#F1C40F", "#000000"],
        "Hypertensi Berat":  ["#E74C3C", "#FFFFFF"],
        "Takikardia Berat":  ["#E74C3C", "#FFFFFF"],
        "Tidak Lolos":       ["#E74C3C", "#FFFFFF"],
      };

      for (int i = 0; i < _data.length; i++) {
        final r = _data[i];
        final t1 = (r['t1'] as num?)?.toDouble() ?? 0;
        final t2 = (r['t2'] as num?)?.toDouble() ?? 0;
        final t3 = (r['t3'] as num?)?.toDouble() ?? 0;
        final t4 = (r['t4'] as num?)?.toDouble() ?? 0;
        final t5 = (r['t5'] as num?)?.toDouble() ?? 0;
        final t6 = (r['t6'] as num?)?.toDouble() ?? 0;
        final avg = (r['avg_reaction'] as num?)?.toDouble() ?? 0;

        ws.appendRow([
          IntCellValue(i + 1),
          TextCellValue(r['tanggal'] ?? ''),
          TextCellValue(r['nama'] ?? ''),
          TextCellValue(r['nik'] ?? ''),
          TextCellValue(r['usia']?.toString() ?? ''),
          TextCellValue(r['jenis_kelamin'] ?? ''),
          TextCellValue(r['jabatan'] ?? ''),
          TextCellValue(r['contractor'] ?? ''),
          TextCellValue(r['plan'] ?? ''),
          TextCellValue(r['td_sistol']?.toString() ?? ''),
          TextCellValue(r['td_diastol']?.toString() ?? ''),
          TextCellValue(r['nadi']?.toString() ?? ''),
          TextCellValue(r['alcohol_test']?.toString() ?? ''),
          DoubleCellValue(t1), DoubleCellValue(t2), DoubleCellValue(t3),
          DoubleCellValue(t4), DoubleCellValue(t5), DoubleCellValue(t6),
          DoubleCellValue(t1 + t2 + t3 + t4 + t5 + t6),
          DoubleCellValue(avg),
          TextCellValue(r['fatigue_level'] ?? ''),
          TextCellValue(r['kesimpulan_sistol'] ?? ''),
          TextCellValue(r['kesimpulan_diastol'] ?? ''),
          TextCellValue(r['kesimpulan_nadi'] ?? ''),
          TextCellValue(r['keputusan'] ?? ''),
          TextCellValue(r['rekomendasi'] ?? ''),
          TextCellValue(r['keterangan'] ?? ''),
          TextCellValue(r['kesimpulan_alkohol'] ?? ''),
        ]);

        final rowIndex = i + 1;

        // Usia warning (col 4)
        final usia = int.tryParse(r['usia']?.toString() ?? '') ?? 0;
        if (usia >= ageThreshold) {
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString("#FADBD8"),
            fontColorHex: ExcelColor.fromHexString("#922B21"),
            bold: true,
          );
        }

        // TD Sistol & Kesimpulan Sistol (col 9 & 22)
        final kesSistol = r['kesimpulan_sistol']?.toString() ?? '';
        if (colorMap.containsKey(kesSistol)) {
          final colors = colorMap[kesSistol]!;
          final style = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(colors[0]),
            fontColorHex: ExcelColor.fromHexString(colors[1]),
            bold: colors[1] == "#FFFFFF",
          );
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).cellStyle = style;
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 22, rowIndex: rowIndex)).cellStyle = style;
        }

        // TD Diastol & Kesimpulan Diastol (col 10 & 23)
        final kesDiastol = r['kesimpulan_diastol']?.toString() ?? '';
        if (colorMap.containsKey(kesDiastol)) {
          final colors = colorMap[kesDiastol]!;
          final style = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(colors[0]),
            fontColorHex: ExcelColor.fromHexString(colors[1]),
            bold: colors[1] == "#FFFFFF",
          );
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).cellStyle = style;
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 23, rowIndex: rowIndex)).cellStyle = style;
        }

        // Nadi & Kesimpulan Nadi (col 11 & 24)
        final kesNadi = r['kesimpulan_nadi']?.toString() ?? '';
        if (colorMap.containsKey(kesNadi)) {
          final colors = colorMap[kesNadi]!;
          final style = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(colors[0]),
            fontColorHex: ExcelColor.fromHexString(colors[1]),
            bold: colors[1] == "#FFFFFF",
          );
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).cellStyle = style;
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 24, rowIndex: rowIndex)).cellStyle = style;
        }

        // Rata-rata HFT & Fatigue Level (col 20 & 21)
        final fatigue = r['fatigue_level']?.toString() ?? '';
        if (colorMap.containsKey(fatigue)) {
          final colors = colorMap[fatigue]!;
          final style = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(colors[0]),
            fontColorHex: ExcelColor.fromHexString(colors[1]),
            bold: colors[1] == "#FFFFFF",
          );
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 20, rowIndex: rowIndex)).cellStyle = style;
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 21, rowIndex: rowIndex)).cellStyle = style;
        }

        // Alkohol & Kesimpulan Alkohol (col 12 & 28)
        final kesAlkohol = r['kesimpulan_alkohol']?.toString() ?? '';
        if (colorMap.containsKey(kesAlkohol)) {
          final colors = colorMap[kesAlkohol]!;
          final style = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString(colors[0]),
            fontColorHex: ExcelColor.fromHexString(colors[1]),
            bold: colors[1] == "#FFFFFF",
          );
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).cellStyle = style;
          ws.cell(CellIndex.indexByColumnRow(columnIndex: 28, rowIndex: rowIndex)).cellStyle = style;
        }
      }
      final bytes = excel.save();
      if (bytes == null) throw Exception('Gagal encode Excel');

      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'Export_RATIG_$ts.xlsx';
      final savedDirectly = await _saveToPublicDownload(filename, bytes);
      if (savedDirectly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berkas berhasil disimpan ke folder Download/$filename'), backgroundColor: Colors.green),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$filename';
      await File(path).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: filename)],
        subject: 'Export Riwayat RATIG (${_data.length} data)',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ekspor: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToCSV() async {
    if (_isExporting) return;
    if (_data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk diekspor!')));
      return;
    }
    setState(() => _isExporting = true);
    try {
      final headers = [
        'No', 'Tanggal', 'Nama', 'NIK', 'Usia', 'Jenis Kelamin', 'Bagian',
        'Kontraktor', 'Plan', 'TD Sistol', 'TD Diastol', 'Nadi', 'Kadar Alkohol',
        'T1', 'T2', 'T3', 'T4', 'T5', 'T6',
        'Total HFT', 'Rata-rata HFT', 'Kesimpulan (Fatigue)',
        'Kesimpulan (Sistol)', 'Kesimpulan (Diastol)', 'Kesimpulan (Nadi)',
        'Keputusan', 'Rekomendasi', 'Keterangan', 'Kesimpulan (Alkohol)'
      ];

      StringBuffer sb = StringBuffer();
      String escape(dynamic value) {
        if (value == null) return '';
        String str = value.toString().replaceAll('"', '""');
        if (str.contains(',') || str.contains('\n') || str.contains('"')) {
          return '"$str"';
        }
        return str;
      }

      sb.writeln(headers.map(escape).join(','));

      for (int i = 0; i < _data.length; i++) {
        final r = _data[i];
        final t1 = (r['t1'] as num?)?.toDouble() ?? 0;
        final t2 = (r['t2'] as num?)?.toDouble() ?? 0;
        final t3 = (r['t3'] as num?)?.toDouble() ?? 0;
        final t4 = (r['t4'] as num?)?.toDouble() ?? 0;
        final t5 = (r['t5'] as num?)?.toDouble() ?? 0;
        final t6 = (r['t6'] as num?)?.toDouble() ?? 0;

        final row = [
          (i + 1).toString(),
          (r['tanggal'] ?? '').toString(),
          (r['nama'] ?? '').toString(),
          (r['nik'] ?? '').toString(),
          (r['usia']?.toString() ?? ''),
          (r['jenis_kelamin'] ?? '').toString(),
          (r['jabatan'] ?? '').toString(),
          (r['contractor'] ?? '').toString(),
          (r['plan'] ?? '').toString(),
          (r['td_sistol']?.toString() ?? ''),
          (r['td_diastol']?.toString() ?? ''),
          (r['nadi']?.toString() ?? ''),
          (r['alcohol_test']?.toString() ?? ''),
          t1.toString(), t2.toString(), t3.toString(),
          t4.toString(), t5.toString(), t6.toString(),
          (t1 + t2 + t3 + t4 + t5 + t6).toString(),
          ((r['avg_reaction'] as num?)?.toDouble() ?? 0).toString(),
          (r['fatigue_level'] ?? '').toString(),
          (r['kesimpulan_sistol'] ?? '').toString(),
          (r['kesimpulan_diastol'] ?? '').toString(),
          (r['kesimpulan_nadi'] ?? '').toString(),
          (r['keputusan'] ?? '').toString(),
          (r['rekomendasi'] ?? '').toString(),
          (r['keterangan'] ?? '').toString(),
          (r['kesimpulan_alkohol'] ?? '').toString(),
        ];
        sb.writeln(row.map(escape).join(','));
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'Export_RATIG_$ts.csv';
      final fileBytes = utf8.encode(sb.toString());
      final savedDirectly = await _saveToPublicDownload(filename, fileBytes);
      if (savedDirectly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berkas berhasil disimpan ke folder Download/$filename'), backgroundColor: Colors.green),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$filename';
      await File(path).writeAsBytes(fileBytes, flush: true);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv', name: filename)],
        subject: 'Export Riwayat RATIG CSV (${_data.length} data)',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ekspor CSV: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportToPDF() async {
    if (_isExporting) return;
    if (_data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk diekspor!')));
      return;
    }
    setState(() => _isExporting = true);
    try {
      final doc = pw.Document();

      final headers = [
        'No', 'Tanggal', 'Nama', 'NIK', 'Usia', 'Bagian', 'T1-T6 (ms)', 'Total (ms)', 'Rata-rata', 'Status Fatigue', 'Keputusan'
      ];

      final rowsData = <List<String>>[];
      for (int i = 0; i < _data.length; i++) {
        final r = _data[i];
        final t1 = (r['t1'] as num?)?.toDouble() ?? 0;
        final t2 = (r['t2'] as num?)?.toDouble() ?? 0;
        final t3 = (r['t3'] as num?)?.toDouble() ?? 0;
        final t4 = (r['t4'] as num?)?.toDouble() ?? 0;
        final t5 = (r['t5'] as num?)?.toDouble() ?? 0;
        final t6 = (r['t6'] as num?)?.toDouble() ?? 0;
        final total = t1 + t2 + t3 + t4 + t5 + t6;
        final avg = (r['avg_reaction'] as num?)?.toDouble() ?? 0;

        final tglStr = (r['tanggal'] ?? '').toString();
        rowsData.add([
          (i + 1).toString(),
          tglStr.length > 16 ? tglStr.substring(0, 16) : tglStr,
          (r['nama'] ?? '').toString(),
          (r['nik'] ?? '').toString(),
          (r['usia']?.toString() ?? ''),
          (r['jabatan'] ?? r['divisi'] ?? '').toString(),
          '${t1.toStringAsFixed(0)},${t2.toStringAsFixed(0)},${t3.toStringAsFixed(0)},${t4.toStringAsFixed(0)},${t5.toStringAsFixed(0)},${t6.toStringAsFixed(0)}',
          total.toStringAsFixed(0),
          avg.toStringAsFixed(1),
          (r['fatigue_level'] ?? 'Normal').toString(),
          (r['keputusan'] ?? '-').toString(),
        ]);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: pw_pdf.PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('LAPORAN HASIL PENGUJIAN KELELAHAN (${SettingsService().appName.toUpperCase()} TEST)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: pw_pdf.PdfColors.blueGrey900)),
                  pw.Text('Dicetak: ${DateTime.now().toIso8601String().substring(0, 10)}', style: const pw.TextStyle(fontSize: 9, color: pw_pdf.PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: pw_pdf.PdfColors.blueGrey300),
              pw.SizedBox(height: 6),
            ],
          ),
          footer: (pw.Context ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${SettingsService().companyName} — ${SettingsService().appName} Mobile', style: const pw.TextStyle(fontSize: 8, color: pw_pdf.PdfColors.grey600)),
              pw.Text('Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: pw_pdf.PdfColors.grey600)),
            ],
          ),
          build: (pw.Context ctx) => [
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rowsData,
              border: pw.TableBorder.all(color: pw_pdf.PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pw_pdf.PdfColors.white, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: pw_pdf.PdfColor.fromInt(0xFF2C3E50)),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FixedColumnWidth(25),
                1: const pw.FixedColumnWidth(70),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(55),
                4: const pw.FixedColumnWidth(30),
                5: const pw.FixedColumnWidth(70),
                6: const pw.FixedColumnWidth(110),
                7: const pw.FixedColumnWidth(45),
                8: const pw.FixedColumnWidth(45),
                9: const pw.FixedColumnWidth(75),
                10: const pw.FixedColumnWidth(100),
              },
            ),
          ],
        ),
      );

      final pdfBytes = await doc.save();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'Export_RATIG_$ts.pdf';
      final savedDirectly = await _saveToPublicDownload(filename, pdfBytes);
      if (savedDirectly) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berkas PDF berhasil disimpan ke folder Download/$filename'), backgroundColor: Colors.green),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$filename';
      await File(path).writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf', name: filename)],
        subject: 'Export Riwayat RATIG PDF (${_data.length} data)',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ekspor PDF: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih Format Ekspor', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.table_view_rounded, color: Colors.greenAccent),
                title: Text('Ekspor ke Excel (.xlsx)', style: GoogleFonts.inter(color: Colors.white)),
                subtitle: Text('Format Excel terstruktur dengan tabel lengkap', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportToExcel();
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.blueAccent),
                title: Text('Ekspor ke CSV (.csv)', style: GoogleFonts.inter(color: Colors.white)),
                subtitle: Text('Format text standar pemisah koma (UTF-8)', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportToCSV();
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                title: Text('Ekspor ke PDF (.pdf)', style: GoogleFonts.inter(color: Colors.white)),
                subtitle: Text('Laporan PDF cetak terformat A4 Landscape', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportToPDF();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importResults() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null) return;

      setState(() => _isLoading = true);

      final bytes = result.files.single.bytes ?? await File(result.files.single.path!).readAsBytes();
      final filename = result.files.single.name.toLowerCase();

      int count = 0;
      int skipped = 0;

      if (filename.endsWith('.csv')) {
        // Parse CSV
        final content = String.fromCharCodes(bytes);
        final lines = content.split('\n');
        if (lines.isEmpty) throw 'File CSV kosong';

        // Get headers
        final headers = lines.first.split(',').map((h) => h.trim().toLowerCase().replaceAll('"', '')).toList();

        // Helper maps indices
        int idxTanggal = headers.indexWhere((h) => h == 'tanggal');
        int idxNama = headers.indexWhere((h) => h == 'nama');
        int idxNik = headers.indexWhere((h) => h == 'nik');
        int idxUsia = headers.indexWhere((h) => h == 'usia');
        int idxJk = headers.indexWhere((h) => h == 'jenis_kelamin' || h == 'gender' || h == 'jenis kelamin');
        int idxJabatan = headers.indexWhere((h) => h == 'jabatan' || h == 'bagian');
        int idxContractor = headers.indexWhere((h) => h == 'contractor' || h == 'kontraktor');
        int idxPlan = headers.indexWhere((h) => h == 'plan');
        int idxDivisi = headers.indexWhere((h) => h == 'divisi' || h == 'perusahaan/bagian');
        int idxT1 = headers.indexWhere((h) => h == 't1');
        int idxT2 = headers.indexWhere((h) => h == 't2');
        int idxT3 = headers.indexWhere((h) => h == 't3');
        int idxT4 = headers.indexWhere((h) => h == 't4');
        int idxT5 = headers.indexWhere((h) => h == 't5');
        int idxT6 = headers.indexWhere((h) => h == 't6');
        int idxAvg = headers.indexWhere((h) => h == 'rata-rata hft' || h == 'avg_reaction');
        int idxSistol = headers.indexWhere((h) => h == 'td sistol' || h == 'td_sistol');
        int idxDiastol = headers.indexWhere((h) => h == 'td diastol' || h == 'td_diastol');
        int idxNadi = headers.indexWhere((h) => h == 'nadi');
        int idxAlcohol = headers.indexWhere((h) => h == 'kadar alkohol' || h == 'alcohol_test');
        int idxFatigue = headers.indexWhere((h) => h == 'kesimpulan (fatigue)' || h == 'fatigue_level');
        int idxKesSistol = headers.indexWhere((h) => h == 'kesimpulan (sistol)' || h == 'kesimpulan_sistol');
        int idxKesDiastol = headers.indexWhere((h) => h == 'kesimpulan (diastol)' || h == 'kesimpulan_diastol');
        int idxKesNadi = headers.indexWhere((h) => h == 'kesimpulan (nadi)' || h == 'kesimpulan_nadi');
        int idxKesAlc = headers.indexWhere((h) => h == 'kesimpulan (alkohol)' || h == 'kesimpulan_alkohol');
        int idxKeputusan = headers.indexWhere((h) => h == 'keputusan');
        int idxRekomendasi = headers.indexWhere((h) => h == 'rekomendasi');
        int idxKeterangan = headers.indexWhere((h) => h == 'keterangan');

        if (idxNama == -1 || idxNik == -1) {
          throw 'Header file minimal harus memiliki kolom "nama" dan "nik"';
        }

        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          final values = line.split(',').map((v) => v.trim().replaceAll('"', '')).toList();
          if (values.length <= idxNama || values.length <= idxNik) continue;

          final String nama = values[idxNama];
          final String nik = values[idxNik].toUpperCase();
          if (nama.isEmpty || nik.isEmpty) continue;

          final String tanggal = idxTanggal != -1 && values.length > idxTanggal ? values[idxTanggal] : DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19);
          final String usia = idxUsia != -1 && values.length > idxUsia ? values[idxUsia] : '';
          final String jk = idxJk != -1 && values.length > idxJk ? values[idxJk] : 'Laki-laki';
          final String jabatan = idxJabatan != -1 && values.length > idxJabatan ? values[idxJabatan] : '';
          final String contractor = idxContractor != -1 && values.length > idxContractor ? values[idxContractor] : '';
          final String plan = idxPlan != -1 && values.length > idxPlan ? values[idxPlan] : '';
          final String divisi = idxDivisi != -1 && values.length > idxDivisi ? values[idxDivisi] : '';

          final double t1 = idxT1 != -1 && values.length > idxT1 ? double.tryParse(values[idxT1]) ?? 0.0 : 0.0;
          final double t2 = idxT2 != -1 && values.length > idxT2 ? double.tryParse(values[idxT2]) ?? 0.0 : 0.0;
          final double t3 = idxT3 != -1 && values.length > idxT3 ? double.tryParse(values[idxT3]) ?? 0.0 : 0.0;
          final double t4 = idxT4 != -1 && values.length > idxT4 ? double.tryParse(values[idxT4]) ?? 0.0 : 0.0;
          final double t5 = idxT5 != -1 && values.length > idxT5 ? double.tryParse(values[idxT5]) ?? 0.0 : 0.0;
          final double t6 = idxT6 != -1 && values.length > idxT6 ? double.tryParse(values[idxT6]) ?? 0.0 : 0.0;
          final double avg = idxAvg != -1 && values.length > idxAvg ? double.tryParse(values[idxAvg]) ?? 0.0 : 0.0;

          final double sistol = idxSistol != -1 && values.length > idxSistol ? double.tryParse(values[idxSistol]) ?? 0.0 : 0.0;
          final double diastol = idxDiastol != -1 && values.length > idxDiastol ? double.tryParse(values[idxDiastol]) ?? 0.0 : 0.0;
          final double nadi = idxNadi != -1 && values.length > idxNadi ? double.tryParse(values[idxNadi]) ?? 0.0 : 0.0;
          final double alcohol = idxAlcohol != -1 && values.length > idxAlcohol ? double.tryParse(values[idxAlcohol]) ?? 0.0 : 0.0;

          final String fatigue = idxFatigue != -1 && values.length > idxFatigue ? values[idxFatigue] : 'Normal';
          final String kesSistol = idxKesSistol != -1 && values.length > idxKesSistol ? values[idxKesSistol] : '';
          final String kesDiastol = idxKesDiastol != -1 && values.length > idxKesDiastol ? values[idxKesDiastol] : '';
          final String kesNadi = idxKesNadi != -1 && values.length > idxKesNadi ? values[idxKesNadi] : '';
          final String kesAlc = idxKesAlc != -1 && values.length > idxKesAlc ? values[idxKesAlc] : '';
          final String keputusan = idxKeputusan != -1 && values.length > idxKeputusan ? values[idxKeputusan] : '';
          final String rekomendasi = idxRekomendasi != -1 && values.length > idxRekomendasi ? values[idxRekomendasi] : '';
          final String keterangan = idxKeterangan != -1 && values.length > idxKeterangan ? values[idxKeterangan] : '';

          final row = {
            'tanggal': tanggal,
            'nama': nama,
            'nik': nik,
            'usia': usia,
            'jenis_kelamin': jk,
            'jabatan': jabatan,
            'contractor': contractor,
            'plan': plan,
            'divisi': divisi,
            't1': t1, 't2': t2, 't3': t3,
            't4': t4, 't5': t5, 't6': t6,
            'avg_reaction': avg,
            'td_sistol': sistol,
            'td_diastol': diastol,
            'nadi': nadi,
            'alcohol_test': alcohol,
            'fatigue_level': fatigue,
            'kesimpulan_sistol': kesSistol,
            'kesimpulan_diastol': kesDiastol,
            'kesimpulan_nadi': kesNadi,
            'kesimpulan_alkohol': kesAlc,
            'keputusan': keputusan,
            'rekomendasi': rekomendasi,
            'keterangan': keterangan,
          };

          final inserted = await DBHelper().insertResultWithDuplicateCheck(row);
          if (inserted) {
            count++;
          } else {
            skipped++;
          }
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

        // Helper maps indices
        int idxTanggal = headers.indexWhere((h) => h == 'tanggal');
        int idxNama = headers.indexWhere((h) => h == 'nama');
        int idxNik = headers.indexWhere((h) => h == 'nik');
        int idxUsia = headers.indexWhere((h) => h == 'usia');
        int idxJk = headers.indexWhere((h) => h == 'jenis_kelamin' || h == 'gender' || h == 'jenis_kelamin');
        int idxJabatan = headers.indexWhere((h) => h == 'jabatan' || h == 'bagian');
        int idxContractor = headers.indexWhere((h) => h == 'contractor' || h == 'kontraktor');
        int idxPlan = headers.indexWhere((h) => h == 'plan');
        int idxDivisi = headers.indexWhere((h) => h == 'divisi' || h == 'perusahaan/bagian');
        int idxT1 = headers.indexWhere((h) => h == 't1');
        int idxT2 = headers.indexWhere((h) => h == 't2');
        int idxT3 = headers.indexWhere((h) => h == 't3');
        int idxT4 = headers.indexWhere((h) => h == 't4');
        int idxT5 = headers.indexWhere((h) => h == 't5');
        int idxT6 = headers.indexWhere((h) => h == 't6');
        int idxAvg = headers.indexWhere((h) => h == 'rata-rata_hft' || h == 'avg_reaction' || h == 'rata_rata_hft');
        int idxSistol = headers.indexWhere((h) => h == 'td_sistol' || h == 'sistol');
        int idxDiastol = headers.indexWhere((h) => h == 'td_diastol' || h == 'diastol');
        int idxNadi = headers.indexWhere((h) => h == 'nadi');
        int idxAlcohol = headers.indexWhere((h) => h == 'kadar_alkohol' || h == 'alcohol_test' || h == 'kadar_alkohol');
        int idxFatigue = headers.indexWhere((h) => h == 'kesimpulan_(fatigue)' || h == 'fatigue_level' || h.contains('fatigue'));
        int idxKesSistol = headers.indexWhere((h) => h == 'kesimpulan_(sistol)' || h == 'kesimpulan_sistol');
        int idxKesDiastol = headers.indexWhere((h) => h == 'kesimpulan_(diastol)' || h == 'kesimpulan_diastol');
        int idxKesNadi = headers.indexWhere((h) => h == 'kesimpulan_(nadi)' || h == 'kesimpulan_nadi');
        int idxKesAlc = headers.indexWhere((h) => h == 'kesimpulan_(alkohol)' || h == 'kesimpulan_alkohol');
        int idxKeputusan = headers.indexWhere((h) => h == 'keputusan');
        int idxRekomendasi = headers.indexWhere((h) => h == 'rekomendasi');
        int idxKeterangan = headers.indexWhere((h) => h == 'keterangan');

        if (idxNama == -1 || idxNik == -1) {
          throw 'Header Excel minimal harus memiliki kolom "Nama" dan "NIK"';
        }

        for (int i = 1; i < sheet.maxRows; i++) {
          final rowData = sheet.rows[i];
          if (rowData.isEmpty) continue;

          final String nama = idxNama != -1 && rowData.length > idxNama ? rowData[idxNama]?.value?.toString().trim() ?? '' : '';
          final String nik = idxNik != -1 && rowData.length > idxNik ? rowData[idxNik]?.value?.toString().trim().toUpperCase() ?? '' : '';

          if (nama.isEmpty || nik.isEmpty) continue;

          final String tanggal = idxTanggal != -1 && rowData.length > idxTanggal ? rowData[idxTanggal]?.value?.toString().trim() ?? DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19) : DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19);
          final String usia = idxUsia != -1 && rowData.length > idxUsia ? rowData[idxUsia]?.value?.toString().trim() ?? '' : '';
          final String jk = idxJk != -1 && rowData.length > idxJk ? rowData[idxJk]?.value?.toString().trim() ?? 'Laki-laki' : 'Laki-laki';
          final String jabatan = idxJabatan != -1 && rowData.length > idxJabatan ? rowData[idxJabatan]?.value?.toString().trim() ?? '' : '';
          final String contractor = idxContractor != -1 && rowData.length > idxContractor ? rowData[idxContractor]?.value?.toString().trim() ?? '' : '';
          final String plan = idxPlan != -1 && rowData.length > idxPlan ? rowData[idxPlan]?.value?.toString().trim() ?? '' : '';
          final String divisi = idxDivisi != -1 && rowData.length > idxDivisi ? rowData[idxDivisi]?.value?.toString().trim() ?? '' : '';

          final double t1 = idxT1 != -1 && rowData.length > idxT1 ? double.tryParse(rowData[idxT1]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double t2 = idxT2 != -1 && rowData.length > idxT2 ? double.tryParse(rowData[idxT2]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double t3 = idxT3 != -1 && rowData.length > idxT3 ? double.tryParse(rowData[idxT3]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double t4 = idxT4 != -1 && rowData.length > idxT4 ? double.tryParse(rowData[idxT4]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double t5 = idxT5 != -1 && rowData.length > idxT5 ? double.tryParse(rowData[idxT5]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double t6 = idxT6 != -1 && rowData.length > idxT6 ? double.tryParse(rowData[idxT6]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double avg = idxAvg != -1 && rowData.length > idxAvg ? double.tryParse(rowData[idxAvg]?.value?.toString() ?? '') ?? 0.0 : 0.0;

          final double sistol = idxSistol != -1 && rowData.length > idxSistol ? double.tryParse(rowData[idxSistol]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double diastol = idxDiastol != -1 && rowData.length > idxDiastol ? double.tryParse(rowData[idxDiastol]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double nadi = idxNadi != -1 && rowData.length > idxNadi ? double.tryParse(rowData[idxNadi]?.value?.toString() ?? '') ?? 0.0 : 0.0;
          final double alcohol = idxAlcohol != -1 && rowData.length > idxAlcohol ? double.tryParse(rowData[idxAlcohol]?.value?.toString() ?? '') ?? 0.0 : 0.0;

          final String fatigue = idxFatigue != -1 && rowData.length > idxFatigue ? rowData[idxFatigue]?.value?.toString().trim() ?? 'Normal' : 'Normal';
          final String kesSistol = idxKesSistol != -1 && rowData.length > idxKesSistol ? rowData[idxKesSistol]?.value?.toString().trim() ?? '' : '';
          final String kesDiastol = idxKesDiastol != -1 && rowData.length > idxKesDiastol ? rowData[idxKesDiastol]?.value?.toString().trim() ?? '' : '';
          final String kesNadi = idxKesNadi != -1 && rowData.length > idxKesNadi ? rowData[idxKesNadi]?.value?.toString().trim() ?? '' : '';
          final String kesAlc = idxKesAlc != -1 && rowData.length > idxKesAlc ? rowData[idxKesAlc]?.value?.toString().trim() ?? '' : '';
          final String keputusan = idxKeputusan != -1 && rowData.length > idxKeputusan ? rowData[idxKeputusan]?.value?.toString().trim() ?? '' : '';
          final String rekomendasi = idxRekomendasi != -1 && rowData.length > idxRekomendasi ? rowData[idxRekomendasi]?.value?.toString().trim() ?? '' : '';
          final String keterangan = idxKeterangan != -1 && rowData.length > idxKeterangan ? rowData[idxKeterangan]?.value?.toString().trim() ?? '' : '';

          final row = {
            'tanggal': tanggal,
            'nama': nama,
            'nik': nik,
            'usia': usia,
            'jenis_kelamin': jk,
            'jabatan': jabatan,
            'contractor': contractor,
            'plan': plan,
            'divisi': divisi,
            't1': t1, 't2': t2, 't3': t3,
            't4': t4, 't5': t5, 't6': t6,
            'avg_reaction': avg,
            'td_sistol': sistol,
            'td_diastol': diastol,
            'nadi': nadi,
            'alcohol_test': alcohol,
            'fatigue_level': fatigue,
            'kesimpulan_sistol': kesSistol,
            'kesimpulan_diastol': kesDiastol,
            'kesimpulan_nadi': kesNadi,
            'kesimpulan_alkohol': kesAlc,
            'keputusan': keputusan,
            'rekomendasi': rekomendasi,
            'keterangan': keterangan,
          };

          final inserted = await DBHelper().insertResultWithDuplicateCheck(row);
          if (inserted) {
            count++;
          } else {
            skipped++;
          }
        }
      }

      await _load();
      if (!mounted) return;
      String msg = '$count data berhasil diimpor.';
      if (skipped > 0) {
        msg += ' $skipped data dilewati (duplikat).';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal impor data: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Color _fatigueColor(String? level) {
    switch (level) {
      case 'Normal': return const Color(0xFFFFFFFF);
      case 'Fatigue Ringan': return const Color(0xFF2ECC71);
      case 'Fatigue Sedang': return const Color(0xFFF1C40F);
      case 'Fatigue Berat': return const Color(0xFFE74C3C);
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0B0F19)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Expanded(child: Text('🔍 Filter & Riwayat', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                    if (_selectedIds.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Hapus Terpilih (${_selectedIds.length})',
                        onPressed: _deleteSelected,
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                      tooltip: 'Hapus Semua (yang tampil)',
                      onPressed: _deleteAll,
                    ),
                    IconButton(
                      icon: _isExporting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F2FE)))
                          : const Icon(Icons.download_rounded, color: Color(0xFF00F2FE)),
                      tooltip: 'Ekspor Data (filter aktif)',
                      onPressed: _isExporting ? null : _showExportOptions,
                    ),
                    IconButton(
                      icon: const Icon(Icons.upload_file_rounded, color: Colors.orangeAccent),
                      tooltip: 'Impor Hasil Tes (.xlsx / .csv)',
                      onPressed: _isLoading ? null : _importResults,
                    ),
                    IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: _isLoading ? null : _load),
                  ],
                ),
              ),
              // Filter Panel
              _buildFilterPanel(),
              // Active filter chip
              if (_filterActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt, color: Color(0xFF00F2FE), size: 16),
                      const SizedBox(width: 4),
                      Text('Filter aktif — ${_data.length} data', style: GoogleFonts.inter(color: const Color(0xFF00F2FE), fontSize: 12)),
                      const Spacer(),
                      TextButton(
                        onPressed: _resetFilter,
                        child: Text('Reset', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              // Select All / deselect
              if (_data.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedIds.length == _data.length,
                        tristate: true,
                        activeColor: Colors.redAccent,
                        onChanged: (v) {
                          setState(() {
                            if (_selectedIds.length == _data.length) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds = _data.map((e) => e['id'] as int).toSet();
                            }
                          });
                        },
                      ),
                      Text(
                        _selectedIds.isEmpty ? 'Pilih semua untuk hapus' : '${_selectedIds.length} dipilih',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F2FE)))
                    : _data.isEmpty
                        ? Center(child: Text('Tidak ada data', style: GoogleFonts.inter(color: Colors.white30)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _data.length,
                            itemBuilder: (ctx, i) => _buildCard(_data[i], i),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        child: Column(
          children: [
            // Row 1: Search + tanggal
            Row(
              children: [
                Expanded(child: _filterField(_searchCtrl, 'Cari Nama/NIK', Icons.search)),
                const SizedBox(width: 8),
                Expanded(child: _filterField(_dariCtrl, 'Dari (tgl)', Icons.calendar_today, onTap: () => _pickDate(_dariCtrl))),
                const SizedBox(width: 8),
                Expanded(child: _filterField(_sampaiCtrl, 'Sampai (tgl)', Icons.calendar_today, onTap: () => _pickDate(_sampaiCtrl))),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Jabatan + dropdowns + buttons
            Row(
              children: [
                Expanded(child: _filterField(_jabatanCtrl, 'Jabatan', Icons.work_outline)),
                const SizedBox(width: 8),
                Expanded(child: _dropdownField('Fatigue', _fatigueLevels, _fatigueFilter, (v) => setState(() => _fatigueFilter = v!))),
                const SizedBox(width: 8),
                Expanded(child: _dropdownField('Keputusan', _keputusanOptions, _keputusanFilter, (v) => setState(() => _keputusanFilter = v!))),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F2FE), foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onPressed: _applyFilter,
                  child: Text('Filter', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterField(TextEditingController ctrl, String hint, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: TextField(
        controller: ctrl,
        readOnly: onTap != null,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
        onSubmitted: (_) => _applyFilter(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
          prefixIcon: Icon(icon, color: Colors.white30, size: 16),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00F2FE), width: 1)),
        ),
      ),
    );
  }

  Widget _dropdownField(String hint, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E1B4B),
        style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, int index) {
    final id = item['id'] as int;
    final fColor = _fatigueColor(item['fatigue_level']);
    final avg = (item['avg_reaction'] as num?)?.toDouble() ?? 0;
    final tanggal = (item['tanggal'] ?? '').toString();
    final nik = item['nik']?.toString() ?? '';
    final hasWarning = _warningNiks.contains(nik);
    final isSelected = _selectedIds.contains(id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        opacity: 0.05,
        border: Border.all(
          color: isSelected
              ? Colors.redAccent.withValues(alpha: 0.7)
              : hasWarning
                  ? Colors.redAccent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
          width: isSelected ? 2 : 1,
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => MedisScreen(
              dbId: id, avgReaction: avg,
              fatigueLevel: item['fatigue_level'] ?? '',
              mode: (item['mode'] ?? '').isNotEmpty ? item['mode'] : widget.mode,
            ),
          )).then((_) => _load());
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              activeColor: Colors.redAccent,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedIds.add(id);
                  } else {
                    _selectedIds.remove(id);
                  }
                });
              },
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (hasWarning)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Kelelahan Ekstrem 3x berturut-turut!', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                    ]),
                  ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['nama'] ?? '-', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('NIK: ${item['nik'] ?? '-'}  •  ${item['jabatan'] ?? '-'}', style: GoogleFonts.inter(color: Colors.blueGrey[300], fontSize: 12)),
                    Text(tanggal.length >= 10 ? tanggal.substring(0, 16) : tanggal, style: GoogleFonts.inter(color: Colors.blueGrey[500], fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: fColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: fColor.withValues(alpha: 0.5))),
                      child: Text(item['fatigue_level'] ?? '-', style: GoogleFonts.inter(color: fColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                    const SizedBox(height: 4),
                    Text('${avg.toStringAsFixed(1)} ms', style: GoogleFonts.outfit(color: const Color(0xFF00F2FE), fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 4, children: [1, 2, 3, 4, 5, 6].map((n) {
                  final val = (item['t$n'] as num?)?.toDouble() ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
                    child: Text('T$n:${val > 0 ? val.toStringAsFixed(0) : '-'}', style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
                  );
                }).toList()),
                if ((item['alcohol_test'] ?? '') != '')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('🍺 Alkohol: ${item['alcohol_test']}% → ${item['kesimpulan_alkohol'] ?? '-'}', style: GoogleFonts.inter(fontSize: 11, color: Colors.orangeAccent)),
                  ),
                if ((item['keputusan'] ?? '') != '')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('⚕ ${item['keputusan']}', style: GoogleFonts.inter(fontSize: 11, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
