import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'location_picker_dialog.dart';

class LocationPickerButton extends StatelessWidget {
  final LatLng? selectedLocation;
  final Function(LatLng) onLocationSelected;
  final String title;
  final String? subtitle;
  final String? hintText;
  final bool isRequired;
  final bool isTablet;

  const LocationPickerButton({
    super.key,
    this.selectedLocation,
    required this.onLocationSelected,
    this.title = 'Select Location',
    this.subtitle,
    this.hintText,
    this.isRequired = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            if (isRequired)
              const Text(
                '* ',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: isTablet ? 12 : 10,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
        const SizedBox(height: 8),

        // Location Picker Button
        InkWell(
          onTap: () => _showLocationPicker(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selectedLocation != null 
                    ? const Color.fromRGBO(8, 111, 222, 0.977)
                    : const Color(0xFFE2E8F0),
                width: selectedLocation != null ? 2 : 1,
              ),
              boxShadow: selectedLocation != null
                  ? [
                      BoxShadow(
                        color: const Color.fromRGBO(8, 111, 222, 0.977).withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selectedLocation != null
                        ? const Color.fromRGBO(8, 111, 222, 0.977)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: selectedLocation != null
                        ? Colors.white
                        : const Color(0xFF6B7280),
                    size: isTablet ? 20 : 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedLocation != null
                            ? 'Location Selected'
                            : hintText ?? 'Tap to select location',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: selectedLocation != null
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selectedLocation != null
                              ? const Color.fromRGBO(8, 111, 222, 0.977)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      if (selectedLocation != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Lat: ${selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${selectedLocation!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: isTablet ? 11 : 10,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: selectedLocation != null
                      ? const Color.fromRGBO(8, 111, 222, 0.977)
                      : const Color(0xFF6B7280),
                  size: isTablet ? 16 : 14,
                ),
              ],
            ),
          ),
        ),

        // Clear button (if location is selected)
        if (selectedLocation != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onLocationSelected(LatLng(0, 0)), // Use dummy location to clear
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Clear Selection',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showLocationPicker(BuildContext context) async {
    final result = await showLocationPicker(
      context: context,
      initialLocation: selectedLocation,
      title: title,
      subtitle: subtitle,
    );

    if (result != null) {
      onLocationSelected(result);
    }
  }
}

/// Helper widget for quick location selection in forms
class QuickLocationPicker extends StatelessWidget {
  final LatLng? selectedLocation;
  final Function(LatLng) onLocationSelected;
  final String label;
  final bool isRequired;
  final bool isTablet;

  const QuickLocationPicker({
    super.key,
    this.selectedLocation,
    required this.onLocationSelected,
    this.label = 'Location',
    this.isRequired = false,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LocationPickerButton(
            selectedLocation: selectedLocation,
            onLocationSelected: onLocationSelected,
            title: label,
            isRequired: isRequired,
            isTablet: isTablet,
          ),
        ),
        const SizedBox(width: 12),
        // Current location button
        Container(
          width: isTablet ? 50 : 45,
          height: isTablet ? 50 : 45,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(8, 111, 222, 0.977),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(8, 111, 222, 0.977).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _getCurrentLocation(context),
              child: Icon(
                Icons.my_location,
                color: Colors.white,
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _getCurrentLocation(BuildContext context) async {
    // This would integrate with the LocationService
    // For now, we'll show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting current location...'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
