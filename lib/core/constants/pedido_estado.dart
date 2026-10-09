
/* ===================== ESTADOS (CANÓNICOS) ===================== */

const String kEstadoPendiente = 'Pendiente';
const String kEstadoAceptado = 'Aceptado';
const String kEstadoEnCamino = 'En camino';
const String kEstadoEntregado = 'Entregado';
const String kEstadoCancelado = 'Cancelado';

const List<String> kEstadosValidos = [
  kEstadoPendiente,
  kEstadoAceptado,
  kEstadoEnCamino,
  kEstadoEntregado,
  kEstadoCancelado,
];

String normalizeEstado(dynamic v) {
  final s = (v ?? '').toString().trim().toLowerCase();

  if (s.isEmpty) return kEstadoPendiente;

  if (s == 'aceptado' || s == 'aceptada' || s == 'Aceptado') return kEstadoAceptado;

  if (
    s == 'en camino' || s == 'encamino' || s == 'en_camino' || s == 'En camino'
  ) {
    return kEstadoEnCamino;
  }

  if (s == 'entregado') return kEstadoEntregado;
  if (s == 'cancelado') return kEstadoCancelado;
  if (s == 'pendiente') return kEstadoPendiente;

  // fallback SEGURO
  return kEstadoPendiente;
}