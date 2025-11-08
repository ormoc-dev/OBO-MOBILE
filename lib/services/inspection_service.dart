import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/inspection.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/hive_offline_database.dart';

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

      // Add session cookie and headers for authentication
      final apiHeaders = await ApiService.headers;
      request.headers.addAll({
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      });
      
      // Add cookie if available
      if (apiHeaders.containsKey('Cookie')) {
        request.headers['Cookie'] = apiHeaders['Cookie']!;
        print('Adding cookie to upload request: ${apiHeaders['Cookie']}');
      }
      
      // Add session ID header if available
      if (apiHeaders.containsKey('X-Session-Id')) {
        request.headers['X-Session-Id'] = apiHeaders['X-Session-Id']!;
        print('Adding X-Session-Id to upload request: ${apiHeaders['X-Session-Id']}');
      }

      // Handle web platform blob URLs
      if (filePath.startsWith('blob:') || filePath.startsWith('blob://')) {
        // For web, we need to fetch the blob and upload as bytes
        // This requires different handling - for now, reject blob URLs
        throw Exception('Blob URLs cannot be uploaded. Please use mobile app or select file again.');
      }

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      
      // Extract and save session cookie from response
      final cookie = ApiService.extractCookieFromHeaders(response.headers);
      if (cookie != null) {
        await ApiService.setSessionCookie(cookie);
        print('Session cookie saved from upload response: $cookie');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final path = data['data']?['path'] as String?;
          if (path != null && path.isNotEmpty) return path;
        }
        throw Exception(data['message'] ?? 'Failed to upload media');
      } else if (response.statusCode == 401) {
        // Authentication failed - session might have expired
        throw Exception('Authentication failed. Please log in again.');
      } else {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // On failure, return original local path so the app still functions
      // But re-throw authentication errors
      if (e.toString().contains('Authentication failed')) {
        rethrow;
      }
      return filePath;
    }
  }

  // Upload media file from bytes (for web platform)
  static Future<String> uploadMediaFileFromBytes(
    List<int> bytes, {
    required String originalPath,
    required String fileName,
    required String section,
    required String type,
  }) async {
    try {
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        throw Exception('No internet connection');
      }

      final baseUrl = await AppConfig.baseUrl;
      final uri = Uri.parse('$baseUrl/mobile/upload_media.php');

      final request = http.MultipartRequest('POST', uri);
      request.fields['section'] = section;
      request.fields['media_type'] = type;

      // Add session cookie and headers for authentication
      final apiHeaders = await ApiService.headers;
      request.headers.addAll({
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      });
      
      // Add cookie if available
      if (apiHeaders.containsKey('Cookie')) {
        request.headers['Cookie'] = apiHeaders['Cookie']!;
        print('Adding cookie to upload request: ${apiHeaders['Cookie']}');
      }
      
      // Add session ID header if available
      if (apiHeaders.containsKey('X-Session-Id')) {
        request.headers['X-Session-Id'] = apiHeaders['X-Session-Id']!;
        print('Adding X-Session-Id to upload request: ${apiHeaders['X-Session-Id']}');
      }

      // Determine file extension from fileName or MIME type
      String ext = '';
      if (fileName.contains('.')) {
        ext = fileName.split('.').last.toLowerCase();
      } else {
        // Default extensions based on type
        ext = type == 'video' ? 'mp4' : 'jpg';
      }

      // Create multipart file from bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName.isNotEmpty ? fileName : 'file.$ext',
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      
      // Extract and save session cookie from response
      final cookie = ApiService.extractCookieFromHeaders(response.headers);
      if (cookie != null) {
        await ApiService.setSessionCookie(cookie);
        print('Session cookie saved from upload response: $cookie');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final path = data['data']?['path'] as String?;
          if (path != null && path.isNotEmpty) return path;
        }
        throw Exception(data['message'] ?? 'Failed to upload media');
      } else if (response.statusCode == 401) {
        // Authentication failed - session might have expired
        throw Exception('Authentication failed. Please log in again.');
      } else {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to upload media: $e');
    }
  }
  // Upload all media files and return updated paths
  static Future<Map<String, Map<String, List<String>>>> uploadAllMediaFiles(
    Map<String, List<String>> sectionImagePaths,
    Map<String, List<String>> sectionVideoPaths,
  ) async {
    final uploadedImages = <String, List<String>>{};
    final uploadedVideos = <String, List<String>>{};

    // Upload images for each section
    for (final entry in sectionImagePaths.entries) {
      final section = entry.key;
      final imagePaths = entry.value;
      uploadedImages[section] = [];

      for (final localPath in imagePaths) {
        try {
          // Skip blob URLs - they can't be uploaded and are temporary
          if (localPath.startsWith('blob:') || localPath.startsWith('blob://')) {
            print('Skipping blob URL (cannot upload): $localPath');
            continue; // Skip blob URLs entirely
          }
          
          // Check if it's already a server path (starts with uploads/)
          if (localPath.startsWith('uploads/') || 
              localPath.startsWith('http://') || 
              localPath.startsWith('https://')) {
            uploadedImages[section]!.add(localPath);
            continue;
          }

          // Check if it's a valid file path (not a blob URL)
          if (!localPath.contains('/') && !localPath.contains('\\')) {
            print('Skipping invalid path: $localPath');
            continue;
          }

          // Upload local file to server
          final serverPath = await uploadMediaFile(
            localPath,
            section: section,
            type: 'image',
          );
          
          // Verify server path was returned
          if (serverPath.isNotEmpty && !serverPath.startsWith('blob:')) {
            uploadedImages[section]!.add(serverPath);
          } else {
            print('Upload returned invalid path: $serverPath');
          }
        } catch (e) {
          print('Failed to upload image $localPath: $e');
          // Don't add failed uploads - they're invalid
        }
      }
    }

    // Upload videos for each section
    for (final entry in sectionVideoPaths.entries) {
      final section = entry.key;
      final videoPaths = entry.value;
      uploadedVideos[section] = [];

      for (final localPath in videoPaths) {
        try {
          // Skip blob URLs - they can't be uploaded and are temporary
          if (localPath.startsWith('blob:') || localPath.startsWith('blob://')) {
            print('Skipping blob URL (cannot upload): $localPath');
            continue; // Skip blob URLs entirely
          }
          
          // Check if it's already a server path (starts with uploads/)
          if (localPath.startsWith('uploads/') || 
              localPath.startsWith('http://') || 
              localPath.startsWith('https://')) {
            uploadedVideos[section]!.add(localPath);
            continue;
          }

          // Check if it's a valid file path (not a blob URL)
          if (!localPath.contains('/') && !localPath.contains('\\')) {
            print('Skipping invalid path: $localPath');
            continue;
          }

          // Upload local file to server
          final serverPath = await uploadMediaFile(
            localPath,
            section: section,
            type: 'video',
          );
          
          // Verify server path was returned
          if (serverPath.isNotEmpty && !serverPath.startsWith('blob:')) {
            uploadedVideos[section]!.add(serverPath);
          } else {
            print('Upload returned invalid path: $serverPath');
          }
        } catch (e) {
          print('Failed to upload video $localPath: $e');
          // Don't add failed uploads - they're invalid
        }
      }
    }

    return {
      'images': uploadedImages,
      'videos': uploadedVideos,
    };
  }

  // Create a new inspection on the server
  static Future<Map<String, dynamic>> createInspection(Inspection inspection) async {
    try {
      // Check connectivity
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        throw Exception('No internet connection. Inspection will be synced when online.');
      }

      // Upload all media files first and get server paths
      final uploadedMedia = await uploadAllMediaFiles(
        inspection.sectionImagePaths ?? {},
        inspection.sectionVideoPaths ?? {},
      );

      final baseUrl = await AppConfig.baseUrl;
      final endpoint = '/mobile/create_inspection.php';

      // Prepare request body - use uploaded server paths instead of local paths
      final body = {
        'scanned_data': inspection.scannedData.isNotEmpty ? inspection.scannedData : 'No QR data',
        'inspection_start_time': inspection.inspectionStartTime?.toIso8601String(),
        'inspection_end_time': inspection.inspectionEndTime?.toIso8601String(),
        'latitude': inspection.latitude,
        'longitude': inspection.longitude,
        'section_status': inspection.sectionStatus,
        'section_image_paths': uploadedMedia['images'] ?? {},
        'section_video_paths': uploadedMedia['videos'] ?? {},
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

      // Upload all media files first and get server paths
      final uploadedMedia = await uploadAllMediaFiles(
        inspection.sectionImagePaths ?? {},
        inspection.sectionVideoPaths ?? {},
      );

      final baseUrl = await AppConfig.baseUrl;
      final endpoint = '/mobile/update_inspection.php';

      // Prepare request body - use uploaded server paths instead of local paths
      final body = {
        'inspection_id': serverInspectionId,
        'inspection_start_time': inspection.inspectionStartTime?.toIso8601String(),
        'inspection_end_time': inspection.inspectionEndTime?.toIso8601String(),
        'latitude': inspection.latitude,
        'longitude': inspection.longitude,
        'section_status': inspection.sectionStatus,
        'section_image_paths': uploadedMedia['images'] ?? {},
        'section_video_paths': uploadedMedia['videos'] ?? {},
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
  // This method ensures all media files are uploaded before syncing
  static Future<bool> syncInspection(Inspection inspection) async {
    try {
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        throw Exception('No internet connection. Cannot sync inspection.');
      }

      // Check if inspection has been synced before (has server ID)
      final hasServerId = inspection.id.contains('_') && 
                         int.tryParse(inspection.id.split('_').last) != null;

      if (hasServerId && inspection.isSynced) {
        // Update existing inspection (media files will be uploaded in updateInspection)
        await updateInspection(inspection);
        // Mark as synced after successful update
        await HiveOfflineDatabase.markInspectionAsSynced(inspection.id);
      } else {
        // Create new inspection (media files will be uploaded in createInspection)
        final result = await createInspection(inspection);
        
        // Store server inspection ID if returned
        if (result['server_inspection_id'] != null) {
          final serverId = result['server_inspection_id'];
          final oldId = inspection.id;
          
          // Update local inspection with server ID
          inspection.id = 'inspection_$serverId';
          inspection.isSynced = true;
          
          // Delete old entry and save with new ID
          await HiveOfflineDatabase.deleteInspection(oldId);
          await HiveOfflineDatabase.saveInspection(inspection);
          await HiveOfflineDatabase.markInspectionAsSynced(inspection.id);
        }
      }

      return true;
    } catch (e) {
      print('Error syncing inspection: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Sync all unsynced inspections (for background sync)
  static Future<Map<String, dynamic>> syncAllUnsyncedInspections() async {
    try {
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        return {
          'success': false,
          'message': 'No internet connection',
          'synced_count': 0,
          'failed_count': 0,
        };
      }

      // Get all unsynced inspections
      final unsyncedInspections = HiveOfflineDatabase.getUnsyncedInspections();
      
      if (unsyncedInspections.isEmpty) {
        return {
          'success': true,
          'message': 'No unsynced inspections',
          'synced_count': 0,
          'failed_count': 0,
        };
      }

      int syncedCount = 0;
      int failedCount = 0;
      List<String> errors = [];

      print('Found ${unsyncedInspections.length} unsynced inspections. Starting sync...');

      // Sync each inspection
      for (final inspection in unsyncedInspections) {
        try {
          print('Syncing inspection: ${inspection.id}');
          
          // Sync inspection (this will upload all media files)
          final success = await syncInspection(inspection);
          
          if (success) {
            syncedCount++;
            print('Successfully synced inspection: ${inspection.id}');
          } else {
            failedCount++;
            errors.add('Failed to sync inspection ${inspection.id}');
            print('Failed to sync inspection: ${inspection.id}');
          }
        } catch (e) {
          failedCount++;
          final errorMsg = 'Error syncing inspection ${inspection.id}: $e';
          errors.add(errorMsg);
          print(errorMsg);
        }
      }

      return {
        'success': failedCount == 0,
        'message': 'Synced $syncedCount of ${unsyncedInspections.length} inspections',
        'synced_count': syncedCount,
        'failed_count': failedCount,
        'errors': errors,
      };
    } catch (e) {
      print('Error in syncAllUnsyncedInspections: $e');
      return {
        'success': false,
        'message': 'Sync failed: $e',
        'synced_count': 0,
        'failed_count': 0,
      };
    }
  }
}

