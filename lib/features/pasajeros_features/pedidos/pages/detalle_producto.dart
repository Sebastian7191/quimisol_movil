import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/navbar/pages/nav_bar_pasajeros.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/services/pedidos_novedades_store.dart';
import 'package:quimisol_movil/shared/widgets/zoomable_image.dart';
import 'package:share_plus/share_plus.dart';

class DetallePedidoPage extends StatefulWidget {
  const DetallePedidoPage({
    super.key,
    required this.pedidoId,
    required this.pedidoCode,
  });

  final String pedidoId;
  final String pedidoCode;

  @override
  State<DetallePedidoPage> createState() => _DetallePedidoPageState();
}

class _DetallePedidoPageState extends State<DetallePedidoPage> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  static const int _maxFileSizeBytes = 5 * 1024 * 1024;

  Uint8List? _nuevoComprobanteBytes;
  String? _nuevoComprobanteNombre;
  bool _pickingComprobante = false;
  bool _reenviandoComprobante = false;

  bool _savingQr = false;
  bool _sharingQr = false;
  String? _qrImageUrl;
  bool _cancelando = false;

  DocumentReference<Map<String, dynamic>> get _pedidoDoc =>
      _fire.collection('pedidos').doc(widget.pedidoId);

  // Stream fijo: si se creara en cada build, cada setState lo reiniciaría
  // (parpadeo de carga).
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _pedidoStream =
      _pedidoDoc.snapshots();

  // ── Aviso de avance en el seguimiento ──
  final _novedades = PedidosNovedadesStore.I;

  /// Último estado que el cliente vio antes de abrir esta pantalla.
  String? _vistoAlAbrir;

  /// Paso mostrado en el último build y desde dónde animar al nuevo.
  int? _ultimoPaso;
  int _animarDesde = 0;

  /// true en el primer recorrido al abrir: se anima la carga de la caja.
  bool _primerRecorrido = false;

  bool _mostrarAviso = false;
  Timer? _avisoTimer;

  @override
  void initState() {
    super.initState();
    _loadQrConfig();

    _novedades.init();
    _vistoAlAbrir = _novedades.estadoVisto(widget.pedidoId);
    // Con la pantalla abierta, todo cambio del pedido queda visto.
    _novedades.addListener(_marcarVisto);
  }

  @override
  void dispose() {
    _avisoTimer?.cancel();
    _novedades.removeListener(_marcarVisto);
    super.dispose();
  }

  void _marcarVisto() => _novedades.marcarVisto(widget.pedidoId);

  /// Detecta si el pedido avanzó de paso (desde lo último que vio el cliente
  /// o mientras tiene la pantalla abierta) para animar el seguimiento.
  void _registrarPaso(int paso) {
    if (_ultimoPaso == paso) return;

    final primeraVez = _ultimoPaso == null;
    int desde;
    if (_ultimoPaso == null) {
      final visto = _vistoAlAbrir;
      desde = visto == null ? paso : _stepIndex(_stepFromRaw(visto));
    } else {
      desde = _ultimoPaso!;
    }

    _ultimoPaso = paso;
    final avanzo = desde < paso && paso <= 3;
    // Al abrir la pantalla el camión siempre recorre el seguimiento desde
    // el inicio; luego solo anima los avances en vivo.
    _primerRecorrido = primeraVez;
    _animarDesde = primeraVez ? 0 : (avanzo ? desde.clamp(0, 3) : paso);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _marcarVisto();
      if (!avanzo || !mounted) return;

      setState(() => _mostrarAviso = true);
      _avisoTimer?.cancel();
      _avisoTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _mostrarAviso = false);
      });
    });
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0.0;
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  String _asString(dynamic v) => (v ?? '').toString();

  String _formatTimestamp(dynamic v) {
    try {
      if (v is Timestamp) {
        final d = v.toDate();
        final dd = d.day.toString().padLeft(2, '0');
        final mm = d.month.toString().padLeft(2, '0');
        final yyyy = d.year.toString();
        final hh = d.hour.toString().padLeft(2, '0');
        final mi = d.minute.toString().padLeft(2, '0');
        return '$dd/$mm/$yyyy • $hh:$mi';
      }
    } catch (_) {}
    return '—';
  }

  String _repartidorNombreFromData(Map<String, dynamic> data) {
    dynamic v;

    if (data.containsKey('repartidorNombre')) v = data['repartidorNombre'];
    if ((v == null || _asString(v).trim().isEmpty) &&
        data.containsKey('nombreRepartidor')) {
      v = data['nombreRepartidor'];
    }
    if ((v == null || _asString(v).trim().isEmpty) &&
        data.containsKey('repartidor_name')) {
      v = data['repartidor_name'];
    }
    if ((v == null || _asString(v).trim().isEmpty) &&
        data.containsKey('repartidorName')) {
      v = data['repartidorName'];
    }

    if ((v == null || _asString(v).trim().isEmpty) &&
        data['repartidor'] is Map) {
      final m = Map<String, dynamic>.from(data['repartidor']);
      v = m['nombre'] ?? m['name'];
    }

    final s = _asString(v).trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '';
    return s;
  }

  String _itemName(Map<String, dynamic> it) {
    final a = _asString(it['name']).trim();
    if (a.isNotEmpty) return a;
    final b = _asString(it['nombre']).trim();
    if (b.isNotEmpty) return b;
    return 'Producto';
  }

  String _itemImage(Map<String, dynamic> it) =>
      _asString(it['imageUrl']).trim();

  int _itemQty(Map<String, dynamic> it) {
    final q1 = _asInt(it['qty']);
    if (q1 > 0) return q1;
    final q2 = _asInt(it['cantidad']);
    if (q2 > 0) return q2;
    return 1;
  }

  double _itemPrice(Map<String, dynamic> it) {
    final p1 = _asDouble(it['price']);
    if (p1 > 0) return p1;
    final p2 = _asDouble(it['precio']);
    if (p2 > 0) return p2;
    final p3 = _asDouble(it['unitPrice']);
    if (p3 > 0) return p3;
    return 0.0;
  }

  double _itemSubtotal(Map<String, dynamic> it) {
    final s1 = _asDouble(it['subtotal']);
    if (s1 > 0) return s1;
    return _itemQty(it) * _itemPrice(it);
  }

  String _tipoPagoLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return '—';
    if (s.contains('qr')) return 'QR';
    if (s.contains('efect')) return 'Efectivo';
    return raw;
  }

  _PaymentBadgeMeta _paymentBadge(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('rech')) {
      return _PaymentBadgeMeta(
        label: 'Rechazado',
        bg: Palette.statsDanger,
        icon: Icons.cancel_outlined,
      );
    }
    if (s.contains('pag')) {
      return _PaymentBadgeMeta(
        label: 'Pagado',
        bg: Palette.statsSuccess,
        icon: Icons.check_circle_outline_rounded,
      );
    }
    return _PaymentBadgeMeta(
      label: 'Pendiente',
      bg: Palette.statsWarning,
      icon: Icons.timelapse_rounded,
    );
  }

  String _norm(String s) => s.trim().toLowerCase();

  _TrackStep _stepFromRaw(String raw) {
    final s = _norm(raw);

    if (s == 'pendiente' || s == 'en proceso' || s == 'proceso') {
      return _TrackStep.pendiente;
    }
    if (s == 'aceptado' || s == 'aceptada') {
      return _TrackStep.aceptado;
    }
    if (s == 'en_curso' ||
        s == 'en curso' ||
        s == 'encurso' ||
        s == 'en_camino' ||
        s == 'en camino' ||
        s == 'encamino') {
      return _TrackStep.enCurso;
    }
    if (s == 'completado' || s == 'completada' || s == 'entregado') {
      return _TrackStep.completado;
    }

    if (s == 'retrasado') return _TrackStep.retrasado;
    if (s == 'cancelado' || s == 'cancelada') return _TrackStep.cancelado;

    return _TrackStep.pendiente;
  }

  _BadgeMeta _badgeFromStep(_TrackStep step) {
    switch (step) {
      case _TrackStep.completado:
        return _BadgeMeta(
          'Completado',
          Icons.check_circle_outline_rounded,
          Palette.statsSuccess,
        );
      case _TrackStep.cancelado:
        return _BadgeMeta(
          'Cancelado',
          Icons.cancel_outlined,
          Palette.statsDanger,
        );
      case _TrackStep.retrasado:
        return _BadgeMeta(
          'Retrasado',
          Icons.warning_amber_rounded,
          Palette.statsWarning,
        );
      case _TrackStep.enCurso:
        return _BadgeMeta(
          'En curso',
          Icons.local_shipping_outlined,
          Palette.statsWarning,
        );
      case _TrackStep.aceptado:
        return _BadgeMeta(
          'Aceptado',
          Icons.verified_outlined,
          Palette.statsSuccess,
        );
      case _TrackStep.pendiente:
        return _BadgeMeta(
          'Pendiente',
          Icons.timelapse_rounded,
          Palette.statsWarning,
        );
    }
  }

  int _stepIndex(_TrackStep s) {
    switch (s) {
      case _TrackStep.pendiente:
        return 0;
      case _TrackStep.aceptado:
        return 1;
      case _TrackStep.enCurso:
        return 2;
      case _TrackStep.completado:
        return 3;
      case _TrackStep.retrasado:
        return 99;
      case _TrackStep.cancelado:
        return 100;
    }
  }

  bool _isLoggedIn() => _auth.currentUser != null;

  Future<void> _cancelarPedido({
    required String pedidoId,
    required String uidCliente,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar este pedido? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, mantener'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sí, cancelar',
              style: TextStyle(color: Palette.statsDanger),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _cancelando = true);

    try {
      final batch = _fire.batch();

      final pedidoRef = _fire.collection('pedidos').doc(pedidoId);
      batch.set(pedidoRef, {
        'estado': 'Cancelado',
        // Desde aquí corren las 48 h para hablar con soporte.
        'canceladoAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (uidCliente.isNotEmpty) {
        final userPedidoRef = _fire
            .collection('usuarios')
            .doc(uidCliente)
            .collection('pedidos')
            .doc(pedidoId);
        batch.set(userPedidoRef, {
          'estado': 'Cancelado',
          'canceladoAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu pedido ha sido cancelado.'),
          backgroundColor: Palette.statsDanger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar el pedido: $e')),
      );
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  Future<void> _loadQrConfig() async {
    try {
      final qrDoc = await _fire.collection('pagos').doc('config_qr').get();
      final qrData = qrDoc.data();

      final qrActive =
          (qrData?['activo'] as bool?) ??
          (qrData?['qrActive'] as bool?) ??
          false;

      final qrUrl = (qrData?['qrImageUrl'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        _qrImageUrl = (qrActive && qrUrl.isNotEmpty) ? qrUrl : null;
      });
    } catch (_) {}
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

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Te comparto el código QR para realizar el pago.');
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

  Future<void> _pickNuevoComprobante() async {
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
          const SnackBar(
            content: Text('El comprobante supera el límite de 5 MB.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _nuevoComprobanteBytes = bytes;
        _nuevoComprobanteNombre = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar el comprobante: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingComprobante = false);
    }
  }

  String _extensionFromName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.jpg')) return 'jpg';
    if (lower.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
        return 'image/jpeg';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<String> _subirNuevoComprobante({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = _extensionFromName(fileName);
    final finalName = 'comp_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = 'pagos/comprobantes/$uid/$finalName';

    final ref = _storage.ref().child(path);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _contentTypeFromExt(ext),
        customMetadata: {
          'uid': uid,
          'pedidoId': widget.pedidoId,
          'nombre_original': fileName,
        },
      ),
    );

    return await ref.getDownloadURL();
  }

  Future<void> _reenviarComprobante() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (_nuevoComprobanteBytes == null || _nuevoComprobanteNombre == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona una nueva imagen.')),
      );
      return;
    }

    try {
      setState(() => _reenviandoComprobante = true);

      final nuevaUrl = await _subirNuevoComprobante(
        uid: uid,
        bytes: _nuevoComprobanteBytes!,
        fileName: _nuevoComprobanteNombre!,
      );

      final pedidoRef = _fire.collection('pedidos').doc(widget.pedidoId);
      final pedidoSnap = await pedidoRef.get();
      final data = pedidoSnap.data() ?? <String, dynamic>{};

      final uidCliente = (data['uid'] ?? uid).toString().trim();

      final updatePayload = <String, dynamic>{
        'comprobante_url': nuevaUrl,
        'comprobante_nombre': _nuevoComprobanteNombre,
        'estado_pago': 'pendiente',
        'motivo_rechazo_pago': '',
        // Con el nuevo comprobante ya no corre el plazo de cancelación.
        'fecha_limite_pago': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = _fire.batch();
      batch.set(pedidoRef, updatePayload, SetOptions(merge: true));

      if (uidCliente.isNotEmpty) {
        final userPedidoRef = _fire
            .collection('usuarios')
            .doc(uidCliente)
            .collection('pedidos')
            .doc(widget.pedidoId);

        batch.set(userPedidoRef, {
          'comprobante_url': nuevaUrl,
          'comprobante_nombre': _nuevoComprobanteNombre,
          'estado_pago': 'pendiente',
          'motivo_rechazo_pago': '',
          'fecha_limite_pago': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _nuevoComprobanteBytes = null;
        _nuevoComprobanteNombre = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante reenviado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reenviar comprobante: $e')),
      );
    } finally {
      if (mounted) setState(() => _reenviandoComprobante = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Palette.fieldBg;
    final purple = Palette.primary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: purple),
                  ),
                  Expanded(
                    child: Text(
                      'Pedido #${widget.pedidoCode}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: purple,
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: !_isLoggedIn()
                  ? Center(
                      child: Text(
                        'Inicia sesión para ver el pedido.',
                        style: TextStyle(
                          color: purple.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _pedidoStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                'Error al cargar el pedido.\n${snap.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: purple.withOpacity(0.75),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        }

                        final data = snap.data?.data();
                        if (data == null) {
                          return Center(
                            child: Text(
                              'Pedido no encontrado.',
                              style: TextStyle(
                                color: purple.withOpacity(0.75),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        }

                        final estadoRaw = _asString(data['estado']);
                        final step = _stepFromRaw(estadoRaw);
                        final badge = _badgeFromStep(step);
                        _registrarPaso(_stepIndex(step));

                        final repartidorNombre = _repartidorNombreFromData(
                          data,
                        );

                        final entregaRaw = data['fecha_entrega'];
                        final envioRaw = data['fecha_envio'];

                        final entregaText = (entregaRaw != null)
                            ? _formatTimestamp(entregaRaw)
                            : (envioRaw != null)
                            ? _formatTimestamp(envioRaw)
                            : 'En revisión';

                        final costoEnvio = _asDouble(
                          data.containsKey('costo_envio')
                              ? data['costo_envio']
                              : data['costoEnvio'],
                        );

                        final tipoPago = _asString(
                          data['tipo_pago'] ?? data['tipoPago'],
                        ).trim();

                        final estadoPago = _asString(
                          data['estado_pago'] ?? data['estadoPago'],
                        ).trim();

                        final motivoRechazoPago = _asString(
                          data['motivo_rechazo_pago'],
                        ).trim();

                        final comprobanteUrl = _asString(
                          data['comprobante_url'],
                        ).trim();

                        final comprobanteNombre = _asString(
                          data['comprobante_nombre'],
                        ).trim();

                        final paymentBadge = _paymentBadge(estadoPago);
                        final pagoRechazado =
                            estadoPago.trim().toLowerCase() == 'rechazado';
                        // Plazo para volver a pagar (lo pone la Cloud
                        // Function al rechazar el comprobante).
                        final limitePagoRaw = data['fecha_limite_pago'];
                        final limitePagoTexto = limitePagoRaw is Timestamp
                            ? _formatTimestamp(limitePagoRaw)
                            : '';
                        final esEfectivo = tipoPago
                            .trim()
                            .toLowerCase()
                            .contains('efect');

                        final uidCliente = _asString(data['uid']).trim();

                        final itemsRaw = data['items'];
                        final items = <Map<String, dynamic>>[];
                        if (itemsRaw is List) {
                          for (final e in itemsRaw) {
                            if (e is Map) {
                              items.add(Map<String, dynamic>.from(e));
                            }
                          }
                        }

                        final productsSubtotal = items.fold<double>(
                          0,
                          (acc, it) => acc + _itemSubtotal(it),
                        );

                        final totalDoc = _asDouble(data['total']);
                        final totalProductos = totalDoc > 0
                            ? totalDoc
                            : productsSubtotal;

                        final totalFinal =
                            totalProductos + (costoEnvio > 0 ? costoEnvio : 0);

                        final showSpecial = false;
                        final isCancelled = step == _TrackStep.cancelado;
                        final isDelayed = step == _TrackStep.retrasado;

                        // Cancelado: 48 h desde la cancelación para hablar
                        // con soporte. Pedidos viejos sin canceladoAt usan
                        // la última actualización.
                        final canceladoTs =
                            data['canceladoAt'] ?? data['updatedAt'];
                        final limiteReclamo = canceladoTs is Timestamp
                            ? canceladoTs.toDate().add(
                                const Duration(hours: 48),
                              )
                            : null;
                        final limiteReclamoTexto = limiteReclamo == null
                            ? ''
                            : _formatTimestamp(
                                Timestamp.fromDate(limiteReclamo),
                              );

                        return Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  140,
                                ),
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Palette.card,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.65),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: badge.bg,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    badge.icon,
                                                    size: 16,
                                                    color: Palette.white,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    badge.label,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              'Resumen',
                                              style: TextStyle(
                                                color: purple.withOpacity(0.80),
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _ResumenRow(
                                          label: 'Repartidor',
                                          value: repartidorNombre.isEmpty
                                              ? 'Asignando…'
                                              : repartidorNombre,
                                          valueColor: repartidorNombre.isEmpty
                                              ? Palette.statsWarning
                                              : purple,
                                        ),
                                        const SizedBox(height: 10),
                                        _ResumenRow(
                                          label: 'Entrega',
                                          value: entregaText,
                                          valueColor:
                                              (entregaRaw == null &&
                                                  envioRaw == null)
                                              ? Palette.statsWarning
                                              : purple,
                                        ),
                                        const SizedBox(height: 10),
                                        _ResumenRow(
                                          label: 'Tipo pago',
                                          value: _tipoPagoLabel(tipoPago),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Text(
                                              'Estado pago',
                                              style: TextStyle(
                                                color: purple.withOpacity(0.75),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: paymentBadge.bg,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    paymentBadge.icon,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    paymentBadge.label,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (esEfectivo) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Palette.statsWarning
                                                  .withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Palette.statsWarning
                                                    .withOpacity(0.22),
                                              ),
                                            ),
                                            child: Text(
                                              'Recuerda pagar al repartidor cuando tu entrega sea completada, por favor 😊',
                                              style: TextStyle(
                                                color: purple.withOpacity(0.92),
                                                fontWeight: FontWeight.w700,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (motivoRechazoPago.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          _ReasonBox(
                                            title: 'Motivo del rechazo',
                                            text: motivoRechazoPago,
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Divider(
                                          color: purple.withOpacity(0.12),
                                          height: 1,
                                        ),
                                        const SizedBox(height: 10),
                                        _ResumenRow(
                                          label: 'Productos',
                                          value:
                                              'Bs. ${totalProductos.toStringAsFixed(2)}',
                                        ),
                                        const SizedBox(height: 8),
                                        // Mientras el admin no acepta el pedido
                                        // el envío aún no está definido.
                                        _ResumenRow(
                                          label: 'Envío',
                                          value: step == _TrackStep.pendiente
                                              ? 'Pendiente'
                                              : costoEnvio <= 0
                                              ? 'Gratis'
                                              : 'Bs. ${costoEnvio.toStringAsFixed(2)}',
                                          valueColor:
                                              step == _TrackStep.pendiente
                                              ? const Color(0xFFF59E0B)
                                              : costoEnvio <= 0
                                              ? Palette.statsSuccess
                                              : purple,
                                        ),
                                        const SizedBox(height: 10),
                                        Divider(
                                          color: purple.withOpacity(0.12),
                                          height: 1,
                                        ),
                                        const SizedBox(height: 10),
                                        _ResumenRow(
                                          label: 'Total',
                                          value:
                                              'Bs. ${totalFinal.toStringAsFixed(2)}',
                                          strong: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!esEfectivo &&
                                      !pagoRechazado &&
                                      comprobanteUrl.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    _ClientComprobanteCard(
                                      comprobanteUrl:
                                          _nuevoComprobanteBytes != null
                                          ? null
                                          : comprobanteUrl,
                                      comprobanteNombre:
                                          _nuevoComprobanteNombre ??
                                          comprobanteNombre,
                                      localBytes: _nuevoComprobanteBytes,
                                    ),
                                  ] else if (!esEfectivo &&
                                      !pagoRechazado &&
                                      _nuevoComprobanteBytes != null) ...[
                                    const SizedBox(height: 14),
                                    _ClientComprobanteCard(
                                      comprobanteUrl: null,
                                      comprobanteNombre:
                                          _nuevoComprobanteNombre ?? '',
                                      localBytes: _nuevoComprobanteBytes,
                                    ),
                                  ],
                                  if (!esEfectivo && pagoRechazado) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Palette.card,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.65),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 18,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.refresh_rounded,
                                                color: purple,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Pago rechazado',
                                                style: TextStyle(
                                                  color: purple,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Tu pago fue rechazado. Vuelve a realizar el pago usando el QR y luego sube un nuevo comprobante para enviarlo nuevamente a revisión.',
                                            style: TextStyle(
                                              color: purple.withOpacity(0.82),
                                              fontWeight: FontWeight.w700,
                                              height: 1.35,
                                            ),
                                          ),
                                          if (limitePagoTexto.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Palette.statsDanger
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: Palette.statsDanger
                                                      .withOpacity(0.25),
                                                ),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    Icons.timer_outlined,
                                                    size: 18,
                                                    color: Palette.statsDanger,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Tienes hasta el $limitePagoTexto para subir un nuevo comprobante. Si no, tu pedido se cancelará automáticamente.',
                                                      style: TextStyle(
                                                        color:
                                                            Palette.statsDanger,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 14),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              color: Palette.fieldBg,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: purple.withOpacity(0.06),
                                              ),
                                            ),
                                            child: Center(
                                              child:
                                                  (_qrImageUrl != null &&
                                                      _qrImageUrl!.isNotEmpty)
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            18,
                                                          ),
                                                      child: Container(
                                                        constraints:
                                                            const BoxConstraints(
                                                              maxHeight: 320,
                                                              maxWidth: 320,
                                                            ),
                                                        color: Colors.white,
                                                        padding:
                                                            const EdgeInsets.all(
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
                                                          Icons
                                                              .qr_code_2_rounded,
                                                          size: 70,
                                                          color: purple
                                                              .withOpacity(
                                                                0.28,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Text(
                                                          'No hay QR disponible',
                                                          style: TextStyle(
                                                            color: purple
                                                                .withOpacity(
                                                                  0.60,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w800,
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
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        )
                                                      : const Icon(
                                                          Icons
                                                              .download_rounded,
                                                        ),
                                                  label: Text(
                                                    _savingQr
                                                        ? 'Guardando...'
                                                        : 'Guardar',
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Palette.button,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
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
                                                                color: Palette
                                                                    .button,
                                                              ),
                                                        )
                                                      : const Icon(
                                                          Icons.share_rounded,
                                                        ),
                                                  label: Text(
                                                    _sharingQr
                                                        ? 'Compartiendo...'
                                                        : 'Compartir',
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Palette.button,
                                                    side: BorderSide(
                                                      color: Palette.button,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 18),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: _pickingComprobante
                                                  ? null
                                                  : _pickNuevoComprobante,
                                              icon: _pickingComprobante
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
                                                      Icons.upload_file_rounded,
                                                    ),
                                              label: Text(
                                                _nuevoComprobanteBytes == null
                                                    ? 'Comprobante'
                                                    : 'Cambiar comprobante',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Palette.button,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_nuevoComprobanteBytes !=
                                              null) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Palette.fieldBg,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: purple.withOpacity(
                                                    0.06,
                                                  ),
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: Image.memory(
                                                  _nuevoComprobanteBytes!,
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
                                              onPressed:
                                                  (_reenviandoComprobante ||
                                                      _nuevoComprobanteBytes ==
                                                          null)
                                                  ? null
                                                  : _reenviarComprobante,
                                              icon: _reenviandoComprobante
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
                                                      Icons.send_rounded,
                                                    ),
                                              label: Text(
                                                _reenviandoComprobante
                                                    ? 'Reenviando...'
                                                    : 'Reenviar comprobante',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Palette.button,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.shopping_bag_rounded,
                                        color: purple.withOpacity(0.90),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Productos',
                                        style: TextStyle(
                                          color: purple,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${items.length})',
                                        style: TextStyle(
                                          color: purple.withOpacity(0.75),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (items.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 18),
                                      child: Center(
                                        child: Text(
                                          'Este pedido no tiene items.',
                                          style: TextStyle(
                                            color: purple.withOpacity(0.75),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ...items.map((it) {
                                      final name = _itemName(it);
                                      final img = _itemImage(it);
                                      final qty = _itemQty(it);
                                      final price = _itemPrice(it);
                                      final sub = _itemSubtotal(it);

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _PedidoItemRow(
                                          name: name,
                                          imageUrl: img,
                                          qty: qty,
                                          price: price,
                                          subtotal: sub,
                                        ),
                                      );
                                    }),
                                  if (step == _TrackStep.pendiente &&
                                      esEfectivo) ...[
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        onPressed: _cancelando
                                            ? null
                                            : () => _cancelarPedido(
                                                pedidoId: widget.pedidoId,
                                                uidCliente: uidCliente,
                                              ),
                                        icon: _cancelando
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          Palette.statsDanger,
                                                    ),
                                              )
                                            : const Icon(Icons.cancel_outlined),
                                        label: Text(
                                          _cancelando
                                              ? 'Cancelando...'
                                              : 'Cancelar pedido',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Palette.statsDanger,
                                          side: BorderSide(
                                            color: Palette.statsDanger,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                14,
                              ),
                              decoration: BoxDecoration(
                                color: Palette.white,
                                border: Border(
                                  top: BorderSide(
                                    color: purple.withOpacity(0.10),
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 18,
                                    offset: const Offset(0, -10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.route_rounded,
                                        size: 18,
                                        color: purple.withOpacity(0.90),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Seguimiento',
                                        style: TextStyle(
                                          color: purple,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Aviso de que el pedido avanzó.
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        transitionBuilder: (child, anim) =>
                                            ScaleTransition(
                                              scale: anim,
                                              child: child,
                                            ),
                                        child: _mostrarAviso
                                            ? Container(
                                                key: const ValueKey('aviso'),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Palette.statsSuccess,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: const Text(
                                                  '¡Actualizado!',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 10.5,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(
                                                key: ValueKey('nada'),
                                              ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        badge.label,
                                        style: TextStyle(
                                          color: purple.withOpacity(0.85),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (isCancelled)
                                    _CanceladoBanner(
                                      motivo: _asString(
                                        data['motivo_cancelacion'],
                                      ).trim(),
                                      limite: limiteReclamo,
                                      limiteTexto: limiteReclamoTexto,
                                      onSoporte: () =>
                                          Navbar.irAPestana(context, 3),
                                    )
                                  else if (showSpecial && isDelayed)
                                    _SpecialStateBanner(
                                      type: isCancelled
                                          ? _SpecialType.cancelado
                                          : _SpecialType.retrasado,
                                    )
                                  else
                                    _TrackingRow(
                                      key: ValueKey(
                                        '$_animarDesde-${_stepIndex(step)}',
                                      ),
                                      activeIndex: _stepIndex(step).clamp(0, 3),
                                      desde: _animarDesde,
                                      cargar: _primerRecorrido,
                                      camion: !isCancelled && !isDelayed,
                                      celebrar: step == _TrackStep.completado,
                                      purple: purple,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenRow extends StatelessWidget {
  const _ResumenRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: purple.withOpacity(0.75),
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? purple,
              fontWeight: FontWeight.w900,
              fontSize: strong ? 14.5 : 13.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.statsDanger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.statsDanger.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Palette.statsDanger,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: Palette.primary.withOpacity(0.92),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientComprobanteCard extends StatelessWidget {
  const _ClientComprobanteCard({
    required this.comprobanteUrl,
    required this.comprobanteNombre,
    required this.localBytes,
  });

  final String? comprobanteUrl;
  final String comprobanteNombre;
  final Uint8List? localBytes;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;

    return Container(
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: purple, size: 18),
              const SizedBox(width: 8),
              Text(
                'Comprobante',
                style: TextStyle(
                  color: purple,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withOpacity(0.9),
                builder: (_) => _ComprobanteZoomDialog(
                  imageUrl: comprobanteUrl,
                  title: 'Comprobante',
                  localBytes: localBytes,
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Palette.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: purple.withOpacity(0.10)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1.15,
                  child: localBytes != null
                      ? Image.memory(localBytes!, fit: BoxFit.contain)
                      : Image.network(
                          comprobanteUrl ?? '',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Center(
                              child: Text(
                                'No se pudo cargar el comprobante.',
                                style: TextStyle(
                                  color: purple.withOpacity(0.75),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca la imagen para verla completa.',
            style: TextStyle(
              color: purple.withOpacity(0.70),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComprobanteZoomDialog extends StatelessWidget {
  const _ComprobanteZoomDialog({
    required this.imageUrl,
    required this.title,
    required this.localBytes,
  });

  final String? imageUrl;
  final String title;
  final Uint8List? localBytes;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.92),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.trim().isEmpty ? 'Comprobante' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    panEnabled: true,
                    child: Center(
                      child: localBytes != null
                          ? Image.memory(localBytes!, fit: BoxFit.contain)
                          : Image.network(
                              imageUrl ?? '',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) {
                                return const Text(
                                  'No se pudo cargar la imagen.',
                                  style: TextStyle(color: Colors.white),
                                );
                              },
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const CircularProgressIndicator(
                                  color: Colors.white,
                                );
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Usa dos dedos para hacer zoom y arrastra para mover la imagen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PedidoItemRow extends StatelessWidget {
  const _PedidoItemRow({
    required this.name,
    required this.imageUrl,
    required this.qty,
    required this.price,
    required this.subtotal,
  });

  final String name;
  final String imageUrl;
  final int qty;
  final double price;
  final double subtotal;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;

    return Container(
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.65)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ZoomableImage(
            url: imageUrl,
            titulo: name,
            abrirAlTocar: true,
            child: Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Palette.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: purple.withOpacity(0.10)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: imageUrl.trim().isEmpty
                    ? Icon(
                        Icons.image_outlined,
                        color: purple.withOpacity(0.55),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          color: purple.withOpacity(0.55),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: purple,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(text: 'Cant: $qty'),
                    _Pill(text: 'Bs. ${price.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Subtotal',
                style: TextStyle(
                  color: purple.withOpacity(0.70),
                  fontWeight: FontWeight.w800,
                  fontSize: 11.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bs. ${subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: purple,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: purple.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: purple.withOpacity(0.90),
          fontWeight: FontWeight.w900,
          fontSize: 11.2,
        ),
      ),
    );
  }
}

/// Seguimiento con un camión que recorre los pasos:
/// - Al abrir la pantalla ([cargar]) la caja cae dentro del camión en
///   "Pendiente" y el camión avanza hasta el paso actual.
/// - En "En curso" se queda rodando.
/// - En "Completado" ([celebrar]) deja la caja en el último paso, salta
///   confeti y el camión se va.
class _TrackingRow extends StatefulWidget {
  const _TrackingRow({
    super.key,
    required this.activeIndex,
    required this.purple,
    this.desde,
    this.cargar = false,
    this.camion = true,
    this.celebrar = false,
  });

  final int activeIndex;
  final Color purple;

  /// Paso desde el que se anima el avance; null o igual a [activeIndex]
  /// = sin avance.
  final int? desde;

  /// Anima la carga de la caja antes de que salga el camión.
  final bool cargar;

  /// false en estados especiales (cancelado / retrasado): sin camión.
  final bool camion;

  /// Pedido entregado: animación especial de entrega.
  final bool celebrar;

  @override
  State<_TrackingRow> createState() => _TrackingRowState();
}

class _TrackingRowState extends State<_TrackingRow>
    with TickerProviderStateMixin {
  static const double _laneH = 34;
  static const double _dotR = 19;
  static const _steps = <_TrackNode>[
    _TrackNode('Pendiente', Icons.receipt_long_rounded),
    _TrackNode('Aceptado', Icons.verified_outlined),
    _TrackNode('En curso', Icons.local_shipping_outlined),
    _TrackNode('Completado', Icons.check_circle_outline_rounded),
  ];

  late final int _from = (widget.desde ?? widget.activeIndex).clamp(
    0,
    widget.activeIndex,
  );

  late final AnimationController _load = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _drive = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 550 * (widget.activeIndex - _from) + 250),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController _deliver = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  bool get _celebra =>
      widget.camion &&
      widget.celebrar &&
      widget.activeIndex == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _load.dispose();
    _drive.dispose();
    _loop.dispose();
    _deliver.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final avanza = widget.activeIndex > _from;
    try {
      if (!widget.camion) {
        if (avanza) {
          await _drive.forward().orCancel;
        } else {
          _drive.value = 1;
        }
        return;
      }

      if (widget.cargar) {
        await _load.forward().orCancel;
      } else {
        _load.value = 1;
      }

      if (avanza) {
        _loop.repeat();
        await _drive.forward().orCancel;
      } else {
        _drive.value = 1;
      }

      if (_celebra) {
        if (!_loop.isAnimating) _loop.repeat();
        await _deliver.forward().orCancel;
        _loop.stop();
      } else if (widget.activeIndex == 2) {
        // En curso: el camión sigue rodando.
        if (!_loop.isAnimating) _loop.repeat();
      } else {
        _loop.stop();
      }
    } on TickerCanceled {
      // Se cerró la pantalla a mitad de la animación.
    }
  }

  static double _iv(double t, double a, double b, [Curve c = Curves.linear]) {
    return c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_load, _drive, _loop, _deliver]),
      builder: (context, _) {
        final p =
            _from +
            (widget.activeIndex - _from) *
                Curves.easeInOutCubic.transform(_drive.value);
        final l = _load.value;
        final d = _deliver.value;

        // En la entrega, "Completado" se marca cuando la caja cae en él.
        final row = _row(p, entregada: !_celebra || d >= 0.42);
        if (!widget.camion) return row;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: _laneH),
                row,
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TruckLanePainter(
                    steps: _steps.length,
                    p: p,
                    laneH: _laneH,
                    dotY: _laneH + _dotR,
                    dotR: _dotR,
                    accent: Palette.button,
                    success: Palette.statsSuccess,
                    road: widget.purple,
                    loop: _loop.value,
                    boxAppear: _iv(l, 0, 0.4, Curves.easeOutBack),
                    boxDrop: _iv(l, 0.45, 0.85, Curves.easeInCubic),
                    landBounce: math.sin(math.pi * _iv(l, 0.85, 1)),
                    boxRise: _iv(d, 0.08, 0.22, Curves.easeOutCubic),
                    boxFall: _iv(d, 0.22, 0.42, Curves.easeInCubic),
                    burst: _iv(d, 0.42, 1),
                    exit: _iv(d, 0.5, 0.85, Curves.easeInCubic),
                    speedLines: math.sin(math.pi * _iv(d, 0.5, 0.85)),
                    label: _iv(d, 0.75, 1, Curves.easeOutBack),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(double p, {required bool entregada}) {
    const eps = 0.001;
    final purple = widget.purple;
    final activeIndex = widget.activeIndex;
    final anima = activeIndex > _from;

    final lastIndex = _steps.length - 1;
    final llego = p >= activeIndex - eps;
    final isFinished = activeIndex >= lastIndex && llego && entregada;

    return Row(
      // Círculos alineados arriba aunque alguna etiqueta use dos líneas.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: _TrackDot(
              label: _steps[i].label,
              icon: _steps[i].icon,
              done: isFinished ? (i <= p + eps) : (i < p - eps),
              active: !isFinished && i == activeIndex && llego,
              // El paso nuevo "rebota" al llegar; en la entrega, al caer
              // la caja.
              pop: _celebra
                  ? i == lastIndex && isFinished
                  : anima && i == activeIndex && llego,
            ),
          ),
          if (i != _steps.length - 1)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(top: _dotR - 1.5),
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (p - i).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Palette.statsSuccess.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _TrackDot extends StatelessWidget {
  const _TrackDot({
    required this.label,
    required this.icon,
    required this.done,
    required this.active,
    this.pop = false,
  });

  final String label;
  final IconData icon;
  final bool done;
  final bool active;

  /// Anima un rebote (escala) al aparecer como paso actual.
  final bool pop;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;

    Color bg;
    Color fg;
    if (done) {
      bg = Palette.statsSuccess;
      fg = Palette.white;
    } else if (active) {
      bg = Palette.button;
      fg = Palette.white;
    } else {
      bg = Palette.white;
      fg = purple.withOpacity(0.70);
    }

    final circulo = Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: purple.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: pop
                ? Palette.button.withOpacity(0.45)
                : Colors.black.withOpacity(0.05),
            blurRadius: pop ? 16 : 12,
            offset: pop ? Offset.zero : const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: fg),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pop
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: circulo,
              )
            : circulo,
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: purple.withOpacity(active || done ? 0.95 : 0.70),
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _TrackNode {
  final String label;
  final IconData icon;
  const _TrackNode(this.label, this.icon);
}

/// Dibuja el carril del camión sobre el seguimiento: camino, camión, caja,
/// y en la entrega el anillo, el confeti y el aviso "¡Entregado!".
class _TruckLanePainter extends CustomPainter {
  _TruckLanePainter({
    required this.steps,
    required this.p,
    required this.laneH,
    required this.dotY,
    required this.dotR,
    required this.accent,
    required this.success,
    required this.road,
    required this.loop,
    required this.boxAppear,
    required this.boxDrop,
    required this.landBounce,
    required this.boxRise,
    required this.boxFall,
    required this.burst,
    required this.exit,
    required this.speedLines,
    required this.label,
  });

  final int steps;
  final double p; // posición del camión en pasos (0..steps-1)
  final double laneH;
  final double dotY; // centro vertical de los círculos
  final double dotR;
  final Color accent;
  final Color success;
  final Color road;
  final double loop; // ciclo de ruedas / camino / vaivén

  // Carga al abrir la pantalla
  final double boxAppear;
  final double boxDrop;
  final double landBounce;

  // Entrega
  final double boxRise;
  final double boxFall;
  final double burst;
  final double exit;
  final double speedLines;
  final double label;

  static const double _cargoW = 26;
  static const double _cargoH = 15;
  static const double _cabW = 12;
  static const double _cabH = 11;
  static const double _gap = 1.5;
  static const double _truckW = _cargoW + _gap + _cabW;
  static const double _wheelR = 3.5;
  static const double _boxS = 10;
  static const Color _wheelColor = Color(0xFF263238);
  static const Color _boxColor = Color(0xFFFFB74D);
  static const Color _boxTape = Color(0xFFE08E2B);

  // (ángulo, velocidad, tamaño, color, giro) de cada papelito de confeti.
  static final List<(double, double, double, int, double)> _confeti = () {
    final r = math.Random(11);
    return List.generate(22, (_) {
      return (
        -math.pi * (0.08 + 0.84 * r.nextDouble()),
        32 + 38 * r.nextDouble(),
        2.5 + 1.8 * r.nextDouble(),
        r.nextInt(4),
        (r.nextDouble() - 0.5) * 12,
      );
    });
  }();

  double _nodeX(double w, double q) => w * (2 * q + 0.5) / (2 * steps - 1);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final roadY = laneH - 1;
    final wheelCy = roadY - 1.5 - _wheelR;
    final bodyBottom = wheelCy - 0.5;
    final cargoTop = bodyBottom - _cargoH;

    final lastX = _nodeX(w, steps - 1.0);
    final centerX = _nodeX(w, p) + exit * (w - lastX + _truckW + 10);
    final truckX = centerX - _truckW / 2;
    final cargoCx = truckX + _cargoW / 2;

    final idleBounce = (math.sin(loop * 2 * math.pi)).abs() * 0.8;
    final bodyDy = landBounce * 2 - idleBounce;

    final hoverTop = cargoTop - _boxS - 2.5;
    final insideTop = cargoTop + 2 + bodyDy;

    _paintRoad(canvas, w, roadY);
    _paintSpeedLines(canvas, truckX, cargoTop);

    // Caja que se carga al abrir (detrás del furgón para que "entre").
    if (boxDrop < 1 && boxAppear > 0) {
      final top = hoverTop + (insideTop - hoverTop) * boxDrop;
      _paintBox(canvas, Offset(cargoCx, top + _boxS / 2), boxAppear);
    }
    // Caja que sale del furgón en la entrega.
    if (boxRise > 0 && boxFall == 0) {
      final top = insideTop + (hoverTop - insideTop) * boxRise;
      _paintBox(canvas, Offset(cargoCx, top + _boxS / 2), 1);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, -laneH, w, laneH + 2));
    _paintTruck(canvas, truckX, bodyBottom + bodyDy, wheelCy);
    canvas.restore();

    // La caja cae sobre "Completado".
    if (boxFall > 0 && boxFall < 1) {
      final from = Offset(cargoCx, hoverTop + _boxS / 2);
      final to = Offset(lastX, dotY);
      _paintBox(canvas, Offset.lerp(from, to, boxFall)!, 1 - 0.45 * boxFall);
    }

    if (burst > 0 && burst < 1) _paintBurst(canvas, Offset(lastX, dotY));
    if (label > 0) _paintLabel(canvas, w, lastX);
  }

  void _paintRoad(Canvas canvas, double w, double y) {
    final paint = Paint()
      ..color = road.withOpacity(0.16)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dash = 6.0;
    const period = 11.0;
    final shift = loop * period;
    for (double x = -period; x < w + period; x += period) {
      final a = (x - shift).clamp(0.0, w);
      final b = (x - shift + dash).clamp(0.0, w);
      if (b > a) canvas.drawLine(Offset(a, y), Offset(b, y), paint);
    }
  }

  void _paintSpeedLines(Canvas canvas, double truckX, double cargoTop) {
    if (speedLines <= 0) return;
    final paint = Paint()
      ..color = accent.withOpacity(0.6 * speedLines)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const lines = [(3.0, 12.0), (8.0, 8.0), (12.0, 15.0)];
    for (final (dy, len) in lines) {
      final y = cargoTop + dy;
      final right = truckX - 4;
      canvas.drawLine(
        Offset(right - len * speedLines, y),
        Offset(right, y),
        paint,
      );
    }
  }

  void _paintBox(Canvas canvas, Offset center, double scale) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _boxS,
      height: _boxS,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = _boxColor,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 2.2, height: _boxS),
      Paint()..color = _boxTape,
    );
    canvas.restore();
  }

  void _paintTruck(Canvas canvas, double x, double bodyBottom, double wheelCy) {
    final cabColor = Color.lerp(accent, Colors.black, 0.18)!;

    // Chasis
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 1.5, bodyBottom - 2.5, _truckW - 1.5, 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = cabColor,
    );

    // Furgón
    final cargo = Rect.fromLTWH(x, bodyBottom - _cargoH, _cargoW, _cargoH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargo, const Radius.circular(3)),
      Paint()..color = accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 4, cargo.center.dy - 1, _cargoW - 8, 2),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.white.withOpacity(0.55),
    );

    // Cabina
    final cabL = x + _cargoW + _gap;
    final cabT = bodyBottom - _cabH;
    final cab = Path()
      ..moveTo(cabL, bodyBottom)
      ..lineTo(cabL, cabT + 1.5)
      ..quadraticBezierTo(cabL, cabT, cabL + 1.5, cabT)
      ..lineTo(cabL + _cabW - 5, cabT)
      ..lineTo(cabL + _cabW, cabT + 4.5)
      ..lineTo(cabL + _cabW, bodyBottom - 1.5)
      ..quadraticBezierTo(
        cabL + _cabW,
        bodyBottom,
        cabL + _cabW - 1.5,
        bodyBottom,
      )
      ..close();
    canvas.drawPath(cab, Paint()..color = cabColor);

    final window = Path()
      ..moveTo(cabL + 4.5, cabT + 2)
      ..lineTo(cabL + _cabW - 5.6, cabT + 2)
      ..lineTo(cabL + _cabW - 2.2, cabT + 5)
      ..lineTo(cabL + 4.5, cabT + 5)
      ..close();
    canvas.drawPath(window, Paint()..color = Colors.white.withOpacity(0.9));

    canvas.drawCircle(
      Offset(cabL + _cabW - 1, bodyBottom - 3.2),
      1.1,
      Paint()..color = _boxColor,
    );

    _paintWheel(canvas, Offset(x + 6.5, wheelCy));
    _paintWheel(canvas, Offset(cabL + _cabW - 4.5, wheelCy));
  }

  void _paintWheel(Canvas canvas, Offset c) {
    canvas.drawCircle(c, _wheelR, Paint()..color = _wheelColor);
    canvas.drawCircle(c, 1.3, Paint()..color = Colors.white);
    final a = loop * 2 * math.pi;
    final spoke = Offset(math.cos(a), math.sin(a)) * (_wheelR - 0.6);
    canvas.drawLine(
      c - spoke,
      c + spoke,
      Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..strokeWidth = 0.9,
    );
  }

  void _paintBurst(Canvas canvas, Offset c) {
    // Anillo que se expande desde "Completado".
    final rt = (burst / 0.6).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      dotR + 16 * Curves.easeOut.transform(rt),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - rt)
        ..color = success.withOpacity(1 - rt),
    );

    // Confeti
    final colors = [success, accent, _boxColor, const Color(0xFFFF6B9A)];
    final t = burst;
    for (final (a, v, s, ci, spin) in _confeti) {
      final pos =
          c +
          Offset(math.cos(a), math.sin(a)) *
              (dotR * 0.6 + v * Curves.easeOut.transform(t)) +
          Offset(0, 38 * t * t);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(spin * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: s, height: s * 1.6),
        Paint()..color = colors[ci].withOpacity(1 - t),
      );
      canvas.restore();
    }
  }

  void _paintLabel(Canvas canvas, double w, double lastX) {
    final tp = TextPainter(
      text: const TextSpan(
        text: '¡Entregado! 🎉',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillW = tp.width + 16;
    final pillH = tp.height + 6;
    final cx = math.min(lastX, w - pillW / 2 - 2);
    final cy = laneH / 2 + 1;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(label);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: pillW, height: pillH),
        const Radius.circular(999),
      ),
      Paint()..color = success.withOpacity(label.clamp(0.0, 1.0)),
    );
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TruckLanePainter old) => true;
}

/// Seguimiento de un pedido cancelado: motivo, plazo de 48 h para hablar
/// con soporte y botón para ir al chat. Vencido el plazo, el pedido se
/// da por perdido.
class _CanceladoBanner extends StatelessWidget {
  const _CanceladoBanner({
    required this.motivo,
    required this.limite,
    required this.limiteTexto,
    required this.onSoporte,
  });

  final String motivo;
  final DateTime? limite;
  final String limiteTexto;
  final VoidCallback onSoporte;

  String _restante(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      return 'Te quedan $h hora${h == 1 ? '' : 's'}';
    }
    final m = d.inMinutes.clamp(1, 59);
    return 'Te quedan $m minuto${m == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final rojo = Palette.statsDanger;
    final restante = limite?.difference(DateTime.now());
    final vencido = restante != null && restante.isNegative;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rojo.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rojo.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(color: rojo, shape: BoxShape.circle),
                child: const Icon(
                  Icons.close_rounded,
                  color: Palette.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido cancelado',
                      style: TextStyle(
                        color: rojo,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (motivo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        motivo,
                        style: TextStyle(
                          color: Palette.ink.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            vencido
                ? 'El plazo de 48 horas para comunicarte con soporte ya '
                      'venció, así que este pedido se dio por perdido.'
                : 'Tienes 48 horas para comunicarte con soporte si quieres '
                      'recuperar tu pedido. Pasado ese plazo, el pedido se '
                      'perderá.',
            style: TextStyle(
              color: Palette.ink.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (!vencido && limiteTexto.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: rojo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    restante == null
                        ? 'Plazo: hasta el $limiteTexto'
                        : 'Hasta el $limiteTexto · ${_restante(restante)}',
                    style: TextStyle(
                      color: rojo,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!vencido) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: onSoporte,
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text(
                  'Hablar con soporte',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.button,
                  foregroundColor: Palette.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _SpecialType { retrasado, cancelado }

class _SpecialStateBanner extends StatelessWidget {
  const _SpecialStateBanner({required this.type});
  final _SpecialType type;

  @override
  Widget build(BuildContext context) {
    final purple = Palette.primary;

    final isCancel = type == _SpecialType.cancelado;
    final bg = isCancel ? Palette.statsDanger : Palette.statsWarning;
    final icon = isCancel ? Icons.cancel_outlined : Icons.warning_amber_rounded;
    final text = isCancel ? 'Pedido cancelado' : 'Pedido retrasado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bg.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Palette.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: purple, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TrackStep {
  pendiente,
  aceptado,
  enCurso,
  completado,
  retrasado,
  cancelado,
}

class _BadgeMeta {
  final String label;
  final IconData icon;
  final Color bg;

  _BadgeMeta(this.label, this.icon, this.bg);
}

class _PaymentBadgeMeta {
  final String label;
  final IconData icon;
  final Color bg;

  _PaymentBadgeMeta({
    required this.label,
    required this.icon,
    required this.bg,
  });
}
