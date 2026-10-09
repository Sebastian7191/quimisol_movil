import 'package:flutter/material.dart';

class MuestraFormItem {
  int no;
  final TextEditingController codigoMuestraCtrl;
  final TextEditingController cantidadCtrl;
  final TextEditingController volumenPesoCtrl;
  final TextEditingController descripcionCtrl;
  final TextEditingController numeroLaboratorioCtrl;
  String? tipoMuestra;
  String? tipoEnvase;

  MuestraFormItem({
    required this.no,
    String codigoMuestra = '',
    String cantidad = '',
    String volumenPeso = '',
    String descripcion = '',
    String numeroLaboratorio = '',
    this.tipoMuestra,
    this.tipoEnvase,
  })  : codigoMuestraCtrl = TextEditingController(text: codigoMuestra),
        cantidadCtrl = TextEditingController(text: cantidad),
        volumenPesoCtrl = TextEditingController(text: volumenPeso),
        descripcionCtrl = TextEditingController(text: descripcion),
        numeroLaboratorioCtrl = TextEditingController(text: numeroLaboratorio);

  factory MuestraFormItem.fromMap(
    Map<String, dynamic> map, {
    required List<String> tiposMuestraValidos,
    required List<String> tiposEnvaseValidos,
  }) {
    final tipoMuestraRaw = map['tipoMuestra']?.toString().trim();
    final tipoEnvaseRaw = map['tipoEnvase']?.toString().trim();

    return MuestraFormItem(
      no: (map['no'] ?? 1) as int,
      codigoMuestra: (map['codigoMuestra'] ?? '').toString(),
      cantidad: (map['cantidad'] ?? '').toString(),
      volumenPeso: (map['volumenPeso'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      numeroLaboratorio: (map['numeroLaboratorio'] ?? '').toString(),
      tipoMuestra: tiposMuestraValidos.contains(tipoMuestraRaw)
          ? tipoMuestraRaw
          : null,
      tipoEnvase:
          tiposEnvaseValidos.contains(tipoEnvaseRaw) ? tipoEnvaseRaw : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'no': no,
      'codigoMuestra': codigoMuestraCtrl.text.trim(),
      'tipoMuestra': tipoMuestra ?? '',
      'cantidad': cantidadCtrl.text.trim(),
      'volumenPeso': volumenPesoCtrl.text.trim(),
      'tipoEnvase': tipoEnvase ?? '',
      'descripcion': descripcionCtrl.text.trim(),
      'numeroLaboratorio': numeroLaboratorioCtrl.text.trim(),
    };
  }

  void dispose() {
    codigoMuestraCtrl.dispose();
    cantidadCtrl.dispose();
    volumenPesoCtrl.dispose();
    descripcionCtrl.dispose();
    numeroLaboratorioCtrl.dispose();
  }
}

class ChecklistFormItem {
  final TextEditingController ordenCtrl;
  final TextEditingController detalleCtrl;
  final TextEditingController observacionesCtrl;
  String? cumple;

  ChecklistFormItem({
    int orden = 1,
    String detalle = '',
    this.cumple,
    String observaciones = '',
  })  : ordenCtrl = TextEditingController(text: '$orden'),
        detalleCtrl = TextEditingController(text: detalle),
        observacionesCtrl = TextEditingController(text: observaciones);

  factory ChecklistFormItem.fromMap(
    Map<String, dynamic> map, {
    required List<String> cumpleValidos,
  }) {
    final cumpleRaw = map['cumple']?.toString().trim();

    return ChecklistFormItem(
      orden: int.tryParse((map['orden'] ?? '1').toString()) ?? 1,
      detalle: (map['detalle'] ?? '').toString(),
      cumple: cumpleValidos.contains(cumpleRaw) ? cumpleRaw : null,
      observaciones: (map['observaciones'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orden': int.tryParse(ordenCtrl.text.trim()) ?? 0,
      'detalle': detalleCtrl.text.trim(),
      'cumple': cumple ?? '',
      'observaciones': observacionesCtrl.text.trim(),
    };
  }

  void dispose() {
    ordenCtrl.dispose();
    detalleCtrl.dispose();
    observacionesCtrl.dispose();
  }
}