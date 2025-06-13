import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

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

  // Customization
  Color qrForegroundColor = Colors.black;
  Color qrBackgroundColor = Colors.white;
  bool includeLogo = false;
  File? _logoFile;

  // Fungsi untuk deteksi versi Android & permission
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

  // Fungsi share
  Future<void> _shareQrCode() async {
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
          '${tempDir.path}/qr_share_${DateTime.now().millisecondsSinceEpoch}.png';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'QR Code saya!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal membagikan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fungsi untuk generate QR
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

  // Pilih logo dari galeri
  Future<void> _pickLogoFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _logoFile = File(picked.path);
        includeLogo = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Maker'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Masukkan Teks QR Code',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.text_fields),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generateQRCode,
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Buat QR Code'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (qrText.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Text("Warna QR: "),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              final color = await showDialog<Color>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Pilih Warna QR'),
                                  content: BlockPicker(
                                    pickerColor: qrForegroundColor,
                                    onColorChanged: (color) {
                                      Navigator.of(context).pop(color);
                                    },
                                  ),
                                ),
                              );
                              if (color != null) {
                                setState(() => qrForegroundColor = color);
                              }
                            },
                            child: CircleAvatar(
                              backgroundColor: qrForegroundColor,
                              radius: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                      Row(
                        children: [
                          const Text("Latar QR: "),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () async {
                              final color = await showDialog<Color>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Pilih Warna Latar'),
                                  content: BlockPicker(
                                    pickerColor: qrBackgroundColor,
                                    onColorChanged: (color) {
                                      Navigator.of(context).pop(color);
                                    },
                                  ),
                                ),
                              );
                              if (color != null) {
                                setState(() => qrBackgroundColor = color);
                              }
                            },
                            child: CircleAvatar(
                              backgroundColor: qrBackgroundColor,
                              radius: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Tambahkan Logo dari Galeri'),
                    value: includeLogo,
                    onChanged: (val) {
                      if (val) {
                        _pickLogoFromGallery();
                      } else {
                        setState(() {
                          includeLogo = false;
                          _logoFile = null;
                        });
                      }
                    },
                  ),
                  const Divider(height: 32),
                  Center(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: RepaintBoundary(
                          key: _qrKey,
                          child: QrImageView(
                            data: qrText,
                            version: QrVersions.auto,
                            size: 220.0,
                            backgroundColor: qrBackgroundColor,
                            eyeStyle: QrEyeStyle(
                              color: qrForegroundColor,
                              eyeShape: QrEyeShape.square,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              color: qrForegroundColor,
                              dataModuleShape: QrDataModuleShape.square,
                            ),
                            embeddedImage: (includeLogo && _logoFile != null)
                                ? FileImage(_logoFile!)
                                : null,
                            embeddedImageStyle: const QrEmbeddedImageStyle(
                              size: Size(40, 40),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveQrToGallery,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Simpan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _shareQrCode,
                        icon: const Icon(Icons.share),
                        label: const Text('Bagikan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
