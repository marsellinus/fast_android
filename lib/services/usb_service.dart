import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';
import 'settings_service.dart';

class UsbService extends ChangeNotifier {
  UsbPort? _port;
  UsbDevice? _device;
  Transaction<String>? _transaction;
  StreamSubscription<String>? _subscription;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String _statusMessage = "Belum Terhubung";
  String get statusMessage => _statusMessage;

  UsbDevice? get connectedDevice => _device;

  final StreamController<String> _dataStreamController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  Future<List<UsbDevice>> getAvailableDevices() async {
    return await UsbSerial.listDevices();
  }

  Future<bool> connect(UsbDevice device) async {
    disconnect();
    
    _port = await device.create();
    if (await (_port!.open()) != true) {
      _statusMessage = "Gagal membuka port USB";
      notifyListeners();
      return false;
    }
    
    _device = device;
    await _port!.setDTR(true);
    await _port!.setRTS(true);
    
    // Setting Baud rate dari settings
    await _port!.setPortParameters(
        SettingsService().baudRate, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(
        _port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10])); // CR LF

    _subscription = _transaction!.stream.listen((String line) {
      _dataStreamController.add(line.trim());
    });

    _isConnected = true;
    _statusMessage = "Terhubung ke ${device.productName}";
    notifyListeners();
    return true;
  }

  void disconnect() {
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }
    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }
    if (_port != null) {
      _port!.close();
      _port = null;
    }
    
    _device = null;
    _isConnected = false;
    _statusMessage = "Terputus";
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _dataStreamController.close();
    super.dispose();
  }
}
