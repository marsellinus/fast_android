import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/db_helper.dart';
import '../widgets/glass_card.dart';

class MedisScreen extends StatefulWidget {
  final int dbId;
  final double avgReaction;
  final String fatigueLevel;
  final String mode;

  const MedisScreen({super.key, required this.dbId, required this.avgReaction, required this.fatigueLevel, required this.mode});

  @override
  State<MedisScreen> createState() => _MedisScreenState();
}

class _MedisScreenState extends State<MedisScreen> {
  bool get isParamedis => widget.mode == 'Paramedis';

  final _sistolCtrl    = TextEditingController();
  final _diastolCtrl   = TextEditingController();
  final _nadiCtrl      = TextEditingController();
  final _alcoholCtrl   = TextEditingController();
  final _keluhanCtrl       = TextEditingController();
  final _diagnosisAwalCtrl = TextEditingController();
  final _tindakanMedisCtrl = TextEditingController();
  final _pemberianObatCtrl = TextEditingController();
  final _keteranganCtrl    = TextEditingController();

  String? _kesimpulanSistol;
  String? _kesimpulanDiastol;
  String? _kesimpulanNadi;
  String? _kesimpulanAlkohol;
  String? _keputusan;
  String? _rekomendasi;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _sistolCtrl.dispose();
    _diastolCtrl.dispose();
    _nadiCtrl.dispose();
    _alcoholCtrl.dispose();
    _keluhanCtrl.dispose();
    _diagnosisAwalCtrl.dispose();
    _tindakanMedisCtrl.dispose();
    _pemberianObatCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final db = DBHelper();
    final results = await db.getAllResults();
    final row = results.firstWhere((r) => r['id'] == widget.dbId, orElse: () => {});
    if (row.isEmpty) return;

