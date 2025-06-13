import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Generator',
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

  Future<void> _saveQrToGallery() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin akses penyimpanan ditolak')),
      );
      return;
    }

    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = Directory('/storage/emulated/0/DCIM/QRFlutter');
      if (!(await directory.exists())) {
        await directory.create(recursive: true);
      }

      final filePath = '${directory.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR Code berhasil disimpan ke galeri!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
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
        title: const Text('QR Code Generator'),
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
            ElevatedButton.icon(
              onPressed: _generateQRCode,
              label: const Text('Generate QR Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saveQrToGallery,
                    label: const Text('Simpan ke Galeri'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
