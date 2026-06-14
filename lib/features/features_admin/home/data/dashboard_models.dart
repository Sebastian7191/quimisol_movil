import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';

class DashboardStats {
  // pedidos
  final int pedidosTotal;
  final int pedidosPendientes;
  final int pedidosAceptados;
  final int pedidosEnCamino;
  final int pedidosEntregados;
  final int pedidosCancelados;

  final double ventasTotal;
  final double costoEnvioTotal;

  // productos
  final int productosTotal;
  final int productosStockBajo;
  final int productosStockCero;
  final Map<String, int> productosPorTipo;

  // usuarios
  final int usuariosTotal;

  // repartidores
  final int repartidoresTotal;

  // banners
  final int bannersTotal;
  final int bannersActivos;

  // listas para gráficos
  final List<PedidoMini> pedidosRecientes;
  final List<ProductoMini> productosLowStock;

  // listas completas para los dialogs de detalle
  final List<PedidoMini> pedidosTodos;
  final List<ProductoMini> productosTodos;
  final List<UsuarioMini> usuariosTodos;
  final List<RepartidorMini> repartidoresTodos;
  final List<BannerMini> bannersTodos;

  // datos para charts
  final Map<DateTime, int> pedidosPorDia;
  final Map<String, int> pedidosPorDepartamento;
  final Map<String, int> pedidosPorEstado;

  DashboardStats({
    required this.pedidosTotal,
    required this.pedidosPendientes,
    required this.pedidosAceptados,
    required this.pedidosEnCamino,
    required this.pedidosEntregados,
    required this.pedidosCancelados,
    required this.ventasTotal,
    required this.costoEnvioTotal,
    required this.productosTotal,
    required this.productosStockBajo,
    required this.productosStockCero,
    required this.productosPorTipo,
    required this.usuariosTotal,
    required this.repartidoresTotal,
    required this.bannersTotal,
    required this.bannersActivos,
    required this.pedidosRecientes,
    required this.productosLowStock,
    required this.pedidosTodos,
    required this.productosTodos,
    required this.usuariosTodos,
    required this.repartidoresTodos,
    required this.bannersTodos,
    required this.pedidosPorDia,
    required this.pedidosPorDepartamento,
    required this.pedidosPorEstado,
  });

