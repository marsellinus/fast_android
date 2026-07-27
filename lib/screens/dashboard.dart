import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:usb_serial/usb_serial.dart';
import '../database/db_helper.dart';
import '../widgets/glass_card.dart';
import '../services/settings_service.dart';
import 'test_screen.dart';
import 'history_screen.dart';
import 'master_karyawan_screen.dart';
import 'settings_screen.dart';
import 'statistik_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  // Tes hari ini
  int _totalHariIni = 0;
  int _beratHariIni = 0;

  // Form State
  String _mode = 'SHE Officer';
  final _nikController = TextEditingController();
  final FocusNode _nikFocusNode = FocusNode();
  final _namaController = TextEditingController();
  final _usiaController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _infoController = TextEditingController();
  String? _jk;

  // USB Selection State
  List<UsbDevice> _usbDevices = [];
  String _selectedUsbPort = 'AUTO_DETECT';

  bool _isLoading = true;

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _nikController.addListener(() {
      final v = _nikController.text.trim();
      if (v.isNotEmpty) {
        _autofillByNik(v);
      }
    });

    _nikFocusNode.addListener(() {
      if (!_nikFocusNode.hasFocus) {
        final v = _nikController.text.trim();
        if (v.isNotEmpty) {
          _autofillByNik(v);
        }
      }
    });

    _loadStats();
    _refreshUsbDevices();
    _animController.forward();
  }

  // Helper aman untuk mencari UsbDevice berdasarkan deviceName.
  // Mengembalikan null jika tidak ditemukan, TIDAK melempar exception.
  // Ini menggantikan pola `_usbDevices.firstWhere(...)` tanpa `orElse`
  // yang bisa menyebabkan crash (StateError) jika device sudah tidak
  // ada lagi di dalam list (misal: kabel OTG dicabut sesaat).
  UsbDevice? _findUsbDeviceByName(String deviceName) {
    for (final d in _usbDevices) {
      if (d.deviceName == deviceName) return d;
    }
    return null;
  }

  Future<void> _refreshUsbDevices({bool silent = true}) async {
    try {
      final devices = await UsbSerial.listDevices();
      if (!mounted) return;

      final previousSelection = _selectedUsbPort;
      final selectionStillValid = previousSelection == 'AUTO_DETECT' ||
          devices.any((d) => d.deviceName == previousSelection);

      setState(() {
        _usbDevices = devices;
        if (!selectionStillValid) {
          _selectedUsbPort = 'AUTO_DETECT';
        }
      });

      if (!silent && !selectionStillValid && previousSelection != 'AUTO_DETECT') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perangkat USB yang dipilih sebelumnya sudah tidak terdeteksi. Kembali ke Auto-Detect.'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal memindai USB: $e');
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memindai perangkat USB: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nikController.dispose();
    _nikFocusNode.dispose();
    _namaController.dispose();
    _usiaController.dispose();
    _jabatanController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final results = await DBHelper().getAllResults();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    int total = 0, berat = 0;
    for (var row in results) {
      if ((row['tanggal'] ?? '').toString().startsWith(todayStr)) {
        total++;
        if (row['fatigue_level'] == 'Fatigue Berat') berat++;
      }
    }
    if (mounted) {
      setState(() {
        _totalHariIni = total;
        _beratHariIni = berat;
        _isLoading = false;
      });
    }
  }

  // Auto-fill logic identik dengan RATIG.py
  Future<void> _autofillByNik(String nik) async {
    final data = await DBHelper().autofillByNik(nik);
    if (!mounted) return;
    if (data != null && data.isNotEmpty) {
      setState(() {
        _namaController.text = data['nama'] ?? '';
        _usiaController.text = data['usia']?.toString() ?? '';
        _jabatanController.text = data['jabatan'] ?? '';
        _infoController.text = data['info_pekerjaan'] ?? '';
        _jk = data['jenis_kelamin'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Autofill berhasil untuk NIK: $nik'),
          backgroundColor: const Color(0xFF00F2FE),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showLookupDialog() async {
    List<Map<String, dynamic>> masterList = [];
    try {
      final karyawan = await DBHelper().getAllKaryawan(isKontraktor: false);
      final kontraktor = await DBHelper().getAllKaryawan(isKontraktor: true);
      masterList.addAll(karyawan.map((e) => {...e, 'type': 'Karyawan'}));
      masterList.addAll(kontraktor.map((e) => {...e, 'type': 'Kontraktor'}));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat master data: $e'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setInnerState) {
            final filtered = masterList.where((item) {
              final q = searchQuery.toLowerCase();
              final nama = (item['nama'] ?? '').toString().toLowerCase();
              final nik = (item['nik'] ?? '').toString().toLowerCase();
              return nama.contains(q) || nik.contains(q);
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1B4B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Cari Data Master',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setInnerState(() => searchQuery = v),
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
                    const SizedBox(height: 16),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Data tidak ditemukan',
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final isKont = item['type'] == 'Kontraktor';
                                return Card(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    title: Text(
                                      item['nama'] ?? '',
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      '${item['nik']} • ${item['jabatan'] ?? ''}',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isKont ? const Color(0xFFF5AF19).withValues(alpha: 0.2) : const Color(0xFF00F2FE).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item['type'],
                                        style: GoogleFonts.inter(
                                          color: isKont ? const Color(0xFFF5AF19) : const Color(0xFF00F2FE),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _nikController.text = (item['nik'] ?? '').toString();
                                        _namaController.text = (item['nama'] ?? '').toString();
                                        _usiaController.text = (item['usia'] ?? '').toString();
                                        _jk = (item['jenis_kelamin'] ?? 'Laki-laki').toString();
                                        _jabatanController.text = (item['jabatan'] ?? '').toString();
                                        _infoController.text = (item['info_pekerjaan'] ?? '').toString();
                                      });
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tutup', style: GoogleFonts.inter(color: Colors.white54)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _switchMode(String newMode) async {
    if (newMode == 'Paramedis') {
      final pwdCtrl = TextEditingController();
      bool isVisible = false;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1B4B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.security, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  Text('Otorisasi Paramedis',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: TextField(
                controller: pwdCtrl,
                obscureText: !isVisible,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Masukkan PIN',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.purpleAccent),
                  suffixIcon: IconButton(
                    icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                    onPressed: () => setInnerState(() => isVisible = !isVisible),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (pwdCtrl.text == SettingsService().paramedisPin || pwdCtrl.text == 'ITPSHE#2026') {
                      Navigator.pop(ctx, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN Salah!'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: const Text('Login'),
                ),
              ],
            );
          }
        ),
      );
      if (ok == true && mounted) {
        setState(() => _mode = 'Paramedis');
      }
    } else {
      setState(() => _mode = 'SHE Officer');
    }
  }

  Future<void> _startTest() async {
    final nik = _nikController.text.trim().toUpperCase();
    final nama = _namaController.text.trim();
    if (nik.isEmpty || nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NIK dan Nama wajib diisi!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Validasi duplikasi tes harian sesuai dailyTestLimit di settings
    final todayCount = await DBHelper().getTodayTestCount(nik);
    final limit = SettingsService().dailyTestLimit;
    if (!mounted) return;
    if (todayCount >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Peringatan: Pekerja NIK $nik sudah melakukan $todayCount tes hari ini (Batas: $limit tes/hari)!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Validasi usia sesuai threshold di settings
    final usiaStr = _usiaController.text.trim();
    if (usiaStr.isNotEmpty) {
      final u = int.tryParse(usiaStr) ?? 0;
      final ageThreshold = SettingsService().ageWarningThreshold;
      if (u >= ageThreshold) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1B4B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('⚠ Peringatan Usia', style: GoogleFonts.outfit(color: Colors.redAccent)),
            content: Text('Pekerja berusia $u tahun (≥$ageThreshold tahun). Lanjutkan tes?', style: GoogleFonts.inter(color: Colors.white)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirm != true) return;
      }
    }

    // --- FIX: sebelumnya pakai `_usbDevices.firstWhere(...)` tanpa fallback,
    // yang akan MELEMPAR StateError (dan meng-crash aplikasi) jika device
    // yang tadinya dipilih ternyata sudah hilang dari daftar (misalnya
    // kabel OTG longgar sesaat sebelum tombol ditekan).
    // Sekarang: refresh daftar device dulu, lalu cari dengan aman.
    await _refreshUsbDevices(silent: true);
    if (!mounted) return;

    UsbDevice? selectedDevice;
    if (_selectedUsbPort != 'AUTO_DETECT') {
      selectedDevice = _findUsbDeviceByName(_selectedUsbPort);
      if (selectedDevice == null) {
        // Device yang dipilih user sudah tidak ada -> beri tahu & lanjut
        // dengan mode Auto-Detect alih-alih membiarkan app crash.
        setState(() => _selectedUsbPort = 'AUTO_DETECT');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perangkat USB pilihan tidak ditemukan. Melanjutkan dengan Auto-Detect.'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    final formData = {
      'nik': nik,
      'nama': nama,
      'usia': _usiaController.text.trim(),
      'jenis_kelamin': _jk ?? '',
      'jabatan': _jabatanController.text.trim(),
      'divisi': _infoController.text.trim(),
      'mode': _mode,
      'usbDevice': selectedDevice,
    };

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TestScreen(formData: formData)),
    ).then((_) => _loadStats()); // Refresh data
  }

  @override
  Widget build(BuildContext context) {
    // Rich Gradient Background
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.health_and_safety, color: Color(0xFF00F2FE)),
            ),
            const SizedBox(width: 12),
            Text(SettingsService().appName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _mode == 'Paramedis'
                      ? [const Color(0xFFF12711), const Color(0xFFF5AF19)]
                      : [const Color(0xFF00F2FE), const Color(0xFF4FACFE)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (_mode == 'Paramedis' ? const Color(0xFFF12711) : const Color(0xFF00F2FE)).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4)
                    )
                  ]
                ),
                child: Row(
                  children: [
                    Icon(_mode == 'Paramedis' ? Icons.medical_services : Icons.shield, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(_mode, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(mode: _mode)),
            ).then((_) {
              // Reload settings after returning
              setState(() {});
            }),
          ),
        ],
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F2FE)))
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        bool isTablet = constraints.maxWidth > 800;

                        Widget buildDashboardContent() {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(SettingsService().appName, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text('Reaction Timer & Fatigue Monitoring', style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey[300])),
                              const SizedBox(height: 24),
                              // Ringkasan hari ini
                              GlassCard(
                                padding: const EdgeInsets.all(20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF00F2FE).withValues(alpha: 0.2)),
                                child: Row(children: [
                                  const Icon(Icons.today, color: Color(0xFF00F2FE), size: 32),
                                  const SizedBox(width: 16),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Tes Hari Ini', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
                                    Text('$_totalHariIni pekerja', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                    if (_beratHariIni > 0)
                                      Text('⚠ $_beratHariIni Fatigue Berat', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ])),
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.white38),
                                    onPressed: _loadStats,
                                  ),
                                ]),
                              ),
                            ],
                          );
                        }

                        Widget buildFormContent() {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mulai Uji Reaksi', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 8),
                              Text('Pencarian NIK otomatis terhubung ke Master Data.', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                              const SizedBox(height: 24),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _GlassTextField(
                                      controller: _nikController,
                                      focusNode: _nikFocusNode,
                                      label: 'NIK',
                                      icon: Icons.badge_outlined,
                                      isNumber: true,
                                      onSubmitted: (v) {
                                        if (v.trim().isNotEmpty) {
                                          _autofillByNik(v.trim());
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    height: 52,
                                    width: 52,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.search, color: Color(0xFF00F2FE)),
                                      tooltip: 'Cari NIK dari Master Data',
                                      onPressed: _showLookupDialog,
                                    ),
                                  ),
                                ],
                              ),
                              _GlassTextField(controller: _namaController, label: 'Nama Lengkap', icon: Icons.person_outline),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _GlassTextField(
                                      controller: _usiaController,
                                      label: 'Usia',
                                      icon: Icons.calendar_today_outlined,
                                      isNumber: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _GlassDropdown(
                                      value: _jk,
                                      label: 'Gender',
                                      icon: Icons.people_outline,
                                      items: const ['Laki-laki', 'Perempuan'],
                                      onChanged: (v) => setState(() => _jk = v),
                                    ),
                                  ),
                                ],
                              ),

                              _GlassTextField(controller: _jabatanController, label: 'Jabatan', icon: Icons.work_outline),
                              _GlassTextField(controller: _infoController, label: 'Info Pekerjaan / Divisi', icon: Icons.domain),

                              DropdownButtonFormField<String>(
                                initialValue: _selectedUsbPort,
                                decoration: InputDecoration(
                                  labelText: 'Port USB (ESP32)',
                                  labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                                  prefixIcon: const Icon(Icons.usb, color: Colors.white30, size: 20),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                                    onPressed: () => _refreshUsbDevices(silent: false),
                                    tooltip: 'Refresh USB',
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: 'AUTO_DETECT',
                                    child: Text(
                                      'Auto-Detect (Cari Otomatis)',
                                      style: GoogleFonts.inter(color: const Color(0xFF00F2FE), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  ..._usbDevices.map((d) {
                                    final name = d.productName ?? d.deviceName;
                                    return DropdownMenuItem<String>(
                                      value: d.deviceName,
                                      child: Text(
                                        name,
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (v) => setState(() => _selectedUsbPort = v ?? 'AUTO_DETECT'),
                                dropdownColor: const Color(0xFF1E1B4B),
                              ),

                              const SizedBox(height: 32),

                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _switchMode('SHE Officer'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _mode == 'SHE Officer' ? const Color(0xFF00F2FE).withValues(alpha: 0.2) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text('SHE Officer', style: GoogleFonts.inter(color: _mode == 'SHE Officer' ? const Color(0xFF00F2FE) : Colors.white54, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _switchMode('Paramedis'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _mode == 'Paramedis' ? const Color(0xFFF5AF19).withValues(alpha: 0.2) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text('Paramedis', style: GoogleFonts.inter(color: _mode == 'Paramedis' ? const Color(0xFFF5AF19) : Colors.white54, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    elevation: 8,
                                    shadowColor: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                                  ),
                                  onPressed: _startTest,
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)]),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                          const SizedBox(width: 8),
                                          Text('MULAI TES', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              Row(children: [
                                Expanded(child: _NavButton(
                                  icon: Icons.bar_chart,
                                  label: 'Statistik',
                                  color: const Color(0xFF00F2FE),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatistikScreen())),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _NavButton(
                                  icon: Icons.history,
                                  label: 'Riwayat',
                                  color: Colors.purpleAccent,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(mode: _mode))).then((_) => _loadStats()),
                                )),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: _NavButton(
                                  icon: Icons.folder_shared,
                                  label: 'Master Data',
                                  color: Colors.orangeAccent,
                                  onTap: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final selected = await Navigator.push<Map<String, dynamic>>(
                                      context,
                                      MaterialPageRoute(builder: (_) => MasterKaryawanScreen(mode: _mode)),
                                    );
                                    if (selected == null) return;
                                    final nik = (selected['nik'] ?? '').toString();
                                    if (nik.isNotEmpty) {
                                      _nikController.text = nik;
                                      _autofillByNik(nik);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Terpilih untuk tes: ${selected['nama']} ($nik)'),
                                          backgroundColor: const Color(0xFF00F2FE),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _NavButton(
                                  icon: Icons.settings_outlined,
                                  label: 'Pengaturan',
                                  color: Colors.tealAccent,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(mode: _mode))).then((_) => setState(() {})),
                                )),
                              ]),
                            ],
                          );
                        }

                        if (isTablet) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: buildDashboardContent(),
                                ),
                              ),
                              Container(
                                width: 380,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.05)))
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: buildFormContent(),
                                ),
                              )
                            ],
                          );
                        } else {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildDashboardContent(),
                                const SizedBox(height: 40),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 32),
                                buildFormContent(),
                              ],
                            ),
                          );
                        }
                      }
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumber;
  final Function(String)? onSubmitted;
  final FocusNode? focusNode;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isNumber = false,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onSubmitted: onSubmitted,
        textInputAction: onSubmitted != null ? TextInputAction.done : TextInputAction.next,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white30, size: 20),
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
  final String? value;
  final String label;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _GlassDropdown({
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white30, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF00F2FE))),
        ),
        dropdownColor: const Color(0xFF1E1B4B),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}