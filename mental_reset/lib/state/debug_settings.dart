import 'package:flutter/foundation.dart';

/// Переключатель аварии mock-репозитория (виден в Профиле).
class DebugSettings extends ChangeNotifier {
  bool _simulateFailure = false;
  bool get simulateFailure => _simulateFailure;

  void setSimulateFailure(bool value) {
    _simulateFailure = value;
    notifyListeners();
  }
}
