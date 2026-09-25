import 'package:cloud_firestore/cloud_firestore.dart';

/// Obtiene el nombre real de un usuario a partir de su documento en
/// `usuarios`, sin importar con qué campo se guardó (name, nombre, etc.).
class UserNameResolver {
  UserNameResolver._();

  static const _generic = {
    '',
    'cliente',
    'usuario',
    'nombre',
    'sin nombre',
    'null',
    '—',
    '-',
  };

  /// true si el texto está vacío o es un placeholder ("Cliente", "Usuario"...).
  static bool isGeneric(String? value) =>
      _generic.contains((value ?? '').trim().toLowerCase());

  static String _s(dynamic v) => (v ?? '').toString().trim();

  /// Nombre real desde los datos del usuario, o null si no tiene ninguno.
  static String? fromData(Map<String, dynamic> data) {
    for (final key in const [
      'name',
      'nombre',
      'displayName',
      'fullName',
      'nombreCompleto',
      'nombre_completo',
    ]) {
      final v = _s(data[key]);
      if (!isGeneric(v)) return v;
    }

    final compuesto = [
      _s(data['nombres']),
      _s(data['apellidos']),
    ].where((e) => e.isNotEmpty).join(' ');
    if (!isGeneric(compuesto)) return compuesto;

    return null;
  }

  /// Parte del correo antes de la @ (último recurso para mostrar algo útil).
  static String? fromEmail(String? email) {
    final e = (email ?? '').trim();
    if (!e.contains('@')) return null;
    final local = e.split('@').first.trim();
    return local.isEmpty ? null : local;
  }

  /// Nombre para mostrar: nombre real > parte del correo > [fallback].
  static String display(Map<String, dynamic> data, {String fallback = 'Usuario'}) {
    return fromData(data) ?? fromEmail(_s(data['email'])) ?? fallback;
  }

  static final Map<String, Future<String?>> _cache = {};

  /// Busca el nombre en `usuarios/{uid}` (con cache). Devuelve null si no hay.
  static Future<String?> byUid(String uid) {
    final id = uid.trim();
    if (id.isEmpty) return Future.value(null);
    return _cache.putIfAbsent(id, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(id)
            .get();
        final data = doc.data() ?? {};
        return fromData(data) ?? fromEmail(_s(data['email']));
      } catch (_) {
        _cache.remove(id);
        return null;
      }
    });
  }
}
