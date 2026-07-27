# Panduan Menjalankan RATIG Android (USB Serial)

Folder ini berisi kode sumber awal untuk membuat aplikasi Android RATIG yang dapat membaca data dari ESP32 menggunakan kabel **USB OTG**.

## Prasyarat
Karena saat dicoba `flutter create` pada command line gagal (kemungkinan karena *lock* sistem atau path environment belum sempurna disetel pada PowerShell eksternal), Anda bisa melanjutkan menggunakan Terminal di VS Code atau Android Studio Anda.

Pastikan:
1. **Flutter SDK** sudah diunduh dan dipasang di Path Anda (misal `D:\flutter\flutter\bin`).
2. **Android Studio** terpasang beserta Android SDK-nya.
3. Anda memiliki kabel **USB OTG** dan kabel data untuk menghubungkan HP ke PC (untuk *debugging*/menjalankan aplikasi).

## Cara Menjalankan (Run) Aplikasi
Buka terminal (Command Prompt, PowerShell, atau Terminal di VS Code) lalu arahkan ke folder ini:

```bash
cd "D:\magang\RATIG ( reaction timer fatigue)\RATIG_Android"
```

1. **Unduh Dependensi** (Ini akan mengambil library `usb_serial`):
   ```bash
   flutter pub get
   ```

2. **Sambungkan HP Android Anda ke PC** menggunakan kabel data biasa.
   - Pastikan **Developer Options (Opsi Pengembang)** dan **USB Debugging** di HP Anda sudah **Aktif**.
   
3. **Jalankan Aplikasi:**
   ```bash
   flutter run
   ```
   *Flutter akan meng-compile kode menjadi `.apk` dan otomatis menginstalnya ke HP Anda.*

## Cara Menggunakan di Lapangan
Setelah aplikasi terbuka di HP Anda:
1. Cabut kabel dari PC.
2. Colokkan **Kabel USB OTG** ke HP Anda.
3. Colokkan ujung satunya ke alat RATIG (ESP32).
4. Layar HP akan memunculkan pop-up *"Allow this app to access the USB device?"*, klik **OK**.
5. Di aplikasi, klik tombol **Connect**. Anda akan melihat data waktu reaksi masuk di layar!

---
*Catatan:* Baud rate pada kode `main.dart` telah diatur pada `115200`. Jika ESP32 Anda menggunakan baud rate lain (misalnya 9600), Anda dapat mengubah angkanya pada baris `await _port!.setPortParameters(115200, ...)` di dalam `main.dart`.
