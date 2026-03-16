import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

class MetodoPagoPage extends StatefulWidget {
  final UbicacionSeleccionada ubicacion;
  final double subtotal;
  final double shipping;
  final double total;

  const MetodoPagoPage({
    super.key,
    required this.ubicacion,
    required this.subtotal,
    required this.shipping,
    required this.total,
  });

  @override
  State<MetodoPagoPage> createState() => _MetodoPagoPageState();
}

class _MetodoPagoPageState extends State<MetodoPagoPage> {
  static const int _maxFileSizeBytes = 5 * 1024 * 1024;

  final CartStore _store = CartStore.I;
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _creating = false;
  bool _pickingComprobante = false;
  bool _savingQr = false;
  bool _sharingQr = false;

  bool _qrActive = false;
  bool _cashActive = false;
  String? _qrImageUrl;

  String _selectedMetodo = 'qr'; // qr | efectivo

  Uint8List? _comprobanteBytes;
  String? _comprobanteName;

  @override
  void initState() {
    super.initState();
    _loadMetodosPago();
  }

  Future<void> _loadMetodosPago() async {
    try {
      setState(() => _loading = true);

      final results = await Future.wait([
        _fire.collection('pagos').doc('config_qr').get(),
        _fire.collection('pagos').doc('config_efectivo').get(),
      ]);

      final qrDoc = results[0];
      final cashDoc = results[1];

      final qrData = qrDoc.data();
      final cashData = cashDoc.data();

      final qrActive =
          (qrData?['activo'] as bool?) ??
          (qrData?['qrActive'] as bool?) ??
          false;

      final cashActive =
          (cashData?['activo'] as bool?) ??
          (cashData?['cashActive'] as bool?) ??
          false;

      final qrUrl = (qrData?['qrImageUrl'] ?? '').toString().trim();

      String selected = 'qr';
      if (qrActive) {
        selected = 'qr';
      } else if (cashActive) {
        selected = 'efectivo';
      }

      if (!mounted) return;
      setState(() {
        _qrActive = qrActive;
        _cashActive = cashActive;
        _qrImageUrl = qrUrl.isEmpty ? null : qrUrl;
        _selectedMetodo = selected;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cargar los métodos de pago: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickComprobante() async {
    try {
      setState(() => _pickingComprobante = true);

      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.lengthInBytes > _maxFileSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('El comprobante supera el límite de 5 MB.'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _comprobanteBytes = bytes;
        _comprobanteName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo seleccionar el comprobante: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingComprobante = false);
    }
  }

  Future<Uint8List> _downloadQrBytes() async {
    if (_qrImageUrl == null || _qrImageUrl!.isEmpty) {
      throw Exception('No hay imagen QR disponible.');
    }

    final response = await http.get(Uri.parse(_qrImageUrl!));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo descargar la imagen QR.');
    }

    return response.bodyBytes;
  }

  Future<void> _guardarQr() async {
    try {
      if (_qrImageUrl == null || _qrImageUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay imagen QR para guardar.')),
        );
        return;
      }

      setState(() => _savingQr = true);

      final bytes = await _downloadQrBytes();
      final fileName = 'qr_pago_${DateTime.now().millisecondsSinceEpoch}';

      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: fileName,
      );

      final success =
          result['isSuccess'] == true ||
          result['isSuccess'] == 1 ||
          result['filePath'] != null;

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Imagen QR guardada correctamente.'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo guardar la imagen QR.'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el QR: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingQr = false);
    }
  }

