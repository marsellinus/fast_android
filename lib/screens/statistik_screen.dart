import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../widgets/glass_card.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen> {
  bool _isLoading = true;

  int _total = 0, _normal = 0, _ringan = 0, _sedang = 0, _berat = 0;
  List<Map<String, dynamic>> _dailyData = [];
  List<Map<String, dynamic>> _divisiData = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final summary = await DBHelper().getFatigueSummary();
    final daily = await DBHelper().getDailyCount(days: 14);
    final divisi = await DBHelper().getFatigueByDivisi();
    if (!mounted) return;
    setState(() {
      _normal = summary['Normal'] ?? 0;
      _ringan = summary['Fatigue Ringan'] ?? 0;
      _sedang = summary['Fatigue Sedang'] ?? 0;
      _berat = summary['Fatigue Berat'] ?? 0;
      _total = _normal + _ringan + _sedang + _berat;
      _dailyData = daily;
      _divisiData = divisi;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text('📊 Statistik', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0B0F19)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F2FE)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF00F2FE),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // ── KPI Cards ─────────────────────────────────────
                      Text('Ringkasan Keseluruhan', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 12),
                      _buildKpiRow(),
                      const SizedBox(height: 28),

                      // ── Grafik Batang Harian ───────────────────────────
                      Text('Tes per Hari — 14 Hari Terakhir', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        child: SizedBox(height: 200, child: _buildBarChart()),
                      ),
                      const SizedBox(height: 28),

                      // ── Pie Chart Distribusi Fatigue ───────────────────
                      Text('Distribusi Level Fatigue', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        child: SizedBox(height: 220, child: _total == 0 ? _emptyChart('Belum ada data') : _buildPieChart()),
                      ),
                      const SizedBox(height: 28),

                      // ── Grafik per Jabatan/Divisi ──────────────────────
                      if (_divisiData.isNotEmpty) ...[
                        Text('Distribusi Fatigue per Jabatan', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          child: _buildDivisiTable(),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildKpiRow() {
    final kpis = [
      ('Total', _total, const Color(0xFF00F2FE), Icons.analytics),
      ('Normal', _normal, const Color(0xFFFFFFFF), Icons.check_circle_outline),
      ('F. Ringan', _ringan, const Color(0xFF2ECC71), Icons.warning_amber_outlined),
      ('F. Sedang', _sedang, const Color(0xFFF1C40F), Icons.error_outline),
      ('F. Berat', _berat, const Color(0xFFE74C3C), Icons.dangerous_outlined),
    ];
    return LayoutBuilder(builder: (ctx, constr) {
      final int cols = constr.maxWidth > 500 ? 5 : 2;
      return Wrap(
        spacing: 8, runSpacing: 8,
        children: kpis.map((k) {
          final width = (constr.maxWidth - (cols - 1) * 8) / cols;
          return SizedBox(
            width: width,
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: k.$3.withValues(alpha: 0.3)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(k.$4, color: k.$3, size: 22),
                const SizedBox(height: 8),
                Text(k.$1, style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
                Text(k.$2.toString(), style: GoogleFonts.outfit(color: k.$3, fontSize: 28, fontWeight: FontWeight.bold)),
                if (_total > 0)
                  Text('${(k.$2 / _total * 100).toStringAsFixed(1)}%', style: GoogleFonts.inter(color: k.$3.withValues(alpha: 0.7), fontSize: 10)),
              ]),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildBarChart() {
    if (_dailyData.isEmpty) return _emptyChart('Belum ada data 14 hari terakhir');
    final maxY = _dailyData.map((e) => (e['count'] as int).toDouble()).fold(0.0, (a, b) => a > b ? a : b);
    final spots = _dailyData.asMap().entries.map((e) => BarChartGroupData(
      x: e.key,
      barRods: [BarChartRodData(toY: (e.value['count'] as int).toDouble(), color: const Color(0xFF00F2FE), width: 14, borderRadius: BorderRadius.circular(4))],
    )).toList();
    return BarChart(BarChartData(
      maxY: maxY + 1,
      barGroups: spots,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) {
          final idx = v.toInt();
          if (idx < 0 || idx >= _dailyData.length) return const SizedBox();
          final date = (_dailyData[idx]['date'] as String?) ?? '';
          return Padding(padding: const EdgeInsets.only(top: 4), child: Text(date.length >= 10 ? date.substring(5) : date, style: GoogleFonts.inter(color: Colors.white38, fontSize: 8)));
        })),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }

  Widget _buildPieChart() {
    final slices = [
      PieChartSectionData(value: _normal.toDouble(), color: const Color(0xFFFFFFFF), title: 'Normal\n$_normal', radius: 80, titleStyle: GoogleFonts.inter(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: _ringan.toDouble(), color: const Color(0xFF2ECC71), title: 'Ringan\n$_ringan', radius: 80, titleStyle: GoogleFonts.inter(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: _sedang.toDouble(), color: const Color(0xFFF1C40F), title: 'Sedang\n$_sedang', radius: 80, titleStyle: GoogleFonts.inter(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
      PieChartSectionData(value: _berat.toDouble(), color: const Color(0xFFE74C3C), title: 'Berat\n$_berat', radius: 80, titleStyle: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
    ].where((s) => s.value > 0).toList();
    return PieChart(PieChartData(sections: slices, centerSpaceRadius: 30, sectionsSpace: 2));
  }

  Widget _buildDivisiTable() {
    final grouped = <String, Map<String, int>>{};
    for (final r in _divisiData) {
      final div = r['divisi'] as String;
      final fl = r['fatigue_level'] as String? ?? '-';
      final cnt = r['count'] as int? ?? 0;
      grouped.putIfAbsent(div, () => {});
      grouped[div]![fl] = cnt;
    }
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1), 4: FlexColumnWidth(1)},
      children: [
        TableRow(children: ['Jabatan', 'Normal', 'Ringan', 'Sedang', 'Berat'].map((h) =>
          Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text(h, style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)))
        ).toList()),
        ...grouped.entries.map((e) => TableRow(children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4), child: Text(e.key, style: GoogleFonts.inter(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
           _tdNum(e.value['Normal'] ?? 0, const Color(0xFFFFFFFF)),
           _tdNum(e.value['Fatigue Ringan'] ?? 0, const Color(0xFF2ECC71)),
           _tdNum(e.value['Fatigue Sedang'] ?? 0, const Color(0xFFF1C40F)),
           _tdNum(e.value['Fatigue Berat'] ?? 0, const Color(0xFFE74C3C)),
        ])),
      ],
    );
  }

  Widget _tdNum(int val, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: Text(val.toString(), style: GoogleFonts.outfit(color: val > 0 ? color : Colors.white24, fontSize: 13, fontWeight: FontWeight.bold)),
  );

  Widget _emptyChart(String msg) => Center(child: Text(msg, style: GoogleFonts.inter(color: Colors.white30)));
}
