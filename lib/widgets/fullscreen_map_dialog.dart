import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../utils/location_service.dart';

class FullscreenMapDialog extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;
  final bool enableLocationPicker;
  final bool showSearchBar;
  final bool showAddressInfo;

  const FullscreenMapDialog({
    super.key,
    this.initialLocation,
    required this.title,
    this.enableLocationPicker = true,
    this.showSearchBar = true,
    this.showAddressInfo = true,
  });

  @override
  State<FullscreenMapDialog> createState() => _FullscreenMapDialogState();
}

class _FullscreenMapDialogState extends State<FullscreenMapDialog> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  bool _isSearching = false;
  bool _isSatelliteView = false;
  String? _selectedAddress;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    
    // Add listener to search controller
    _searchController.addListener(_onSearchTextChanged);
    
    // Delay location request to ensure map is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final result = await LocationService.getCurrentLocation();

      if (result.success && result.location != null) {
        setState(() {
          _currentLocation = result.location!;
          if (_selectedLocation == null) {
            _selectedLocation = _currentLocation;
          }
          _isLoadingLocation = false;
        });

        // Move map to current location with appropriate zoom level
        try {
          _mapController.move(_currentLocation!, 18.0);
        } catch (e) {
          // If map controller is not ready, wait a bit and try again
          Future.delayed(const Duration(milliseconds: 500), () {
            try {
              _mapController.move(_currentLocation!, 18.0);
            } catch (e) {
              print('Failed to move map: $e');
            }
          });
        }

        // Show success message with accuracy info
        if (mounted) {
          String message = 'Location found! Accuracy: ${result.accuracy?.toStringAsFixed(1)}m';
          if (result.warning != null) {
            message += '\n${result.warning}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: result.warning != null ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isLoadingLocation = false;
        });
        _showLocationError(result.error ?? 'Failed to get current location');
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      _showLocationError('Unexpected error: $e');
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

  Future<void> _getAddressForLocation(LatLng location) async {
    try {
      // Simple reverse geocoding using OpenStreetMap Nominatim API
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1'),
        headers: {
          'User-Agent': 'OBO-Mobile/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          setState(() {
            _selectedAddress = data['display_name'];
          });
        }
      }
    } catch (e) {
      print('Failed to get address: $e');
      // Don't show error to user as this is not critical
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Try multiple search providers for better coverage
      final location = await _searchWithMultipleProviders(query);
      
      if (location != null) {
        setState(() {
          _selectedLocation = location;
          _isSearching = false;
        });

        // Move map to searched location
        _mapController.move(location, 16.0);

        // Try to get address for the found location
        if (widget.showAddressInfo) {
          _getAddressForLocation(location);
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found location: ${LocationService.formatCoordinates(location)}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isSearching = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not found. Try searching for:\n• Street names\n• Landmarks\n• City names\n• Or tap directly on the map'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<LatLng?> _searchWithMultipleProviders(String query) async {
    // Provider 1: OpenStreetMap Nominatim (Primary)
    try {
      final result = await _searchNominatim(query);
      if (result != null) return result;
    } catch (e) {
      print('Nominatim search failed: $e');
    }

    // Provider 2: Try with different search parameters
    try {
      final result = await _searchNominatim(query, countryCode: 'ph'); // Philippines
      if (result != null) return result;
    } catch (e) {
      print('Nominatim PH search failed: $e');
    }

    // Provider 3: Try with broader search
    try {
      final result = await _searchNominatim(query, limit: 5);
      if (result != null) return result;
    } catch (e) {
      print('Nominatim broad search failed: $e');
    }

    // Provider 4: Try searching for nearby areas if current location is available
    if (_currentLocation != null) {
      try {
        final result = await _searchNearby(query);
        if (result != null) return result;
      } catch (e) {
        print('Nearby search failed: $e');
      }
    }

    return null;
  }

  Future<LatLng?> _searchNominatim(String query, {String? countryCode, int limit = 1}) async {
    String url = 'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=$limit&addressdetails=1';
    
    if (countryCode != null) {
      url += '&countrycodes=$countryCode';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'OBO-Mobile/1.0',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> results = json.decode(response.body);
      if (results.isNotEmpty) {
        final result = results.first;
        final lat = double.parse(result['lat']);
        final lon = double.parse(result['lon']);
        return LatLng(lat, lon);
      }
    }
    return null;
  }

  Future<LatLng?> _searchNearby(String query) async {
    // Search within a 50km radius of current location
    final response = await http.get(
      Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=1&addressdetails=1&bounded=1&viewbox=${_currentLocation!.longitude - 0.5},${_currentLocation!.latitude - 0.5},${_currentLocation!.longitude + 0.5},${_currentLocation!.latitude + 0.5}'),
      headers: {
        'User-Agent': 'OBO-Mobile/1.0',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> results = json.decode(response.body);
      if (results.isNotEmpty) {
        final result = results.first;
        final lat = double.parse(result['lat']);
        final lon = double.parse(result['lon']);
        return LatLng(lat, lon);
      }
    }
    return null;
  }

  void _toggleSatelliteView() {
    setState(() {
      _isSatelliteView = !_isSatelliteView;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSatelliteView ? 'Switched to Satellite View' : 'Switched to Standard View'),
          backgroundColor: _isSatelliteView ? const Color(0xFF4285F4) : const Color(0xFF34A853),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _onSearchTextChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when text changes
      });
    }
  }

  bool get _hasSearchTextSafe {
    try {
      return _searchController.text.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Widget _buildSearchSuggestion(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!widget.enableLocationPicker) return;
    
    setState(() {
      _selectedLocation = point;
      _selectedAddress = null; // Clear previous address
    });

    // Show confirmation message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location selected: ${LocationService.formatCoordinates(point)}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Try to get address for the selected location
    if (widget.showAddressInfo) {
      _getAddressForLocation(point);
    }
  }

  void _openGoogleMaps(LatLng location) async {
    final lat = location.latitude;
    final lng = location.longitude;
    
    // Show loading message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening Google Maps...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Create Google Maps URL
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    
    try {
      // Platform-specific handling
      if (kIsWeb) {
        // For web platform, use window.open equivalent
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // For mobile platforms, try different approaches
        bool launched = false;
        
        // Try Android intent first
        try {
          final androidUrl = 'geo:$lat,$lng?q=$lat,$lng';
          if (await canLaunchUrl(Uri.parse(androidUrl))) {
            await launchUrl(Uri.parse(androidUrl));
            launched = true;
          }
        } catch (e) {
          print('Android geo: failed: $e');
        }
        
        // Try iOS Google Maps app
        if (!launched) {
          try {
            final iosUrl = 'comgooglemaps://?q=$lat,$lng';
            if (await canLaunchUrl(Uri.parse(iosUrl))) {
              await launchUrl(Uri.parse(iosUrl));
              launched = true;
            }
          } catch (e) {
            print('iOS Google Maps failed: $e');
          }
        }
        
        // Fallback to web URL
        if (!launched) {
          if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
            await launchUrl(
              Uri.parse(googleMapsUrl),
              mode: LaunchMode.externalApplication,
            );
            launched = true;
          }
        }
        
        // If all methods failed, show dialog
        if (!launched) {
          _showGoogleMapsDialog(googleMapsUrl, lat, lng);
        }
      }
    } catch (e) {
      print('Google Maps error: $e');
      // Show dialog as fallback
      _showGoogleMapsDialog(googleMapsUrl, lat, lng);
    }
  }
  
  void _showGoogleMapsDialog(String googleMapsUrl, double lat, double lng) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.map, color: Color(0xFF4285F4)),
              SizedBox(width: 8),
              Text('Open in Google Maps'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cannot open Google Maps automatically. Please copy this link:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: SelectableText(
                  googleMapsUrl,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Coordinates: $lat, $lng',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 18.0);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Centered on current location'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      // Try to get current location again
      _getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(8, 111, 222, 0.977),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.map,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Map Container
            Expanded(
              child: Stack(
                children: [
                  // Map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation ?? const LatLng(11.0067, 124.6075), // Ormoc City
                      initialZoom: 16.0,
                      maxZoom: 20.0,
                      minZoom: 5.0,
                      onTap: _onMapTap,
                    ),
                    children: [
                      // Tile Layer - Dynamic based on view mode
                      TileLayer(
                        urlTemplate: _isSatelliteView 
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.obo.mobile',
                        maxZoom: 20,
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
                                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
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
                  
                  // Search Bar
                  if (widget.showSearchBar)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 80, // Leave space for controls
                      child: Container(
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
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search: "Ormoc City", "Brgy. Ipil", "Street name"...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : _hasSearchTextSafe
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onSubmitted: _searchLocation,
                        ),
                      ),
                    ),
                  
                  // Search Suggestions Overlay
                  if (widget.showSearchBar && _hasSearchTextSafe && !_isSearching)
                    Positioned(
                      top: 70, // Below search bar
                      left: 16,
                      right: 80,
                      child: Container(
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
                          children: [
                            _buildSearchSuggestion('📍 Tap on map to select exact location'),
                            _buildSearchSuggestion('🏢 Try: "Ormoc City Hall"'),
                            _buildSearchSuggestion('🏪 Try: "Ormoc Public Market"'),
                            _buildSearchSuggestion('🏥 Try: "Ormoc District Hospital"'),
                            _buildSearchSuggestion('🏫 Try: "Ormoc Central School"'),
                            _buildSearchSuggestion('🌊 Try: "Lake Danao"'),
                          ],
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
                        const SizedBox(height: 8),
                        
                        // Satellite view toggle button
                        Container(
                          decoration: BoxDecoration(
                            color: _isSatelliteView ? const Color(0xFF4285F4) : Colors.white,
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
                            onPressed: _toggleSatelliteView,
                            icon: Icon(
                              _isSatelliteView ? Icons.map : Icons.satellite,
                              color: _isSatelliteView ? Colors.white : Colors.black87,
                            ),
                            tooltip: _isSatelliteView ? 'Switch to Standard View' : 'Switch to Satellite View',
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
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: const Color.fromRGBO(8, 111, 222, 0.977),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Address information
                            if (_selectedAddress != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.place,
                                      size: 14,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _selectedAddress!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF0EA5E9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            
                            // Coordinates
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Coordinates:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lat: ${_selectedLocation!.latitude.toStringAsFixed(8)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
                                  ),
                                  Text(
                                    'Lng: ${_selectedLocation!.longitude.toStringAsFixed(8)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Google Maps Button
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openGoogleMaps(_selectedLocation!),
                                icon: const Icon(
                                  Icons.map,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Open in Google Maps',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4285F4), // Google Blue
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: const BorderSide(color: Color(0xFF6B7280)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedLocation != null
                          ? () => Navigator.of(context).pop(_selectedLocation)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Select Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
