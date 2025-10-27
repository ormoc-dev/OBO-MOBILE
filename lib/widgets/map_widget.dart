import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapWidget extends StatefulWidget {
  final Function(LatLng)? onLocationSelected;
  final LatLng? initialLocation;
  final String? title;
  
  const MapWidget({
    super.key,
    this.onLocationSelected,
    this.initialLocation,
    this.title,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    // Delay location request to ensure map is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      _getCurrentLocation();
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Location services are disabled.');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permissions are denied.');
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Location permissions are permanently denied.');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_selectedLocation == null) {
          _selectedLocation = _currentLocation;
        }
        _isLoadingLocation = false;
      });

      // Move map to current location
      try {
        _mapController.move(_currentLocation!, 15.0);
      } catch (e) {
        // If map controller is not ready, wait a bit and try again
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            _mapController.move(_currentLocation!, 15.0);
          } catch (e) {
            print('Failed to move map: $e');
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      _showLocationError('Failed to get current location: $e');
    }
  }

  void _showLocationError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(point);
    }
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      try {
        _mapController.move(_currentLocation!, 15.0);
        setState(() {
          _selectedLocation = _currentLocation;
        });
        if (widget.onLocationSelected != null) {
          widget.onLocationSelected!(_currentLocation!);
        }
      } catch (e) {
        print('Failed to center on current location: $e');
      }
    } else {
      // Try to get current location again
      _getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Container(
      height: isTablet ? 400 : 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation ?? const LatLng(10.3157, 123.8854), // Default to Ormoc City
                initialZoom: 15.0,
                onTap: _onMapTap,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // Tile Layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ormoc.obo_mobile',
                  maxZoom: 18,
                  minZoom: 1,
                  tileBuilder: (context, tileWidget, tile) {
                    return tileWidget;
                  },
                  errorTileCallback: (tile, error, stackTrace) {
                    print('Tile loading error: $error');
                  },
                ),
                
                // Markers Layer
                MarkerLayer(
                  markers: [
                    // Current location marker
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    
                    // Selected location marker
                    if (_selectedLocation != null)
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            // Loading overlay
            if (_isLoadingLocation)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            
            // Controls
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                children: [
                  // Center on current location button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isLoadingLocation ? null : _centerOnCurrentLocation,
                      icon: _isLoadingLocation 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                      tooltip: _isLoadingLocation ? 'Getting location...' : 'Center on current location',
                    ),
                  ),
                ],
              ),
            ),
            
            // Location info
            if (_selectedLocation != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title ?? 'Selected Location',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
