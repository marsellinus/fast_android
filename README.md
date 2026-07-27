# RATIG Android (Reaction Timer Fatigue)

Aplikasi Flutter berbasis Android untuk mengukur dan menguji tingkat kelelahan (*fatigue*) kerja berdasarkan waktu reaksi (*reaction time*) yang terhubung secara langsung ke perangkat keras (hardware) melalui **USB Serial**.

---

## 🚀 Fitur Utama

- 🔌 **Konektivitas USB Serial**: Menghubungkan aplikasi Android secara langsung ke perangkat hardware Reaction Timer (ESP32 / Microcontroller).
- ⏱️ **Pengujian Waktu Reaksi**: Pengujian yang presisi untuk mendeteksi tingkat kelelahan fisik dan mental pengguna/karyawan.
- 📊 **Dashboard & Statistik Visual**: Visualisasi tren waktu reaksi dan grafik kelelahan berbasis `fl_chart`.
- 👥 **Master Data Karyawan**: Pengelolaan data karyawan beserta pencatatan riwayat medis/kesehatan.
- 📜 **Riwayat & Laporan**: Menyimpan seluruh riwayat pengujian secara lokal berbasis SQLite (`sqflite`).
- 📁 **Ekspor Data (Excel & PDF)**: Memungkinkan ekspor hasil uji ke format Excel (`.xlsx`) dan dokumen PDF (`.pdf`), serta fitur perbagian laporan.

---

## 🛠️ Teknologi & Paket yang Digunakan

- **Framework**: [Flutter](https://flutter.dev/) (Dart SDK >= 3.0.0)
- **Koneksi Hardware**: `usb_serial`
- **Database Lokal**: `sqflite`, `path_provider`, `path`
- **Grafik & UI**: `fl_chart`, `google_fonts`, `glassmorphism (glass_card)`
- **Ekspor & Share**: `excel`, `pdf`, `file_picker`, `share_plus`

---

## 📂 Struktur Direktori Utama (`lib/`)

```text
lib/
├── database/
│   └── db_helper.dart            # Pengelolaan SQLite Database (Karyawan, Medis, Hasil Tes)
├── screens/
│   ├── dashboard.dart            # Tampilan Dashboard Utama & Ringkasan Data
│   ├── test_screen.dart          # Layar Pengujian Waktu Reaksi Real-time
│   ├── result_screen.dart        # Hasil Pengujian & Analisis Kelelahan
│   ├── master_karyawan_screen.dart# Manajemen Data Karyawan
│   ├── medis_screen.dart         # Pencatatan Pemeriksaan Medis Karyawan
│   ├── history_screen.dart       # Riwayat Pengujian & Filter Data
│   ├── statistik_screen.dart     # Analisis Grafik & Statistik
│   └── settings_screen.dart      # Pengaturan Aplikasi & Baud Rate USB
├── services/
│   ├── usb_service.dart          # Service Komunikasi USB Serial
│   └── settings_service.dart     # Service Pengaturan Aplikasi
└── widgets/
    └── glass_card.dart           # Komponen UI Kustom Glassmorphism
```

---

## ⚙️ Persiapan Pengembangan & Kompilasi (Build)

### 1. Prasyarat
- Flutter SDK (v3.0.0 ke atas)
- Android Studio & Android SDK (API Level 21+)

### 2. Memasang Dependensi
Buka terminal di direktori proyek dan jalankan:
```bash
flutter pub get
```

### 3. Menjalankan Aplikasi (Debug)
Pastikan perangkat Android atau emulator sudah terhubung, lalu jalankan:
```bash
flutter run
```

### 4. Membuat File APK (Release)
Untuk mengompilasi APK siap pakai:
```bash
flutter build apk --release
```
File APK hasil build akan berada di direktori `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📝 Lisensi & Hak Cipta
Aplikasi ini dikembangkan untuk kebutuhan pengukuran dan pengujian tingkat kelelahan kerja (*Reaction Timer Fatigue*) RATIG.