  Future<void> _compartirQr() async {
    try {
      if (_qrImageUrl == null || _qrImageUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay imagen QR para compartir.')),
        );
        return;
      }

      setState(() => _sharingQr = true);

      final bytes = await _downloadQrBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/qr_pago_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Te comparto el código QR para realizar el pago.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir el QR: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharingQr = false);
    }
  }

  Future<void> _hacerPedido() async {
    if (_auth.currentUser == null) return;
    if (_store.items.isEmpty) return;

    if (_selectedMetodo == 'qr') {
      if (!_qrActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El pago con QR no está disponible en este momento.'),
          ),
        );
        return;
      }

      if (_qrImageUrl == null || _qrImageUrl!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay imagen QR configurada actualmente.'),
          ),
        );
        return;
      }

      if (_comprobanteBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes subir tu comprobante antes de continuar.'),
          ),
        );
        return;
      }
    } else {
      if (!_cashActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El pago en efectivo no está disponible en este momento.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _creating = true);

    try {
      final pedidoId = await _store.checkoutToPedidos(
        ubicacion: widget.ubicacion,
        tipoPago: _selectedMetodo,
        estadoPago: 'pendiente',
        comprobanteNombre: _selectedMetodo == 'qr' ? _comprobanteName : null,
        comprobanteBytes: _selectedMetodo == 'qr' ? _comprobanteBytes : null,
        qrImageUrl: _selectedMetodo == 'qr' ? _qrImageUrl : null,
        observacionPago: _selectedMetodo == 'qr'
            ? 'Pago mediante QR con comprobante pendiente de revisión'
            : 'Pago en efectivo',
      );

      if (!mounted) return;

      if (pedidoId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo crear el pedido.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido creado correctamente ✅')),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear el pedido: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final primary = Palette.button;

    final bool canSubmit =
        !_creating &&
        (_qrActive || _cashActive) &&
        (_selectedMetodo != 'qr' || _comprobanteBytes != null);

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_rounded, color: ink),
                        ),
                        Expanded(
                          child: Text(
                            'Método de pago',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selecciona cómo deseas pagar',
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (_qrActive)
                                  _MetodoTile(
                                    selected: _selectedMetodo == 'qr',
                                    icon: Icons.qr_code_rounded,
                                    title: 'Pago con QR',
                                    subtitle:
                                        'Realiza tu transferencia y sube el comprobante.',
                                    onTap: () {
                                      setState(() => _selectedMetodo = 'qr');
                                    },
                                  ),
                                if (_qrActive && _cashActive)
                                  const SizedBox(height: 12),
                                if (_cashActive)
                                  _MetodoTile(
                                    selected: _selectedMetodo == 'efectivo',
                                    icon: Icons.payments_rounded,
                                    title: 'Pago en efectivo',
                                    subtitle:
                                        'Paga al momento de la entrega o de forma presencial.',
                                    onTap: () {
                                      setState(
                                        () => _selectedMetodo = 'efectivo',
                                      );
                                    },
                                  ),
                                if (!_qrActive && !_cashActive)
                                  Text(
                                    'No hay métodos de pago disponibles en este momento.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_selectedMetodo == 'qr' && _qrActive) ...[
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Código QR',
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Escanea este código para realizar el pago.',
                                    style: TextStyle(
                                      color: ink.withOpacity(0.65),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Palette.fieldBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: ink.withOpacity(0.06),
                                      ),
                                    ),
                                    child: Center(
                                      child:
                                          (_qrImageUrl != null &&
                                              _qrImageUrl!.isNotEmpty)
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: Container(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxHeight: 320,
                                                      maxWidth: 320,
                                                    ),
                                                color: Colors.white,
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                child: Image.network(
                                                  _qrImageUrl!,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                Icon(
                                                  Icons.qr_code_2_rounded,
                                                  size: 70,
                                                  color: ink.withOpacity(0.28),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'No hay QR disponible',
                                                  style: TextStyle(
                                                    color: ink.withOpacity(
                                                      0.60,
                                                    ),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _savingQr
                                              ? null
                                              : _guardarQr,
                                          icon: _savingQr
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.download_rounded,
                                                ),
                                          label: Text(
                                            _savingQr
                                                ? 'Guardando...'
                                                : 'Guardar',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _sharingQr
                                              ? null
                                              : _compartirQr,
                                          icon: _sharingQr
                                              ? SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: primary,
                                                      ),
                                                )
                                              : const Icon(Icons.share_rounded),
                                          label: Text(
                                            _sharingQr
                                                ? 'Compartiendo...'
                                                : 'Compartir',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: primary,
                                            side: BorderSide(color: primary),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Comprobante',
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sube una imagen de tu comprobante. Tamaño máximo: 5 MB.',
                                    style: TextStyle(
                                      color: ink.withOpacity(0.65),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (_comprobanteBytes != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.18),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _comprobanteName == null
                                                  ? 'Comprobante cargado correctamente.'
                                                  : 'Imagen del comprobante.',
                                              style: TextStyle(
                                                color: ink,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Palette.fieldBg,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: ink.withOpacity(0.06),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.memory(
                                          _comprobanteBytes!,
                                          fit: BoxFit.contain,
                                          height: 240,
                                          width: double.infinity,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _pickingComprobante
                                          ? null
                                          : _pickComprobante,
                                      icon: _pickingComprobante
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.upload_file_rounded,
                                            ),
                                      label: Text(
                                        _comprobanteBytes == null
                                            ? 'Comprobante'
                                            : 'Cambiar comprobante',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_selectedMetodo == 'efectivo' && _cashActive) ...[
                            _SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pago en efectivo',
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tu pedido será cobrado posteriormente por el repartidor que se te vaya a asignar.',
                                    style: TextStyle(
                                      color: ink.withOpacity(0.65),
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Resumen',
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _SummaryLine(
                                  label: 'Ubicación',
                                  value: widget.ubicacion.nombre,
                                ),
                                const SizedBox(height: 10),
                                _SummaryLine(
                                  label: 'Dirección',
                                  value: widget.ubicacion.direccion,
                                ),
                                const SizedBox(height: 10),
                                _SummaryLine(
                                  label: 'Subtotal',
                                  value:
                                      'Bs. ${widget.subtotal.toStringAsFixed(2)}',
                                ),
                                const SizedBox(height: 10),
                                _SummaryLine(
                                  label: 'Envío',
                                  value: widget.shipping == 0
                                      ? 'Gratis'
                                      : 'Bs. ${widget.shipping.toStringAsFixed(2)}',
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Total: Bs. ${widget.total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                    child: SizedBox(
                      height: 58,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: canSubmit ? _hacerPedido : null,
                        child: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Hacer pedido',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.ink.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}

class _MetodoTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MetodoTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button;
    final ink = Palette.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(0.10) : Palette.fieldBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primary.withOpacity(0.35) : ink.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? primary : ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: ink.withOpacity(0.62),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? primary : ink.withOpacity(0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: ink.withOpacity(0.55),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(color: ink, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}