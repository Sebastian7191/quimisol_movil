import 'pedido_row.dart';

class DeptoSection {
  final String departamento;
  final List<PedidoRow> pedidos;

  const DeptoSection({
    required this.departamento,
    required this.pedidos,
  });
}