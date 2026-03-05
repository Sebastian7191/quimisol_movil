import 'package:flutter/material.dart';

enum DashboardRange { today, last7, last30, all }

class DashboardController extends ChangeNotifier {
  DashboardRange range = DashboardRange.last7;

  String? estado;        // Ej: "pendiente", "aceptado", "en camino", "entregado"
  String? departamento;  // Ej: "Cochabamba"
  String? almacenId;     // Para productos/repartidores

  void setRange(DashboardRange v) {
    range = v;
    notifyListeners();
  }

  void setEstado(String? v) {
    estado = (v == null || v.trim().isEmpty) ? null : v;
    notifyListeners();
  }

  void setDepartamento(String? v) {
    departamento = (v == null || v.trim().isEmpty) ? null : v;
    notifyListeners();
  }

  void setAlmacen(String? v) {
    almacenId = (v == null || v.trim().isEmpty) ? null : v;
    notifyListeners();
  }

  void clear() {
    range = DashboardRange.last7;
    estado = null;
    departamento = null;
    almacenId = null;
    notifyListeners();
  }

  DateTime? get rangeStart {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    switch (range) {
      case DashboardRange.today:
        return today0;
      case DashboardRange.last7:
        return today0.subtract(const Duration(days: 6));
      case DashboardRange.last30:
        return today0.subtract(const Duration(days: 29));
      case DashboardRange.all:
        return null;
    }
  }
}
