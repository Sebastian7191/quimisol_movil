import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quimisol_movil/core/constants/pedido_estado.dart';
import '../data/pedido_row.dart';
import '../data/depto_section.dart';

class PedidosController {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> pedidosStream() {
    return _db
        .collection('pedidos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Filtro principal
  // adminDepto: si es null → superadmin (ve todo); si tiene valor → solo ese dpto.
  List<PedidoRow> filterPedidos({
    required List<PedidoRow> pedidos,
    required String query,
    required String estado,
    String? adminDepto,
  }) {
    final q = query.trim().toLowerCase();
    final deptoFilter = adminDepto?.trim().toLowerCase();

    return pedidos.where((p) {
      // ✅ Restricción por departamento del admin (superadmin ve todo)
      if (deptoFilter != null && deptoFilter.isNotEmpty) {
        if (p.departamento.trim().toLowerCase() != deptoFilter) return false;
      }
      // ✅ p.estado viene crudo de Firestore (ej. "entregado"); hay que
      // normalizarlo al estado canónico (ej. "Entregado") antes de comparar.
      if (estado != 'Todos' && normalizeEstado(p.estado) != estado) return false;
      if (q.isEmpty) return true;

      return p.codigo.toLowerCase().contains(q) ||
          p.direccion.toLowerCase().contains(q) ||
          p.departamento.toLowerCase().contains(q) ||
          p.tipoPago.toLowerCase().contains(q) ||
          p.estadoPago.toLowerCase().contains(q);
    }).toList();
  }

  // ✅ true si el pedido ya fue entregado (comparación por estado canónico)
  bool isEntregado(PedidoRow p) => normalizeEstado(p.estado) == kEstadoEntregado;

  // Agrupar por depa
  List<DeptoSection> groupByDepartamento(List<PedidoRow> pedidos) {
    final Map<String, List<PedidoRow>> map = {};

    for (final p in pedidos) {
      final key = p.departamento.trim().isEmpty
          ? 'Sin departamento'
          : p.departamento;
      (map[key] ??= []).add(p);
    }

    final keys = map.keys.toList()
      ..sort((a, b) {
        if (a == 'Sin departamento') return 1;
        if (b == 'Sin departamento') return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return keys
        .map((k) => DeptoSection(departamento: k, pedidos: map[k]!))
        .toList();
  }

  // Convierte un documento de Firestore a PedidoRow y añade labels preformateadas
  PedidoRow parsePedidoRow(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final row = PedidoRow.fromDoc(d);
    final fecha = formatTs(row.createdAt);
    final total = money(row.totalFinal);
    return row.copyWith(fechaLabel: fecha, totalLabel: total);
  }

  // Formato de moneda
  String money(double v) {
    final s = v.toStringAsFixed(2);
    return "$s Bs";
  }

  // Formatea una fecha legible desde DateTime
  String formatTs(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}