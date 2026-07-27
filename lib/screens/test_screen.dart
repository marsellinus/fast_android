import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:usb_serial/usb_serial.dart';
import '../services/settings_service.dart';
import 'result_screen.dart';

class TestScreen extends StatefulWidget {
  final Map<String, dynamic> formData;

  const TestScreen({super.key, required this.formData});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _allTrials = [];

  List<double> get _realTrials => _allTrials.where((t) => t['trial'] > 2).map((t) => t['rt'] as double).toList();

  bool _isConnected = false;
  bool _isFinished  = false;
  String _statusMsg = 'Menghubungkan ke ESP32...';

  UsbPort? _port;
  StreamSubscription<String>? _subscription;
  String _buffer = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _connectUsb();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _subscription?.cancel();
    _port?.close();
    super.dispose();
  }

  Future<void> _connectUsb() async {
    try {
      final selectedDevice = widget.formData['usbDevice'] as UsbDevice?;
      
      if (selectedDevice != null) {
        setState(() => _statusMsg = 'Menghubungkan ke ${selectedDevice.productName ?? selectedDevice.deviceName}...');
        final port = await selectedDevice.create();
        if (port != null) {
          final opened = await port.open();
          if (opened) {
            _port = port;
          }
        }
      }

      // Fallback jika tidak ada pilihan usbDevice atau koneksi awal gagal
      if (_port == null) {
        final devices = await UsbSerial.listDevices();
        if (devices.isEmpty) {
          setState(() => _statusMsg = '⚠ Tidak ada perangkat USB terdeteksi.\nPastikan kabel OTG sudah terpasang ke ESP32.');
          return;
        }

        bool connectionSuccess = false;
        for (var device in devices) {
          final port = await device.create();
          if (port != null) {
            final opened = await port.open();
            if (opened) {
              _port = port;
              connectionSuccess = true;
              break;
            } else {
              port.close();
            }
          }
        }

        if (!connectionSuccess || _port == null) {
          setState(() => _statusMsg = '❌ Gagal membuka port USB ke semua perangkat yang terdeteksi.');
          return;
        }
      }

      await _port!.setDTR(true);
      await _port!.setRTS(true);
      await _port!.setPortParameters(SettingsService().baudRate, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

      setState(() {
        _isConnected = true;
        _statusMsg   = 'Mendengarkan Sinyal RATIG...';
      });

      _subscription = _port!.inputStream!.map((data) => String.fromCharCodes(data)).listen(_onRawData);
    } catch (e) {
      setState(() => _statusMsg = '❌ Error koneksi: $e');
    }
  }

  void _onRawData(String raw) {
    _buffer += raw;
    while (_buffer.contains('\n')) {
      final idx  = _buffer.indexOf('\n');
      final line = _buffer.substring(0, idx).trim();
      _buffer    = _buffer.substring(idx + 1);
      if (line.isNotEmpty) _processLine(line);
    }
  }

  void _processLine(String line) {
    if (_isFinished) return;
    final parts = line.split(',');

    if (line.contains('FINAL')) {
      _onFinal();
      return;
    }

    if (!line.contains('TIME') && !line.contains('DATA')) {
      _tryParseFallback(line);
      return;
    }

    try {
      int timeIdx = parts.indexWhere((p) => p.trim() == 'TIME');
      if (timeIdx != -1) {
        // Coba parsing format dengan Mode (misal: DATA,,,,TIME,Light,1,320,OK,pengenalan)
        // parts[timeIdx]   = "TIME"
        // parts[timeIdx+1] = "Light" (Mode)
        // parts[timeIdx+2] = "1" (Trial)
        // parts[timeIdx+3] = "320" (Reaction Time)
        if (timeIdx + 3 < parts.length) {
          final trialIdx = int.tryParse(parts[timeIdx + 2].trim());
          final rt       = double.tryParse(parts[timeIdx + 3].trim());
          if (trialIdx != null && trialIdx > 0 && rt != null && rt > 0) {
            setState(() {
              _allTrials.add({'trial': trialIdx, 'rt': rt});
              final tag = trialIdx <= 2 ? 'PERCOBAAN' : 'UJI ASLI';
              _statusMsg = 'Trial $trialIdx/8 — ${rt.toStringAsFixed(1)} ms ($tag)';
            });
            if (trialIdx >= 8) {
              _onFinal();
            }
            return;
          }
        }

        // Fallback: format tanpa Mode (misal: DATA,,,,TIME,1,320,OK,pengenalan)
        // parts[timeIdx]   = "TIME"
        // parts[timeIdx+1] = "1" (Trial)
        // parts[timeIdx+2] = "320" (Reaction Time)
        if (timeIdx + 2 < parts.length) {
          final trialIdx = int.tryParse(parts[timeIdx + 1].trim());
          final rt       = double.tryParse(parts[timeIdx + 2].trim());
          if (trialIdx != null && trialIdx > 0 && rt != null && rt > 0) {
            setState(() {
              _allTrials.add({'trial': trialIdx, 'rt': rt});
              final tag = trialIdx <= 2 ? 'PERCOBAAN' : 'UJI ASLI';
              _statusMsg = 'Trial $trialIdx/8 — ${rt.toStringAsFixed(1)} ms ($tag)';
            });
            if (trialIdx >= 8) {
              _onFinal();
            }
            return;
          }
        }
      }
    } catch (_) {}
  }

  void _tryParseFallback(String line) {
    final match = RegExp(r'\b(\d{2,4})\b').firstMatch(line);
    if (match != null) {
      final val = double.tryParse(match.group(1)!) ?? 0;
      if (val >= 10 && val <= 2000) {
        final trialIdx = _allTrials.length + 1;
        setState(() {
          _allTrials.add({'trial': trialIdx, 'rt': val});
          final tag = trialIdx <= 2 ? 'PERCOBAAN' : 'UJI ASLI';
          _statusMsg = 'Trial $trialIdx/8 — ${val.toStringAsFixed(1)} ms ($tag)';
        });
        if (_allTrials.length >= 8) _onFinal();
      }
    }
  }

  void _onFinal() {
    if (_isFinished) return;
    setState(() {
      _isFinished = true;
      _statusMsg  = 'Tes Selesai! Mengkalkulasi hasil...';
    });
    List<double> t = _realTrials;
    while (t.length < 6) {
      t.add(0.0);
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(formData: widget.formData, reactionTimes: t)));
    });
  }

  void _goToResultManual() {
    List<double> t = _realTrials;
    while (t.length < 6) {
      t.add(0.0);
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(formData: widget.formData, reactionTimes: t)));
  }

  @override
  Widget build(BuildContext context) {
    final nama = widget.formData['nama'] ?? 'Pekerja';
    final realCount = _realTrials.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            radius: 1.5,
            center: Alignment.topCenter,
          )
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uji Waktu Reaksi', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(nama, style: GoogleFonts.inter(color: const Color(0xFF00F2FE), fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulse Status
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isFinished ? const Color(0xFF00E676).withValues(alpha: 0.1) : const Color(0xFF00F2FE).withValues(alpha: 0.05),
                            boxShadow: [
                              BoxShadow(
                                color: (_isFinished ? const Color(0xFF00E676) : const Color(0xFF00F2FE)).withValues(alpha: 0.2),
                                blurRadius: 40,
                                spreadRadius: 10,
                              )
                            ],
                            border: Border.all(
                              color: (_isFinished ? const Color(0xFF00E676) : const Color(0xFF00F2FE)).withValues(alpha: 0.5),
                              width: 2,
                            )
                          ),
                          child: Icon(
                            _isFinished ? Icons.check_circle_outline : (_isConnected ? Icons.sensors : Icons.usb_off),
                            size: 80,
                            color: _isFinished ? const Color(0xFF00E676) : (_isConnected ? const Color(0xFF00F2FE) : Colors.redAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(_statusMsg, style: GoogleFonts.inter(fontSize: 16, color: Colors.white70), textAlign: TextAlign.center),
                      
                      const SizedBox(height: 48),

                      // Dots Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(8, (i) {
                          final filled = i < _allTrials.length;
                          final isPercobaan = i < 2;
                          Color dotColor = isPercobaan ? const Color(0xFFFFEA00) : const Color(0xFF00F2FE);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: filled ? 16 : 12,
                            height: filled ? 16 : 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? dotColor : Colors.white.withValues(alpha: 0.1),
                              boxShadow: filled ? [
                                BoxShadow(color: dotColor.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)
                              ] : null,
                            ),
                          );
                        }),
                      ),
                      
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legend(const Color(0xFFFFEA00), 'Percobaan (1-2)'),
                          const SizedBox(width: 24),
                          _legend(const Color(0xFF00F2FE), 'Uji Asli (3-8)'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    if (!_isConnected && _allTrials.isEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _connectUsb,
                          icon: const Icon(Icons.usb, size: 20),
                          label: const Text('Coba Sambungkan Ulang'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00F2FE),
                            side: const BorderSide(color: Color(0xFF00F2FE)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                        ),
                      ),
                    if (!_isFinished && _allTrials.isNotEmpty)
                      TextButton(
                        onPressed: _goToResultManual,
                        child: Text(
                          'Skip & Lanjut dengan $realCount data asli',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13, decoration: TextDecoration.underline),
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
