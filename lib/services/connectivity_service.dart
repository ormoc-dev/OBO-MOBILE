import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool _isConnected = true;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  // Get current connection status
  bool get isConnected => _isConnected;
  
  // Stream of connection status changes
  Stream<bool> get connectionStream => _connectionController.stream;

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  // Check current connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  // Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    _updateConnectionStatus(result);
  }

  // Update connection status
  void _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    // Only notify if status changed
    if (wasConnected != _isConnected) {
      _connectionController.add(_isConnected);
    }
  }

  // Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}
