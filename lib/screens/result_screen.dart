import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../widgets/glass_card.dart';
import 'medis_screen.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> formData;
  final List<double> reactionTimes;

  const ResultScreen({super.key, required this.formData, required this.reactionTimes});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  bool _isSaved = false;
  int? _savedId;
  late double _avg;
  late String _level;
  late Color _levelColor;
  
  int _countdown = 4;
  Timer? _timer;
  
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
    
    _calculateResult();
    _saveToDatabase();
    
    _animController.forward();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _calculateResult() {
    final valid = widget.reactionTimes.where((t) => t > 0 && t <= 2000).toList();
    _avg = valid.isNotEmpty ? valid.reduce((a, b) => a + b) / valid.length : 0;
    _level = _classifyFatigue(_avg);
    _levelColor = _getFatigueColor(_level);
  }

  String _classifyFatigue(double avg) {
    if (avg <= 0) return 'Error/Invalid';
    if (avg < 240) return 'Normal';
    if (avg <= 400) return 'Fatigue Ringan';
    if (avg <= 580) return 'Fatigue Sedang';
    return 'Fatigue Berat';
  }

  Color _getFatigueColor(String level) {
    switch (level) {
      case 'Normal':         return const Color(0xFFFFFFFF);
      case 'Fatigue Ringan': return const Color(0xFF2ECC71);
      case 'Fatigue Sedang': return const Color(0xFFF1C40F);
      case 'Fatigue Berat':  return const Color(0xFFE74C3C);
      default:               return Colors.grey;
    }
  }

  Future<void> _saveToDatabase() async {
    final ts = widget.reactionTimes;
    final row = {
      'tanggal':      DateTime.now().toIso8601String(),
      'nama':         widget.formData['nama'] ?? '',
      'nik':          widget.formData['nik'] ?? '',
      'usia':         widget.formData['usia'] ?? '',
      'jenis_kelamin': widget.formData['jenis_kelamin'] ?? '',
      'jabatan':      widget.formData['jabatan'] ?? '',
      'divisi':       widget.formData['divisi'] ?? '',
      'mode':         widget.formData['mode'] ?? 'SHE Officer',
      't1': ts.isNotEmpty ? ts[0] : 0,
      't2': ts.length > 1  ? ts[1] : 0,
      't3': ts.length > 2  ? ts[2] : 0,
      't4': ts.length > 3  ? ts[3] : 0,
      't5': ts.length > 4  ? ts[4] : 0,
      't6': ts.length > 5  ? ts[5] : 0,
      'avg_reaction':  _avg,
      'fatigue_level': _level,
      'status':       'OK',
    };

    final id = await DBHelper().insertResult(row);
    if (mounted) {
      setState(() {
        _isSaved = true;
        _savedId = id;
      });

      if ((widget.formData['mode'] ?? '') == 'Paramedis') {
        _startCountdown();
      }
    }
  }
  
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _countdown = 0;
          timer.cancel();
          if (_savedId != null) _openMedisForm();
        }
      });
    });
  }

  void _openMedisForm() {
    _timer?.cancel();
    if (_savedId == null) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => MedisScreen(
        dbId: _savedId!,
        avgReaction: _avg,
        fatigueLevel: _level,
        mode: widget.formData['mode'] ?? 'SHE Officer',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final nama = widget.formData['nama'] ?? 'Pekerja';
    final nik  = widget.formData['nik']  ?? '-';
    final mode = widget.formData['mode'] ?? 'SHE Officer';
    final isParamedis = mode == 'Paramedis';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          )
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        _timer?.cancel();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                    ),
                    Text('Hasil Akhir', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 48), // Balancer
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // User Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF00F2FE).withValues(alpha: 0.2),
                            child: const Icon(Icons.person, color: Color(0xFF00F2FE), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nama, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('NIK: $nik', style: GoogleFonts.inter(fontSize: 14, color: Colors.blueGrey[300])),
                              ],
                            ),
                          ),
                          if (_isSaved)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00E676).withValues(alpha: 0.2)),
                              child: const Icon(Icons.check, color: Color(0xFF00E676), size: 16),
                            )
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Main Result Card
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: GlassCard(
                          color: _levelColor,
                          opacity: 0.1,
                          border: Border.all(color: _levelColor.withValues(alpha: 0.5), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          child: Column(
                            children: [
                              Text('WAKTU REAKSI RATA-RATA', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('${_avg.toStringAsFixed(1)} ms', style: GoogleFonts.outfit(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white, shadows: [
                                Shadow(color: _levelColor.withValues(alpha: 0.8), blurRadius: 20)
                              ])),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _levelColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: _levelColor),
                                ),
                                child: Text(_level.toUpperCase(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _levelColor, letterSpacing: 1.5)),
                              ),
                              const SizedBox(height: 16),
                              Text(_getFatigueDescription(_level), style: GoogleFonts.inter(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Trial Results Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: List.generate(6, (i) {
                          final val = i < widget.reactionTimes.length ? widget.reactionTimes[i] : 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Text('T${i+1}: ${val > 0 ? val.toStringAsFixed(0) : '-'}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 40),

                      // Chart
                      if (widget.reactionTimes.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: LineChart(LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawHorizontalLine: true,
                              horizontalInterval: 200,
                              getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final idx = val.toInt();
                                    if (idx >= 0 && idx < 6) return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('T${idx+1}', style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)));
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            minX: 0, maxX: 5, minY: 0, maxY: 1000,
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(y: 240, color: const Color(0xFF00E676).withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
                                HorizontalLine(y: 401, color: const Color(0xFFFF9100).withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
                                HorizontalLine(y: 581, color: const Color(0xFFFF1744).withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
                              ],
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: widget.reactionTimes.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value > 0 ? e.value : 0)).toList(),
                                isCurved: true,
                                color: const Color(0xFF00F2FE),
                                barWidth: 4,
                                isStrokeCapRound: true,
                                belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF00F2FE).withValues(alpha: 0.2), Colors.transparent])),
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          )),
                        ),
                        
                      const SizedBox(height: 40),

                      // Auto countdown text
                      if (isParamedis && _countdown > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Form medis otomatis terbuka dalam $_countdown detik...',
                            style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.purpleAccent),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                      const SizedBox(height: 16),

                      // Next action button
                      if (_isSaved && _savedId != null)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _openMedisForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isParamedis ? Colors.purpleAccent : const Color(0xFF00F2FE),
                              foregroundColor: isParamedis ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isParamedis ? Icons.medical_services_outlined : Icons.local_drink_outlined),
                                const SizedBox(width: 8),
                                Text(
                                  isParamedis ? 'INPUT DATA MEDIS' : 'INPUT ALCOHOL TEST',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
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

  String _getFatigueDescription(String level) {
    switch (level) {
      case 'Normal': return 'Pekerja dalam kondisi sangat prima dan bugar. Siap untuk bekerja tanpa batasan kelelahan.';
      case 'Fatigue Ringan': return 'Terdapat indikasi kelelahan ringan. Tetap dapat bekerja namun disarankan istirahat singkat jika memungkinkan.';
      case 'Fatigue Sedang': return 'Kelelahan tingkat menengah terdeteksi. Perlu evaluasi tambahan sebelum melanjutkan pekerjaan berisiko tinggi.';
      case 'Fatigue Berat': return '⚠ PERINGATAN KRITIS: Kelelahan ekstrem! Sangat dilarang untuk bekerja, risiko kecelakaan sangat tinggi.';
      default: return '';
    }
  }
}
