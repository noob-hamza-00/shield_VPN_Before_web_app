import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Stream<bool> get onConnectionChanged => _controller.stream;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // If any result is not none, we have internet
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      _controller.add(hasConnection);
    });
  }

  void dispose() {
    _controller.close();
  }
}
