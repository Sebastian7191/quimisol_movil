import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quimisol_movil/core/theme/palette.dart';

/// Pide al usuario una cantidad escrita a mano. Devuelve null si cancela.
///
/// Si se pasa [disponible] (stock), muestra en rojo cuántas unidades hay y
/// no deja aceptar mientras la cantidad escrita lo supere. Con null no hay
/// tope (stock desconocido).
///
/// El controller vive dentro del diálogo (y se libera en su `dispose`) porque
/// el TextField sigue montado durante la animación de cierre: liberarlo justo
/// después de `showDialog` rompe el árbol de widgets.
Future<int?> showCantidadDialog(
  BuildContext context, {
  required int inicial,
  int? disponible,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _CantidadDialog(inicial: inicial, disponible: disponible),
  );
}

class _CantidadDialog extends StatefulWidget {
  const _CantidadDialog({required this.inicial, this.disponible});

  final int inicial;
  final int? disponible;

  @override
  State<_CantidadDialog> createState() => _CantidadDialogState();
}

class _CantidadDialogState extends State<_CantidadDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final txt = '${widget.inicial}';
    _ctrl = TextEditingController(text: txt)
      ..selection = TextSelection(baseOffset: 0, extentOffset: txt.length);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int? get _valor => int.tryParse(_ctrl.text.trim());

  bool get _excede {
    final max = widget.disponible;
    final v = _valor;
    return max != null && v != null && v > max;
  }

  bool get _valido {
    final v = _valor;
    return v != null && v >= 1 && !_excede;
  }

  String get _avisoStock {
    final max = widget.disponible ?? 0;
    if (max <= 0) return 'No hay unidades disponibles de este producto.';
    return 'Solo tenemos $max unidad${max == 1 ? '' : 'es'} '
        'disponible${max == 1 ? '' : 's'}.';
  }

  void _confirmar() {
    if (!_valido) return;
    FocusScope.of(context).unfocus();
    Navigator.pop(context, _valor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cantidad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            onSubmitted: (_) => _confirmar(),
          ),
          if (_excede) ...[
            const SizedBox(height: 10),
            Text(
              _avisoStock,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _valido ? _confirmar : null,
          child: Text(
            'Aceptar',
            style: TextStyle(
              color: _valido
                  ? Palette.button
                  : Palette.ink.withValues(alpha: 0.30),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
