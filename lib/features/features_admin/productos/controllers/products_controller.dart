// lib/features/productos/controllers/products_controller.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:quimisol_movil/features/features_admin/productos/data/producto_dialog_result.dart';

import '../data/producto_row.dart';
import '../data/form_result.dart';

class ProductosController {
  final _db = FirebaseFirestore.instance;

  final FirebaseStorage storage = FirebaseStorage.instanceFor(
    bucket: 'gs://quimisol-4f159.firebasestorage.app',
  );

  CollectionReference<Map<String, dynamic>> get productosRef =>
      _db.collection('productos');

  CollectionReference<Map<String, dynamic>> get unidadesRef =>
      _db.collection('unidades');

  CollectionReference<Map<String, dynamic>> get almacenesRef =>
      _db.collection('almacenes');

  // ✅ NUEVO: banners
  CollectionReference<Map<String, dynamic>> get bannersRef =>
      _db.collection('banners');

  Stream<QuerySnapshot<Map<String, dynamic>>> productosStream() =>
      productosRef.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> unidadesStream() =>
      unidadesRef.snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> almacenesStream() =>
      almacenesRef.snapshots();

  // ===========================================================================
  // ✅ MAP PRODUCTO (incluye categoría)
  // ===========================================================================
  ProductoRow mapProducto(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};

    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : null;

    final precioRaw = data['precio'];
    final precio = (precioRaw is num) ? precioRaw.toDouble() : 0.0;

    final stockRaw = data['stock'];
    final stock = (stockRaw is num) ? stockRaw.toInt() : 0;

