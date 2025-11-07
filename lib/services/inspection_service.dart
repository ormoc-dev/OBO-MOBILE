import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/inspection.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';

class InspectionService {
  // Upload a single media file and return server web path
  static Future<String> uploadMediaFile(String filePath, {required String section, required String type}) async {
    try {
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        // Offline: return original path (will not be visible on web)
        return filePath;
      }

      final baseUrl = await AppConfig.baseUrl;
      final uri = Uri.parse('$baseUrl/mobile/upload_media.php');

      final request = http.MultipartRequest('POST', uri);
      request.fields['section'] = section;
      request.fields['media_type'] = type; // image|video

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final path = data['data']?['path'] as String?;
          if (path != null && path.isNotEmpty) return path;
        }
        throw Exception(data['message'] ?? 'Failed to upload media');
      } else {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // On failure, return original local path so the app still functions
      return filePath;
    }
  }
  // Create a new inspection on the server
  static Future<Map<String, dynamic>> createInspection(Inspection inspection) async {
    try {
      // Check connectivity
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        throw Exception('No internet connection. Inspection will be synced when online.');
      }

      final baseUrl = await AppConfig.baseUrl;
      final endpoint = '/mobile/create_inspection.php';

      // Prepare request body - ensure all fields are properly formatted
      final body = {
        'scanned_data': inspection.scannedData.isNotEmpty ? inspection.scannedData : 'No QR data',
        'inspection_start_time': inspection.inspectionStartTime?.toIso8601String(),
        'inspection_end_time': inspection.inspectionEndTime?.toIso8601String(),
        'latitude': inspection.latitude,
        'longitude': inspection.longitude,
        'section_status': inspection.sectionStatus,
        'section_image_paths': inspection.sectionImagePaths ?? {},
        'section_video_paths': inspection.sectionVideoPaths ?? {},
        'mechanical_remarks': inspection.mechanicalRemarks,
        'mechanical_assessment': inspection.mechanicalAssessment,
        'line_grade_remarks': inspection.lineGradeRemarks,
        'line_grade_assessment': inspection.lineGradeAssessment,
        'architectural_remarks': inspection.architecturalRemarks,
        'architectural_assessment': inspection.architecturalAssessment,
        'civil_structural_remarks': inspection.civilStructuralRemarks,
        'civil_structural_assessment': inspection.civilStructuralAssessment,
        'sanitary_plumbing_remarks': inspection.sanitaryPlumbingRemarks,
        'sanitary_plumbing_assessment': inspection.sanitaryPlumbingAssessment,
        'electrical_electronics_remarks': inspection.electricalElectronicsRemarks,
        'electrical_electronics_assessment': inspection.electricalElectronicsAssessment,
      };

      print('Creating inspection with data:');
      print('  Scanned data: ${inspection.scannedData}');
      print('  Start time: ${inspection.inspectionStartTime?.toIso8601String()}');
      print('  End time: ${inspection.inspectionEndTime?.toIso8601String()}');
      print('  Latitude: ${inspection.latitude}');
      print('  Longitude: ${inspection.longitude}');
      print('  Sections with data: ${inspection.sectionStatus.keys.toList()}');

      final response = await ApiService.post(endpoint, body);

      print('Create inspection response status: ${response.statusCode}');
      print('Create inspection response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = ApiService.handleResponse(response);
        
        // Check if the API returned success: false
        if (data['success'] == false) {
          final errorMessage = data['message'] ?? 'Unknown error occurred';
          print('API returned success: false - $errorMessage');
          throw Exception(errorMessage);
        }
        
        final serverId = data['data']?['inspection_id'] ?? data['data']?['id'];
        print('Server inspection ID received: $serverId');
        return {
          'success': true,
          'data': data,
          'server_inspection_id': serverId,
        };
      } else {
        final errorBody = response.body;
        print('Create inspection failed with status ${response.statusCode}: $errorBody');
        
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(errorBody);
          final errorMessage = errorData['message'] ?? 'Failed to create inspection';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Failed to create inspection: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('Error creating inspection: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Update an existing inspection on the server
  static Future<Map<String, dynamic>> updateInspection(Inspection inspection) async {
    try {
      // Check connectivity
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        throw Exception('No internet connection. Inspection will be synced when online.');
      }

      // Extract server inspection ID from inspection.id if it's numeric
      // Format: inspection.id might be "inspection_123456789" or server ID
      int? serverInspectionId;
      if (inspection.id.startsWith('inspection_')) {
        // This is a local ID, need to check if we have server ID stored
        // For now, we'll need to store server ID separately or extract it
        // For update, we'll assume the ID format is just the numeric part
        final idParts = inspection.id.split('_');
        if (idParts.length > 1) {
          serverInspectionId = int.tryParse(idParts.last);
        }
      } else {
        serverInspectionId = int.tryParse(inspection.id);
      }

      if (serverInspectionId == null) {
        throw Exception('Invalid inspection ID format. Cannot update on server.');
      }

      final baseUrl = await AppConfig.baseUrl;
      final endpoint = '/mobile/update_inspection.php';

      // Prepare request body
      final body = {
        'inspection_id': serverInspectionId,
        'inspection_start_time': inspection.inspectionStartTime?.toIso8601String(),
        'inspection_end_time': inspection.inspectionEndTime?.toIso8601String(),
        'latitude': inspection.latitude,
        'longitude': inspection.longitude,
        'section_status': inspection.sectionStatus,
        'section_image_paths': inspection.sectionImagePaths ?? {},
        'section_video_paths': inspection.sectionVideoPaths ?? {},
        'mechanical_remarks': inspection.mechanicalRemarks,
        'mechanical_assessment': inspection.mechanicalAssessment,
        'line_grade_remarks': inspection.lineGradeRemarks,
        'line_grade_assessment': inspection.lineGradeAssessment,
        'architectural_remarks': inspection.architecturalRemarks,
        'architectural_assessment': inspection.architecturalAssessment,
        'civil_structural_remarks': inspection.civilStructuralRemarks,
        'civil_structural_assessment': inspection.civilStructuralAssessment,
        'sanitary_plumbing_remarks': inspection.sanitaryPlumbingRemarks,
        'sanitary_plumbing_assessment': inspection.sanitaryPlumbingAssessment,
        'electrical_electronics_remarks': inspection.electricalElectronicsRemarks,
        'electrical_electronics_assessment': inspection.electricalElectronicsAssessment,
      };

      final response = await ApiService.post(endpoint, body);

      if (response.statusCode == 200) {
        final data = ApiService.handleResponse(response);
        
        // Check if the API returned success: false
        if (data['success'] == false) {
          final errorMessage = data['message'] ?? 'Unknown error occurred';
          print('API returned success: false - $errorMessage');
          throw Exception(errorMessage);
        }
        
        return {
          'success': true,
          'data': data,
        };
      } else {
        final errorBody = response.body;
        print('Update inspection failed with status ${response.statusCode}: $errorBody');
        
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(errorBody);
          final errorMessage = errorData['message'] ?? 'Failed to update inspection';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Failed to update inspection: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      print('Error updating inspection: $e');
      rethrow;
    }
  }

  // Get inspection from server
  static Future<Map<String, dynamic>> getInspection(int inspectionId) async {
    try {
      final baseUrl = await AppConfig.baseUrl;
      final endpoint = '/mobile/get_inspection.php?inspection_id=$inspectionId';

      final response = await ApiService.get(endpoint);

      if (response.statusCode == 200) {
        return ApiService.handleResponse(response);
      } else {
        throw Exception('Failed to get inspection: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting inspection: $e');
      rethrow;
    }
  }

  // Sync inspection to server (create or update)
  static Future<bool> syncInspection(Inspection inspection) async {
    try {
      // Check if inspection has been synced before (has server ID)
      final hasServerId = inspection.id.contains('_') && 
                         int.tryParse(inspection.id.split('_').last) != null;

      if (hasServerId && inspection.isSynced) {
        // Update existing inspection
        await updateInspection(inspection);
      } else {
        // Create new inspection
        final result = await createInspection(inspection);
        
        // Store server inspection ID if returned
        if (result['server_inspection_id'] != null) {
          // Update local inspection with server ID
          // This would need to be handled in the database layer
          inspection.markAsSynced();
        }
      }

      return true;
    } catch (e) {
      print('Error syncing inspection: $e');
      return false;
    }
  }
}

