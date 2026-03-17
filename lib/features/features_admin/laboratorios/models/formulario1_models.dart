import 'package:flutter/material.dart';

class Formulario1DetalleItem {
  int item;
  final TextEditingController codigoMuestraEquipoCtrl;
  final TextEditingController cantidadCtrl;
  final TextEditingController descripcionCtrl;

  Formulario1DetalleItem({
    required this.item,
    String codigoMuestraEquipo = '',
    String cantidad = '',
    String descripcion = '',
  })  : codigoMuestraEquipoCtrl =
            TextEditingController(text: codigoMuestraEquipo),
        cantidadCtrl = TextEditingController(text: cantidad),
        descripcionCtrl = TextEditingController(text: descripcion);

  factory Formulario1DetalleItem.fromMap(Map<String, dynamic> map) {
    return Formulario1DetalleItem(
      item: (map['item'] as num?)?.toInt() ?? 1,
      codigoMuestraEquipo: (map['codigoMuestraEquipo'] ?? '').toString(),
      cantidad: (map['cantidad'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item': item,
      'codigoMuestraEquipo': codigoMuestraEquipoCtrl.text.trim(),
      'cantidad': cantidadCtrl.text.trim(),
      'descripcion': descripcionCtrl.text.trim(),
    };
  }

  void dispose() {
    codigoMuestraEquipoCtrl.dispose();
    cantidadCtrl.dispose();
    descripcionCtrl.dispose();
  }
}

class Formulario1CriterioItem {
  final TextEditingController criterioCtrl;
  String? respuesta;

  Formulario1CriterioItem({
    String criterio = '',
    this.respuesta,
  }) : criterioCtrl = TextEditingController(text: criterio);

  factory Formulario1CriterioItem.fromMap(Map<String, dynamic> map) {
    final rawRespuesta = map['respuesta']?.toString().trim();
    final respuestaNormalizada = _normalizarRespuesta(rawRespuesta);

    return Formulario1CriterioItem(
      criterio: (map['criterio'] ?? '').toString(),
      respuesta: respuestaNormalizada,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'criterio': criterioCtrl.text.trim(),
      'respuesta': _normalizarRespuesta(respuesta) ?? '',
    };
  }

  void dispose() {
    criterioCtrl.dispose();
  }
}

class Formulario1EvaluacionItem {
  final TextEditingController preguntaCtrl;
  String? respuesta;

  Formulario1EvaluacionItem({
    String pregunta = '',
    this.respuesta,
  }) : preguntaCtrl = TextEditingController(text: pregunta);

  factory Formulario1EvaluacionItem.fromMap(Map<String, dynamic> map) {
    final rawRespuesta = map['respuesta']?.toString().trim();
    final respuestaNormalizada = _normalizarRespuesta(rawRespuesta);

    return Formulario1EvaluacionItem(
      pregunta: (map['pregunta'] ?? '').toString(),
      respuesta: respuestaNormalizada,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pregunta': preguntaCtrl.text.trim(),
      'respuesta': _normalizarRespuesta(respuesta) ?? '',
    };
  }

  void dispose() {
    preguntaCtrl.dispose();
  }
}

String? _normalizarRespuesta(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final v = value.trim().toUpperCase();
  if (v == 'SI' || v == 'SÍ') return 'SI';
  if (v == 'NO') return 'NO';

  return null;
}