    setState(() {
      _sistolCtrl.text    = row['td_sistol']?.toString() ?? '';
      _diastolCtrl.text   = row['td_diastol']?.toString() ?? '';
      _nadiCtrl.text      = row['nadi']?.toString() ?? '';
      _alcoholCtrl.text   = row['alcohol_test'] != null ? double.tryParse(row['alcohol_test'].toString())?.toStringAsFixed(2) ?? '' : '';
      _keluhanCtrl.text       = row['keluhan'] ?? '';
      _diagnosisAwalCtrl.text = row['diagnosis_awal'] ?? '';
      _tindakanMedisCtrl.text = row['tindakan_medis'] ?? '';
      _pemberianObatCtrl.text = row['pemberian_obat'] ?? '';
      _keteranganCtrl.text    = row['keterangan'] ?? '';

      _kesimpulanSistol   = row['kesimpulan_sistol'];
      _kesimpulanDiastol  = row['kesimpulan_diastol'];
      _kesimpulanNadi     = row['kesimpulan_nadi'];
      _kesimpulanAlkohol  = row['kesimpulan_alkohol'];
      _keputusan          = row['keputusan'];
      _rekomendasi        = row['rekomendasi'];
    });
  }

  void _autoCalc() {
    setState(() {
      if (isParamedis) {
        final sis = double.tryParse(_sistolCtrl.text) ?? 0;
        if (sis > 0) {
          if (sis < 100) {
            _kesimpulanSistol = 'Hipotensi';
          } else if (sis < 140) {
            _kesimpulanSistol = 'Normal';
          } else if (sis < 160) {
            _kesimpulanSistol = 'Hypertensi Ringan';
          } else if (sis < 180) {
            _kesimpulanSistol = 'Hypertensi Sedang';
          } else {
            _kesimpulanSistol = 'Hypertensi Berat';
          }
        }
        final dia = double.tryParse(_diastolCtrl.text) ?? 0;
        if (dia > 0) {
          if (dia < 70) {
            _kesimpulanDiastol = 'Hipotensi';
          } else if (dia < 90) {
            _kesimpulanDiastol = 'Normal';
          } else if (dia < 100) {
            _kesimpulanDiastol = 'Hypertensi Ringan';
          } else if (dia < 120) {
            _kesimpulanDiastol = 'Hypertensi Sedang';
          } else {
            _kesimpulanDiastol = 'Hypertensi Berat';
          }
        }
        final nad = double.tryParse(_nadiCtrl.text) ?? 0;
        if (nad > 0) {
          if (nad < 60) {
            _kesimpulanNadi = 'Bradikardia';
          } else if (nad < 100) {
            _kesimpulanNadi = 'Normal';
          } else if (nad < 110) {
            _kesimpulanNadi = 'Takikardia Ringan';
          } else if (nad < 120) {
            _kesimpulanNadi = 'Takikardia Sedang';
          } else {
            _kesimpulanNadi = 'Takikardia Berat';
          }
        }
      }
      final alc = double.tryParse(_alcoholCtrl.text) ?? -1;
      if (alc >= 0) {
        _kesimpulanAlkohol = alc < 0.08 ? 'Lolos' : 'Tidak Lolos';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Kesimpulan otomatis dihitung!', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF00E676),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    double? alcDouble;
    if (_alcoholCtrl.text.isNotEmpty) alcDouble = double.tryParse(_alcoholCtrl.text);

    final medisData = <String, dynamic>{
      if (isParamedis) ...{
        'td_sistol':          double.tryParse(_sistolCtrl.text),
        'td_diastol':         double.tryParse(_diastolCtrl.text),
        'nadi':               double.tryParse(_nadiCtrl.text),
        'kesimpulan_sistol':  _kesimpulanSistol,
        'kesimpulan_diastol': _kesimpulanDiastol,
        'kesimpulan_nadi':    _kesimpulanNadi,
        'keputusan':          _keputusan,
        'rekomendasi':        _rekomendasi,
        'keluhan':            _keluhanCtrl.text.trim(),
        'diagnosis_awal':     _diagnosisAwalCtrl.text.trim(),
        'tindakan_medis':     _tindakanMedisCtrl.text.trim(),
        'pemberian_obat':     _pemberianObatCtrl.text.trim(),
      },
      'alcohol_test':       alcDouble,
      'kesimpulan_alkohol': _kesimpulanAlkohol,
      'keterangan':         _keteranganCtrl.text.trim(),
    };

    medisData.removeWhere((k, v) => v == null || v == '');
    await DBHelper().updateMedis(widget.dbId, medisData);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Data medis berhasil disimpan!', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00E676),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
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
                    Expanded(child: Text(isParamedis ? 'Rekam Medis' : 'Alcohol Test', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Bar
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Avg Reaction Time', style: GoogleFonts.inter(color: Colors.blueGrey[300], fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('${widget.avgReaction.toStringAsFixed(1)} ms', style: GoogleFonts.outfit(color: const Color(0xFF00F2FE), fontSize: 24, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: _fatigueColor(widget.fatigueLevel).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _fatigueColor(widget.fatigueLevel))),
                              child: Text(widget.fatigueLevel, style: GoogleFonts.inter(color: _fatigueColor(widget.fatigueLevel), fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (isParamedis) ...[
                        const _SectionTitle(title: 'VITAL SIGN', icon: Icons.monitor_heart_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _GlassTextField(controller: _sistolCtrl, label: 'Sistol', isNumber: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _GlassTextField(controller: _diastolCtrl, label: 'Diastol', isNumber: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _GlassTextField(controller: _nadiCtrl, label: 'Nadi', isNumber: true)),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],

                      const _SectionTitle(title: 'ALCOHOL TEST', icon: Icons.local_drink_outlined),
                      const SizedBox(height: 16),
                      _GlassTextField(controller: _alcoholCtrl, label: 'Kadar Alkohol (BAC %)', hint: '0.00', isNumber: true),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _autoCalc,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text('Hitung Kesimpulan Otomatis', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00F2FE),
                            side: const BorderSide(color: Color(0xFF00F2FE)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      if (isParamedis) ...[
                        const _SectionTitle(title: 'KESIMPULAN MEDIS', icon: Icons.fact_check_outlined),
                        const SizedBox(height: 16),
                        _GlassDropdown(label: 'Kesimpulan Sistol', value: _kesimpulanSistol, items: const ['Hipotensi', 'Normal', 'Hypertensi Ringan', 'Hypertensi Sedang', 'Hypertensi Berat'], onChanged: (v) => setState(() => _kesimpulanSistol = v)),
                        _GlassDropdown(label: 'Kesimpulan Diastol', value: _kesimpulanDiastol, items: const ['Hipotensi', 'Normal', 'Hypertensi Ringan', 'Hypertensi Sedang', 'Hypertensi Berat'], onChanged: (v) => setState(() => _kesimpulanDiastol = v)),
                        _GlassDropdown(label: 'Kesimpulan Nadi', value: _kesimpulanNadi, items: const ['Bradikardia', 'Normal', 'Takikardia Ringan', 'Takikardia Sedang', 'Takikardia Berat'], onChanged: (v) => setState(() => _kesimpulanNadi = v)),
                      ],

                      _GlassDropdown(label: 'Kesimpulan Alkohol', value: _kesimpulanAlkohol, items: const ['Lolos', 'Tidak Lolos'], onChanged: (v) => setState(() => _kesimpulanAlkohol = v)),

                      if (isParamedis) ...[
                        const SizedBox(height: 32),
                        const _SectionTitle(title: 'DATA MEDIS TAMBAHAN', icon: Icons.medical_information_outlined),
                        const SizedBox(height: 16),
                        _GlassTextField(controller: _keluhanCtrl, label: 'Keluhan Pasien', maxLines: 2),
                        _GlassTextField(controller: _diagnosisAwalCtrl, label: 'Diagnosis Awal', maxLines: 2),
                        _GlassTextField(controller: _tindakanMedisCtrl, label: 'Tindakan Medis', maxLines: 2),
                        _GlassTextField(controller: _pemberianObatCtrl, label: 'Pemberian Obat', maxLines: 2),

                        const SizedBox(height: 32),
                        const _SectionTitle(title: 'KEPUTUSAN & REKOMENDASI', icon: Icons.gavel_outlined),
                        const SizedBox(height: 16),
                        _GlassDropdown(label: 'Keputusan', value: _keputusan, items: const ['Diizinkan bekerja', 'Diizinkan bekerja, dengan catatan', 'Tidak diizinkan bekerja', 'Rujuk ke Faskes'], onChanged: (v) => setState(() => _keputusan = v)),
                        _GlassDropdown(label: 'Rekomendasi', value: _rekomendasi, items: const ['Manajemen Fatigue', 'Manajemen Hipertensi', 'Manajemen Fatigue & Hipertensi', 'Istirahat', 'Lainnya'], onChanged: (v) => setState(() => _rekomendasi = v)),
                      ],

                      const SizedBox(height: 32),
                      const _SectionTitle(title: 'KETERANGAN LAIN', icon: Icons.notes),
                      const SizedBox(height: 16),
                      _GlassTextField(controller: _keteranganCtrl, label: 'Catatan tambahan...', maxLines: 3),

                      const SizedBox(height: 48),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.save_outlined),
                          label: Text('SIMPAN REKAM MEDIS', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isParamedis ? Colors.purpleAccent : const Color(0xFF00F2FE),
                            foregroundColor: isParamedis ? Colors.white : Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _fatigueColor(String level) {
    switch (level) {
      case 'Normal': return const Color(0xFFFFFFFF);
      case 'Fatigue Ringan': return const Color(0xFF2ECC71);
      case 'Fatigue Sedang': return const Color(0xFFF1C40F);
      case 'Fatigue Berat': return const Color(0xFFE74C3C);
      default: return Colors.grey;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey[300], size: 16),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey[300], letterSpacing: 1.5)),
      ],
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isNumber;
  final String? hint;
  final int maxLines;

  const _GlassTextField({required this.controller, required this.label, this.isNumber = false, this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
          labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
        ),
      ),
    );
  }
}

class _GlassDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _GlassDropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        hint: Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: GoogleFonts.inter(color: Colors.white)))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
        ),
        dropdownColor: const Color(0xFF1E1B4B),
      ),
    );
  }
}
