import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Maker',
      themeMode: ThemeMode.system,
      darkTheme: ThemeData.dark(),
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const QRGeneratorPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QRGeneratorPage extends StatefulWidget {
  const QRGeneratorPage({super.key});

  @override
  State<QRGeneratorPage> createState() => _QRGeneratorPageState();
}

class _QRGeneratorPageState extends State<QRGeneratorPage> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String qrText = '';

  // Fungsi untuk mendeteksi versi Android & mengatur permission
  Future<Permission> _getCorrectPermission() async {
    if (!Platform.isAndroid) return Permission.photos;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    return sdkInt >= 33 ? Permission.photos : Permission.storage;
  }

  // Fungsi simpan QR ke galeri
  Future<void> _saveQrToGallery() async {
    final permission = await _getCorrectPermission();
    var status = await permission.status;

    if (status.isDenied || status.isPermanentlyDenied) {
      status = await permission.request();

      if (!status.isGranted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Izin Diperlukan'),
            content: const Text(
              'Aplikasi membutuhkan izin untuk menyimpan gambar ke galeri.\n\n'
              'Silakan izinkan akses penyimpanan atau foto melalui pengaturan aplikasi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
        );
        return;
      }
    }

    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      final success = await GallerySaver.saveImage(file.path);

      if (success != null && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR Code berhasil disimpan ke galeri!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw 'Gagal menyimpan';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _generateQRCode() {
    setState(() {
      qrText = _controller.text;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Maker'),
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Masukkan teks',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateQRCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_rounded),
                  SizedBox(width: 8),
                  Text('Buat QR Code'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (qrText.isNotEmpty)
              Column(
                children: [
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          color: Colors.white,
                          child: QrImageView(
                            data: qrText,
                            version: QrVersions.auto,
                            size: 220.0,
                            backgroundColor: Colors.white,
                            gapless: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveQrToGallery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.save_alt),
                        SizedBox(width: 8),
                        Text('Simpan ke Galeri'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
