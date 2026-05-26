import 'package:flutter/foundation.dart';

class GuestStore {
  final ValueNotifier<bool> isGuest = ValueNotifier<bool>(false);

  void enterAsGuest() => isGuest.value = true;
  void exitGuest() => isGuest.value = false;

  bool get value => isGuest.value;

  void dispose() => isGuest.dispose();
}