  static DashboardStats build({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> pedidos,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> productos,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> usuarios,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> repartidores,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> banners,
    DateTime? rangeStart,
    int recentLimit = 6,
  }) {
    // ===== pedidos =====
    int pend = 0, acept = 0, enc = 0, entr = 0, canc = 0;
    double ventas = 0, envio = 0;

    final allPedidos = <PedidoMini>[];
    final porDia = <DateTime, int>{};
    final porDep = <String, int>{};
    final porEstado = <String, int>{};

    for (final d in pedidos) {
      final m = d.data();

      final estadoRaw = (m['estado'] ?? '').toString();
      final estado = normalizeEstado(estadoRaw);

      final dep = (m['departamento'] ?? '').toString().trim();
      if (dep.isNotEmpty) porDep[dep] = (porDep[dep] ?? 0) + 1;

      porEstado[estado.isEmpty ? '—' : estado] =
          (porEstado[estado.isEmpty ? '—' : estado] ?? 0) + 1;

      DateTime created = DateTime.fromMillisecondsSinceEpoch(0);
      final raw = m['createdAt'];
      if (raw is Timestamp) created = raw.toDate();
      if (raw is DateTime) created = raw;

      final dayKey = DateTime(created.year, created.month, created.day);
      if (rangeStart == null ||
          !dayKey.isBefore(
              DateTime(rangeStart.year, rangeStart.month, rangeStart.day))) {
        porDia[dayKey] = (porDia[dayKey] ?? 0) + 1;
      }

      final totalRaw = m['total'];
      final envioRaw = m['costo_envio'];

      ventas += _numToDouble(totalRaw);
      envio += _numToDouble(envioRaw);

      if (estado == kEstadoPendiente) {
        pend++;
      } else if (estado == kEstadoAceptado) {
        acept++;
      } else if (estado == kEstadoEnCamino) {
        enc++;
      } else if (estado == kEstadoEntregado) {
        entr++;
      } else if (estado == kEstadoCancelado) {
        canc++;
      }

      allPedidos.add(PedidoMini(
        id: d.id,
        codigo: (m['codigo'] ?? '').toString(),
        direccion: (m['direccion'] ?? '').toString(),
        departamento: dep,
        estado: estadoRaw,
        createdAt: created,
        total: _numToDouble(totalRaw),
        costoEnvio: _numToDouble(envioRaw),
        repartidorNombre: (m['repartidorNombre'] ?? '').toString(),
      ));
    }

    allPedidos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentCut = allPedidos.take(recentLimit).toList();

    // ===== productos =====
    final allProductos = <ProductoMini>[];
    final lowStock = <ProductoMini>[];
    int stockBajo = 0, stockCero = 0;
    final porTipo = <String, int>{};

    for (final d in productos) {
      final m = d.data();
      final nombre = (m['nombre'] ?? '').toString();
      final tipo = (m['tipoItem'] ?? '').toString().trim();
      porTipo[tipo.isEmpty ? 'Sin tipo' : tipo] =
          (porTipo[tipo.isEmpty ? 'Sin tipo' : tipo] ?? 0) + 1;

      final stock = _numToInt(m['stock']);
      final pm = ProductoMini(
        id: d.id,
        nombre: nombre.isEmpty ? d.id : nombre,
        stock: stock,
        tipo: tipo.isEmpty ? 'Sin tipo' : tipo,
        almacenNombre: (m['almacenNombre'] ?? '').toString(),
      );

      allProductos.add(pm);

      if (stock <= 5) {
        stockBajo++;
        if (stock <= 0) stockCero++;
        lowStock.add(pm);
      }
    }

    allProductos.sort((a, b) => a.nombre.compareTo(b.nombre));
    lowStock.sort((a, b) => a.stock.compareTo(b.stock));

    // ===== usuarios =====
    final allUsuarios = <UsuarioMini>[];
    for (final d in usuarios) {
      final m = d.data();
      allUsuarios.add(UsuarioMini(
        id: d.id,
        nombre: (m['nombre'] ?? m['name'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        rol: (m['role'] ?? m['rol'] ?? '').toString(),
      ));
    }
    allUsuarios.sort((a, b) => a.nombre.compareTo(b.nombre));

    // ===== repartidores =====
    final allRepartidores = <RepartidorMini>[];
    for (final d in repartidores) {
      final m = d.data();
      allRepartidores.add(RepartidorMini(
        id: d.id,
        nombre: (m['nombre'] ?? m['name'] ?? '').toString(),
        almacenNombre: (m['almacenNombre'] ?? '').toString(),
        disponible: m['disponible'] == true,
      ));
    }
    allRepartidores.sort((a, b) => a.nombre.compareTo(b.nombre));

    // ===== banners =====
    final allBanners = <BannerMini>[];
    int bannersAct = 0;
    for (final b in banners) {
      final m = b.data();
      final estado = (m['estado'] ?? '').toString().trim().toUpperCase();
      if (estado == 'ACTIVO') bannersAct++;
      allBanners.add(BannerMini(
        id: b.id,
        titulo: (m['titulo'] ?? m['title'] ?? '').toString(),
        estado: estado,
        imageUrl: (m['imageUrl'] ?? m['imagen'] ?? '').toString(),
      ));
    }

    return DashboardStats(
      pedidosTotal: pedidos.length,
      pedidosPendientes: pend,
      pedidosAceptados: acept,
      pedidosEnCamino: enc,
      pedidosEntregados: entr,
      pedidosCancelados: canc,
      ventasTotal: ventas,
      costoEnvioTotal: envio,
      productosTotal: productos.length,
      productosStockBajo: stockBajo,
      productosStockCero: stockCero,
      productosPorTipo: porTipo,
      usuariosTotal: usuarios.length,
      repartidoresTotal: repartidores.length,
      bannersTotal: banners.length,
      bannersActivos: bannersAct,
      pedidosRecientes: recentCut,
      productosLowStock: lowStock.take(8).toList(),
      pedidosTodos: allPedidos,
      productosTodos: allProductos,
      usuariosTodos: allUsuarios,
      repartidoresTodos: allRepartidores,
      bannersTodos: allBanners,
      pedidosPorDia: porDia,
      pedidosPorDepartamento: porDep,
      pedidosPorEstado: porEstado,
    );
  }

  static double _numToDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _numToInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }
}

class PedidoMini {
  final String id;
  final String codigo;
  final String direccion;
  final String departamento;
  final String estado;
  final DateTime createdAt;
  final double total;
  final double costoEnvio;
  final String repartidorNombre;

  PedidoMini({
    required this.id,
    required this.codigo,
    required this.direccion,
    required this.departamento,
    required this.estado,
    required this.createdAt,
    required this.total,
    this.costoEnvio = 0,
    required this.repartidorNombre,
  });
}

class ProductoMini {
  final String id;
  final String nombre;
  final int stock;
  final String tipo;
  final String almacenNombre;

  ProductoMini({
    required this.id,
    required this.nombre,
    required this.stock,
    this.tipo = '',
    required this.almacenNombre,
  });
}

class UsuarioMini {
  final String id;
  final String nombre;
  final String email;
  final String rol;

  const UsuarioMini({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
  });
}

class RepartidorMini {
  final String id;
  final String nombre;
  final String almacenNombre;
  final bool disponible;

  const RepartidorMini({
    required this.id,
    required this.nombre,
    required this.almacenNombre,
    required this.disponible,
  });
}

class BannerMini {
  final String id;
  final String titulo;
  final String estado;
  final String imageUrl;

  const BannerMini({
    required this.id,
    required this.titulo,
    required this.estado,
    this.imageUrl = '',
  });
}

List<DateTime> buildDayAxis(DateTime start, int days) {
  return List.generate(days, (i) {
    final d = start.add(Duration(days: i));
    return DateTime(d.year, d.month, d.day);
  });
}

int maxMapValue(Map<String, int> m) =>
    m.isEmpty ? 1 : m.values.fold(1, (a, b) => math.max(a, b));