    return ProductoRow(
      id: d.id,
      codigo: (data['codigo'] ?? '').toString(),
      nombre: (data['nombre'] ?? '').toString(),
      tipoItem: (data['tipoItem'] ?? 'PRODUCTO').toString(),
      unidadId: (data['unidadId'] ?? '').toString(),
      unidadNombre: (data['unidadNombre'] ?? '').toString(),
      descripcion: (data['descripcion'] ?? '').toString(),
      precio: precio,
      stock: stock,
      createdAt: createdAt,
      imagenUrl: (data['imagenUrl'] ?? '').toString(),
      imagenPath: (data['imagenPath'] ?? '').toString(),
      almacenId: (data['almacenId'] ?? '').toString(),
      almacenNombre: (data['almacenNombre'] ?? '').toString(),

      // ✅ NUEVO: categoría (si en Firestore no existe, queda '')
      categoriaId: (data['categoriaId'] ?? '').toString(),
      categoriaNombre: (data['categoriaNombre'] ?? '').toString(),
    );
  }

  List<ProductoRow> filterProductos({
    required List<ProductoRow> rows,
    required String search,
    required String tipo,
  }) {
    final q = search.trim().toLowerCase();

    final byTipo = tipo == 'Todos'
        ? rows
        : rows.where((r) => r.tipoItem == tipo).toList();

    if (q.isEmpty) return byTipo;

    return byTipo.where((r) {
      return r.codigo.toLowerCase().contains(q) ||
          r.nombre.toLowerCase().contains(q);
    }).toList();
  }

 
  // IMÁGENES
  String sanitizeFilename(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'\s+'), '_');
    if (cleaned.isEmpty) return 'imagen.png';
    return cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
  }

  String guessExtFromBytes(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'jpg';
  }

  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'png';
  }

  return 'png';
}

  Future<Map<String, String>> uploadImage({
    required String productId,
    required Uint8List bytes,
    String? filename,
  }) async {
    final ext = guessExtFromBytes(bytes);
    final safeName = sanitizeFilename(filename ?? 'imagen.$ext');
    final path = 'productos_e_insumos/$productId/$safeName';

    final ref = storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
    final url = await ref.getDownloadURL();

    return {'url': url, 'path': path};
  }

  Future<void> deleteImage(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      await storage.ref().child(path).delete();
    } catch (_) {}
  }

  // ===========================================================================
  // ✅ DESCUENTO (SUBCOLECCIÓN)
  // Ruta: productos/{productId}/descuentos/activo
  // ===========================================================================
  DocumentReference<Map<String, dynamic>> _descuentoActivoRef(String productId) {
    return productosRef.doc(productId).collection('descuentos').doc('activo');
  }

  Future<void> _upsertDescuento({
    required String productId,
    required DescuentoDraft? descuento,
  }) async {
    final ref = _descuentoActivoRef(productId);

    // Si no hay descuento => lo marcamos inactivo y limpiamos campos
    if (descuento == null || !descuento.isValid) {
      await ref.set({
        'activo': false,
        'tipo': FieldValue.delete(),
        'valor': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    // Mantener createdAt solo la primera vez
    final snap = await ref.get();
    final base = <String, dynamic>{
      'activo': true,
      'tipo': descuento.tipo,
      'valor': descuento.valor,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      base['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(base, SetOptions(merge: true));
  }

  // ===========================================================================
  // ✅ BANNER PROMO (colección banners)
  // Doc: banners/{productoId}
  // Campos: titulo, subtitulo, imagen, estado(ACTIVO/INACTIVO), idproducto
  // ===========================================================================
  String _bannerSubtitleFrom(DescuentoDraft? d) {
    if (d == null || !d.isValid) return '';
    if (d.tipo == 'PORCENTAJE') {
      final v = d.valor;
      final txt = (v % 1 == 0) ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
      return '$txt%';
    }
    return 'Bs ${d.valor.toStringAsFixed(2)}';
  }

  Future<void> _syncBanner({
    required String productoId,
    required String titulo,
    required String imagenUrl,
    required bool enabled,
    required DescuentoDraft? descuento,
  }) async {
    final ref = bannersRef.doc(productoId);

    // OFF: marcar INACTIVO solo si existe (no crear doc nuevo)
    if (!enabled) {
      final snap = await ref.get();
      if (snap.exists) {
        await ref.set({'estado': 'INACTIVO'}, SetOptions(merge: true));
      }
      return;
    }

    // ON: crear/actualizar con todos los campos
    await ref.set({
      'titulo': titulo.trim(),
      'subtitulo': _bannerSubtitleFrom(descuento),
      'imagen': imagenUrl.trim(),
      'estado': 'ACTIVO',
      'idproducto': productoId,
      'updatedAt': FieldValue.serverTimestamp(),

      // con merge:true no "pisa" si ya existe
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===========================================================================
  // ✅ CREAR / ACTUALIZAR con descuento + banner + categoría
  // IMPORTANTE: para que se guarde categoriaId/categoriaNombre,
  // tu ProductoFormResult debe tener estos campos:
  //   final String? categoriaId;
  //   final String? categoriaNombre;
  // ===========================================================================
  Future<void> crearProducto(
    ProductoFormResult r, {
    DescuentoDraft? descuento,
    bool promoBannerEnabled = false,
  }) async {
    final doc = productosRef.doc();
    final id = doc.id;

    String url = '';
    String path = '';

    if (r.imageBytes != null) {
      final up = await uploadImage(
        productId: id,
        bytes: r.imageBytes!,
        filename: r.imageName,
      );
      url = up['url']!;
      path = up['path']!;
    }

    final data = <String, dynamic>{
      'codigo': r.codigo.trim(),
      'nombre': r.nombre.trim(),
      'descripcion': r.descripcion.trim(),
      'tipoItem': r.tipoItem,
      'unidadId': r.unidadId,
      'unidadNombre': r.unidadNombre,
      'precio': r.precio,
      'stock': r.stock,
      'imagenUrl': url,
      'imagenPath': path,
      'almacenId': r.almacenId,
      'almacenNombre': r.almacenNombre,
      'activo': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // ✅ categoría (solo si eligió una)
    if (r.categoriaId != null && r.categoriaId!.trim().isNotEmpty) {
      data['categoriaId'] = r.categoriaId!.trim();
      data['categoriaNombre'] = (r.categoriaNombre ?? '').trim();
    }

    await doc.set(data);

    // ✅ descuento
    await _upsertDescuento(productId: id, descuento: descuento);

    // ✅ banner (usa url final)
    await _syncBanner(
      productoId: id,
      titulo: r.nombre,
      imagenUrl: url,
      enabled: promoBannerEnabled,
      descuento: descuento,
    );
  }

  Future<void> actualizarProducto(
    String id,
    ProductoFormResult r, {
    String? existingImagenUrl,
    String? existingImagenPath,
    DescuentoDraft? descuento,
    bool promoBannerEnabled = false,
  }) async {
    String url = existingImagenUrl ?? '';
    String path = existingImagenPath ?? '';

    if (r.imageBytes != null) {
      if (path.trim().isNotEmpty) await deleteImage(path);

      final up = await uploadImage(
        productId: id,
        bytes: r.imageBytes!,
        filename: r.imageName,
      );
      url = up['url']!;
      path = up['path']!;
    }

    final update = <String, dynamic>{
      'codigo': r.codigo.trim(),
      'nombre': r.nombre.trim(),
      'descripcion': r.descripcion.trim(),
      'tipoItem': r.tipoItem,
      'unidadId': r.unidadId,
      'unidadNombre': r.unidadNombre,
      'precio': r.precio,
      'stock': r.stock,
      'imagenUrl': url,
      'imagenPath': path,
      'almacenId': r.almacenId,
      'almacenNombre': r.almacenNombre,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // ✅ categoría: set o delete
    if (r.categoriaId != null && r.categoriaId!.trim().isNotEmpty) {
      update['categoriaId'] = r.categoriaId!.trim();
      update['categoriaNombre'] = (r.categoriaNombre ?? '').trim();
    } else {
      update['categoriaId'] = FieldValue.delete();
      update['categoriaNombre'] = FieldValue.delete();
    }

    await productosRef.doc(id).update(update);

    // ✅ descuento
    await _upsertDescuento(productId: id, descuento: descuento);

    // ✅ banner (usa url final)
    await _syncBanner(
      productoId: id,
      titulo: r.nombre,
      imagenUrl: url,
      enabled: promoBannerEnabled,
      descuento: descuento,
    );
  }

  Future<void> eliminarProducto(String id, String? imagenPath) async {
    await productosRef.doc(id).delete();
    await deleteImage(imagenPath);

    // opcional: borrar descuento
    try {
      await _descuentoActivoRef(id).delete();
    } catch (_) {}

    // opcional: marcar banner inactivo (o borrar)
    try {
      final ref = bannersRef.doc(id);
      final snap = await ref.get();
      if (snap.exists) {
        await ref.set({'estado': 'INACTIVO'}, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}
