import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../services/inspection_service.dart';
import '../config/app_config.dart';

class MediaCaptureWidget extends StatefulWidget {
  final List<String> imagePaths;
  final List<String> videoPaths;
  final Function(List<String>) onImagesChanged;
  final Function(List<String>) onVideosChanged;
  final bool isTablet;
  final String? sectionName;

  const MediaCaptureWidget({
    super.key,
    required this.imagePaths,
    required this.videoPaths,
    required this.onImagesChanged,
    required this.onVideosChanged,
    required this.isTablet,
    this.sectionName,
  });

  @override
  State<MediaCaptureWidget> createState() => _MediaCaptureWidgetState();
}

class _MediaCaptureWidgetState extends State<MediaCaptureWidget> {
  final ImagePicker _picker = ImagePicker();

  // Helper function to check if a path is a network URL or server path
  bool _isNetworkPath(String path) {
    if (path.isEmpty) return false;
    // Check for full URLs
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return true;
    }
    // Check for server relative paths
    if (path.startsWith('uploads/') || path.startsWith('/uploads/')) {
      return true;
    }
    // Check for blob URLs
    if (path.startsWith('blob:')) {
      return true;
    }
    return false;
  }

  // Helper function to normalize and get full URL for images
  Future<String> _getFullImageUrl(String path) async {
    if (path.isEmpty) return path;
    
    // If already a full URL, validate and return
    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        final uri = Uri.parse(path);
        final reconstructed = uri.toString();
        print('Using full URL: $reconstructed');
        return reconstructed;
      } catch (e) {
        print('Error parsing URL, using original: $path - $e');
        return path;
      }
    }
    
    // If it's a relative server path, construct full URL
    if (path.startsWith('uploads/') || path.startsWith('/uploads/')) {
      try {
        final baseUrl = await AppConfig.baseUrl;
        final webBaseUrl = baseUrl.replaceAll('/api', '');
        final cleanPath = path.startsWith('/') ? path.substring(1) : path;
        final fullUrl = Uri.parse('$webBaseUrl/$cleanPath').toString();
        print('Constructed URL from relative path: $fullUrl');
        return fullUrl;
      } catch (e) {
        print('Error getting base URL: $e');
        return path.startsWith('/') ? path : '/$path';
      }
    }
    
    return path;
  }

  // Check if a local file exists for a given path (extract filename and search)
  Future<String?> _findLocalFile(String serverPath) async {
    if (kIsWeb) return null;
    
    try {
      String fileName = serverPath.split('/').last;
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }
      if (fileName.isEmpty) return null;
      
      print('Searching for local file with filename: $fileName');
      
      final Directory baseDir = await getApplicationDocumentsDirectory();
      final Directory photosDir = Directory('${baseDir.path}/inspections/photos');
      final Directory videosDir = Directory('${baseDir.path}/inspections/videos');
      
      bool matchesFilename(String filePath, String targetName) {
        String normalizeName(String input) {
          if (input.isEmpty) return input;
          String base = input.toLowerCase();
          if (base.contains('.')) {
            base = base.split('.').first;
          }
          final parts = base.split('_').where((part) => part.isNotEmpty).toList();
          if (parts.isEmpty) return base;
          final List<String> filtered = [];
          bool trimmed = false;
          for (final part in parts) {
            final isNumeric = RegExp(r'^\d{6,}$').hasMatch(part);
            final isHex = RegExp(r'^[0-9a-f]{6,}$').hasMatch(part);
            if (!trimmed && (isNumeric || isHex)) {
              continue;
            }
            trimmed = true;
            filtered.add(part);
          }
          if (filtered.isEmpty) {
            filtered.addAll(parts.length > 2 ? parts.sublist(parts.length - 2) : parts);
          }
          return filtered.join('_');
        }

        final file = File(filePath);
        final name = file.path.split(Platform.pathSeparator).last;
        final nameWithoutExt = name.split('.').first.toLowerCase();
        final targetWithoutExt = targetName.split('.').first.toLowerCase();
        final normalizedName = normalizeName(name);
        final normalizedTarget = normalizeName(targetName);

        if (name == targetName || nameWithoutExt == targetWithoutExt) return true;
        if (name.contains(targetName) || nameWithoutExt.contains(targetWithoutExt)) return true;
        if (targetName.contains(name) || targetWithoutExt.contains(nameWithoutExt)) return true;
        if (normalizedName.isNotEmpty && normalizedTarget.isNotEmpty) {
          if (normalizedName == normalizedTarget) return true;
          if (normalizedName.contains(normalizedTarget) || normalizedTarget.contains(normalizedName)) return true;
          final nameSuffix = normalizedName.length > 20 ? normalizedName.substring(normalizedName.length - 20) : normalizedName;
          final targetSuffix = normalizedTarget.length > 20 ? normalizedTarget.substring(normalizedTarget.length - 20) : normalizedTarget;
          if (nameSuffix == targetSuffix) return true;
        }

        final nameTimestamp = name.split('_').first;
        final targetTimestamp = targetName.split('_').first;
        if (nameTimestamp.isNotEmpty && targetTimestamp.isNotEmpty) {
          try {
            final nameTime = int.tryParse(nameTimestamp);
            final targetTime = int.tryParse(targetTimestamp);
            if (nameTime != null && targetTime != null) {
              if ((nameTime - targetTime).abs() < 3600000) return true;
            }
          } catch (e) {}
        }
        return false;
      }
      
      if (await photosDir.exists()) {
        final files = await photosDir.list().toList();
        for (var file in files) {
          if (file is File && matchesFilename(file.path, fileName)) {
            print('Found local photo file: ${file.path}');
            return file.path;
          }
        }
      }
      
      if (await videosDir.exists()) {
        final files = await videosDir.list().toList();
        for (var file in files) {
          if (file is File && matchesFilename(file.path, fileName)) {
            print('Found local video file: ${file.path}');
            return file.path;
          }
        }
      }
      
      final Directory backupPhotosDir = Directory('${baseDir.path}/media_backup/photos');
      final Directory backupVideosDir = Directory('${baseDir.path}/media_backup/videos');
      
      if (await backupPhotosDir.exists()) {
        final files = await backupPhotosDir.list().toList();
        for (var file in files) {
          if (file is File && matchesFilename(file.path, fileName)) {
            return file.path;
          }
        }
      }
      
      if (await backupVideosDir.exists()) {
        final files = await backupVideosDir.list().toList();
        for (var file in files) {
          if (file is File && matchesFilename(file.path, fileName)) {
            return file.path;
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error searching for local file: $e');
      return null;
    }
  }

  // Dynamic image widget that handles both web and mobile
  Widget _buildImageWidget(String path, {BoxFit fit = BoxFit.cover}) {
    print('_buildImageWidget called with path: $path');
    
    if (path.isEmpty) {
      print('Path is empty');
      return _buildImageErrorWidget('Empty path');
    }

    // On mobile, always try to find local file first (even for network paths)
    if (!kIsWeb) {
      print('Mobile platform detected');
      if (!_isNetworkPath(path)) {
        print('Path is local: $path');
        return _buildLocalImage(path, fit: fit);
      } else {
        print('Path is network: $path');
        return _buildNetworkImage(path, fit: fit);
      }
    } else {
      print('Web platform detected');
      if (_isNetworkPath(path)) {
        print('Path is network: $path');
        return _buildNetworkImage(path, fit: fit);
      } else {
        print('Path is local on web (invalid): $path');
        return _buildImageErrorWidget('Local file not accessible on web');
      }
    }
  }

  // Build network image (for both web and mobile)
  Widget _buildNetworkImage(String path, {BoxFit fit = BoxFit.cover}) {
    print('_buildNetworkImage called with path: $path');
    
    // On mobile, try to find local file first
    if (!kIsWeb) {
      print('Mobile: Searching for local file first...');
      return FutureBuilder<String?>(
        future: _findLocalFile(path),
        builder: (context, localSnapshot) {
          if (localSnapshot.hasData && localSnapshot.data != null) {
            print('Mobile: Found local file: ${localSnapshot.data}');
            return _buildLocalImage(localSnapshot.data!, fit: fit);
          }
          if (localSnapshot.connectionState == ConnectionState.waiting) {
            print('Mobile: Still searching for local file...');
            return _buildImageLoadingWidget();
          }
          print('Mobile: No local file found, loading from network');
          return _loadNetworkImage(path, fit: fit);
        },
      );
    }
    print('Web: Loading directly from network');
    return _loadNetworkImage(path, fit: fit);
  }

  // Load image from network
  Widget _loadNetworkImage(String path, {BoxFit fit = BoxFit.cover}) {
    print('_loadNetworkImage called with path: $path');
    
    return FutureBuilder<String>(
      future: _getFullImageUrl(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Waiting for URL construction...');
          return _buildImageLoadingWidget();
        }
        
        if (snapshot.hasError) {
          print('Error getting full URL: ${snapshot.error}');
          return _buildImageErrorWidget('URL error: ${snapshot.error}');
        }
        
        final imageUrl = snapshot.data ?? path;
        print('Loading network image from URL: $imageUrl');
        
        return Image.network(
          imageUrl,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          headers: {'Accept': 'image/*'},
          errorBuilder: (context, error, stackTrace) {
            print('ERROR: Failed to load network image');
            print('URL: $imageUrl');
            print('Error: $error');
            print('StackTrace: $stackTrace');
            return _buildImageErrorWidget('Failed to load image');
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('Image loaded successfully');
              return child;
            }
            final progress = loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null;
            print('Loading image progress: $progress');
            return _buildImageLoadingWidget(progress: progress);
          },
          cacheWidth: fit == BoxFit.cover ? 300 : null,
          cacheHeight: fit == BoxFit.cover ? 300 : null,
        );
      },
    );
  }

  // Build local image (mobile only)
  Widget _buildLocalImage(String path, {BoxFit fit = BoxFit.cover}) {
    print('_buildLocalImage called with path: $path');
    
    if (kIsWeb) {
      print('Web: Cannot load local files');
      return _buildImageErrorWidget('Local file not accessible on web');
    }
    
    final file = File(path);
    print('Checking if file exists: $path');
    
    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Checking file existence...');
          return _buildImageLoadingWidget();
        }
        
        print('File exists check result: ${snapshot.data}');
        
        if (snapshot.data == true) {
          print('Loading local image: $path');
          return Image.file(
            file,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              print('ERROR: Failed to load local image: $path');
              print('ERROR details: $error');
              print('ERROR stackTrace: $stackTrace');
              // Try to load as network image if local fails
              if (_isNetworkPath(path)) {
                print('Retrying as network image...');
                return _loadNetworkImage(path, fit: fit);
              }
              return _buildImageErrorWidget('Failed to load');
            },
            cacheWidth: fit == BoxFit.cover ? 300 : null,
            cacheHeight: fit == BoxFit.cover ? 300 : null,
          );
        } else {
          print('Local image file not found: $path');
          // If local file doesn't exist, try network if it's a network path
          if (_isNetworkPath(path)) {
            print('File not found locally, trying network...');
            return _loadNetworkImage(path, fit: fit);
          }
          return _buildImageErrorWidget('File not found');
        }
      },
    );
  }

  // Helper widgets
  Widget _buildImageLoadingWidget({double? progress}) {
    return Container(
      color: Colors.grey[200],
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: progress != null
            ? CircularProgressIndicator(value: progress)
            : const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildImageErrorWidget(String message) {
    print('_buildImageErrorWidget called with message: $message');
    return Container(
      color: Colors.grey[300],
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported,
            color: Colors.grey,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Show permission modal first
      final hasPermissions = await _showPermissionModal(
        isVideo: false,
        source: source,
      );
      
      if (!hasPermissions) {
        return; // User cancelled or denied permissions
      }
      
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        if (!kIsWeb) {
          // Mobile: Save to persistent directory (image.path is a real file path)
          String finalPath = await _saveToInspectionsDir(image, subdir: 'photos');
          
          // Store the local path for offline access
          setState(() {
            widget.imagePaths.add(finalPath);
          });
          widget.onImagesChanged(widget.imagePaths);
          
          // Try to upload to server in background
          try {
            final serverPath = await InspectionService.uploadMediaFile(
              finalPath,
              section: widget.sectionName ?? 'Unknown',
              type: 'image',
            );
            // Server path is stored when syncing inspection
          } catch (_) {
            // Upload failure doesn't affect local storage
          }
        } else {
          // Web platform: Upload blob URL directly to server
          // On web, image.path is a blob URL - we need to upload it immediately
          try {
            // Read blob as bytes
            final bytes = await image.readAsBytes();
            
            // Upload directly to server
            final serverPath = await InspectionService.uploadMediaFileFromBytes(
              bytes,
              originalPath: image.path,
              fileName: image.name.isNotEmpty ? image.name : 'image.jpg',
              section: widget.sectionName ?? 'Unknown',
              type: 'image',
            );
            
            // Store server path (on web, we don't have local storage)
            setState(() {
              widget.imagePaths.add(serverPath);
            });
            widget.onImagesChanged(widget.imagePaths);
          } catch (e) {
            _showErrorDialog('Failed to upload image: $e');
          }
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      // Show permission modal first
      final hasPermissions = await _showPermissionModal(
        isVideo: true,
        source: source,
      );
      
      if (!hasPermissions) {
        return; // User cancelled or denied permissions
      }
      
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5), // Limit to 5 minutes
      );
      
      if (video != null) {
        if (!kIsWeb) {
          // Mobile: Process the video file
          String videoPath = video.path;
          final file = File(videoPath);
          if (await file.exists()) {
            final fileSize = await file.length();
            if (fileSize > 0) {
              // Always save to persistent local directory
              String finalPath = await _saveToInspectionsDir(video, subdir: 'videos');
              
              // Store the local path for offline access
              setState(() {
                widget.videoPaths.add(finalPath);
              });
              widget.onVideosChanged(widget.videoPaths);
              
              // Try to upload to server in background
              try {
                final serverPath = await InspectionService.uploadMediaFile(
                  finalPath,
                  section: widget.sectionName ?? 'Unknown',
                  type: 'video',
                );
                // Server path is stored when syncing inspection
              } catch (_) {
                // Upload failure doesn't affect local storage
              }
            } else {
              _showErrorDialog('Video file is empty or corrupted.');
            }
          } else {
            _showErrorDialog('Video file not found.');
          }
        } else {
          // Web platform: Upload blob URL directly to server
          try {
            // Read blob as bytes
            final bytes = await video.readAsBytes();
            
            // Upload directly to server
            final serverPath = await InspectionService.uploadMediaFileFromBytes(
              bytes,
              originalPath: video.path,
              fileName: video.name.isNotEmpty ? video.name : 'video.mp4',
              section: widget.sectionName ?? 'Unknown',
              type: 'video',
            );
            
            // Store server path (on web, we don't have local storage)
            setState(() {
              widget.videoPaths.add(serverPath);
            });
            widget.onVideosChanged(widget.videoPaths);
          } catch (e) {
            _showErrorDialog('Failed to upload video: $e');
          }
        }
      }
    } catch (e) {
      _showErrorDialog('Failed to pick video: $e');
    }
  }

  Future<bool> _showPermissionModal({required bool isVideo, required ImageSource source}) async {
    if (kIsWeb) return true; // Browser handles permissions
    
    // Check current permissions first
    final permissions = _getRequiredPermissions(isVideo: isVideo, source: source);
    final currentStatuses = <Permission, PermissionStatus>{};
    
    for (final permission in permissions) {
      currentStatuses[permission] = await permission.status;
    }
    
    // If all permissions are already granted, proceed without showing modal
    bool allGranted = currentStatuses.values.every((status) => status.isGranted);
    if (allGranted) {
      return true;
    }
    
    // Show permission modal
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MediaPermissionModal(
        isVideo: isVideo,
        source: source,
        requiredPermissions: permissions,
        initialStatuses: currentStatuses,
      ),
    ) ?? false;
  }

  List<Permission> _getRequiredPermissions({required bool isVideo, required ImageSource source}) {
    final List<Permission> permissions = [];
    
    if (source == ImageSource.camera) {
      // Camera source - need camera permission
      permissions.add(Permission.camera);
    } else {
      // Gallery/Photo library source - need photos/videos permission
      if (Platform.isAndroid) {
        // Android 13+ granular media permissions
        if (isVideo) {
          permissions.add(Permission.videos);
        } else {
          permissions.add(Permission.photos);
        }
        // Also request storage for older Android versions
        permissions.add(Permission.storage);
      } else if (Platform.isIOS) {
        // iOS needs photos permission for photo library access
        permissions.add(Permission.photos);
      }
    }
    
    return permissions;
  }

  Future<bool> _ensurePermissions({required bool isVideo, required ImageSource source}) async {
    if (kIsWeb) return true; // Browser handles permissions
    
    // Get all required permissions
    final List<Permission> toRequest = _getRequiredPermissions(isVideo: isVideo, source: source);
    
    if (toRequest.isEmpty) return true;
    
    // Request all permissions at once
    final Map<Permission, PermissionStatus> statuses = await toRequest.request();
    
    // Check if any permission is permanently denied
    for (final entry in statuses.entries) {
      if (entry.value.isPermanentlyDenied) {
        // Show dialog to open settings
        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: Text(
                '${_getPermissionName(entry.key)} permission is permanently denied. Please enable it in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          
          if (shouldOpen == true) {
            await openAppSettings();
          }
        }
        return false;
      }
      
      // Check if permission is denied (not granted)
      if (!entry.value.isGranted) {
        return false;
      }
    }
    
    return true;
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Camera';
      case Permission.photos:
        return 'Photos';
      case Permission.videos:
        return 'Videos';
      case Permission.storage:
        return 'Storage';
      default:
        return 'Media Access';
    }
  }

  Future<String> _saveToInspectionsDir(XFile xfile, {required String subdir}) async {
    try {
      // Always use application documents directory for persistence
      final Directory baseDir = await getApplicationDocumentsDirectory();
      final Directory inspectionsDir = Directory(p.join(baseDir.path, 'inspections', subdir));
      if (!(await inspectionsDir.exists())) {
        await inspectionsDir.create(recursive: true);
      }

      final String ext = p.extension(xfile.path);
      // Use timestamp and random number to ensure unique filename
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}_${p.basenameWithoutExtension(xfile.path)}$ext';
      final String destPath = p.join(inspectionsDir.path, fileName);

      // Copy to destination - ensure file is fully written
      final File destFile = File(destPath);
      final bytes = await xfile.readAsBytes();
      await destFile.writeAsBytes(bytes, flush: true);
      
      // Verify file was written successfully
      if (await destFile.exists() && await destFile.length() > 0) {
        debugPrint('Media saved successfully to: $destPath');
        return destPath;
      } else {
        throw Exception('File was not written correctly');
      }
    } catch (e) {
      // If application documents directory fails, try external storage directory
      try {
        debugPrint('Primary save failed: $e, trying alternative location...');
        final Directory baseDir = await getApplicationDocumentsDirectory();
        // Try a different subdirectory as fallback
        final Directory inspectionsDir = Directory(p.join(baseDir.path, 'media_backup', subdir));
        if (!(await inspectionsDir.exists())) {
          await inspectionsDir.create(recursive: true);
        }
        
        final String ext = p.extension(xfile.path);
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}_${p.basenameWithoutExtension(xfile.path)}$ext';
        final String destPath = p.join(inspectionsDir.path, fileName);
        
        final File destFile = File(destPath);
        final bytes = await xfile.readAsBytes();
        await destFile.writeAsBytes(bytes, flush: true);
        
        if (await destFile.exists() && await destFile.length() > 0) {
          debugPrint('Media saved to fallback location: $destPath');
          return destPath;
        } else {
          throw Exception('Fallback save also failed');
        }
      } catch (e2) {
        // Last resort: return original path but log warning
        debugPrint('WARNING: Media save failed completely: $e | Fallback failed: $e2');
        debugPrint('Using original path: ${xfile.path}');
        // Return original path - this should still work if the file hasn't been deleted
        return xfile.path;
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      widget.imagePaths.removeAt(index);
    });
    widget.onImagesChanged(widget.imagePaths);
  }

  void _removeVideo(int index) {
    setState(() {
      widget.videoPaths.removeAt(index);
    });
    widget.onVideosChanged(widget.videoPaths);
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Media capture buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showImageOptions,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: Text(
                  'Add Photos',
                  style: TextStyle(fontSize: widget.isTablet ? 14 : 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: widget.isTablet ? 12 : 10,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showVideoOptions,
                icon: const Icon(Icons.videocam, size: 18),
                label: Text(
                  'Add Videos',
                  style: TextStyle(fontSize: widget.isTablet ? 14 : 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: widget.isTablet ? 12 : 10,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Images grid
        if (widget.imagePaths.isNotEmpty) ...[
          Text(
            'Photos (${widget.imagePaths.length})',
            style: TextStyle(
              fontSize: widget.isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.isTablet ? 4 : 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: widget.imagePaths.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildImageWidget(
                          widget.imagePaths[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        
        // Videos list
        if (widget.videoPaths.isNotEmpty) ...[
          Text(
            'Videos (${widget.videoPaths.length})',
            style: TextStyle(
              fontSize: widget.isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          ...widget.videoPaths.asMap().entries.map((entry) {
            final index = entry.key;
            final videoPath = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  'Video ${index + 1}',
                  style: TextStyle(
                    fontSize: widget.isTablet ? 14 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Tap to preview',
                  style: TextStyle(
                    fontSize: widget.isTablet ? 12 : 10,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                trailing: IconButton(
                  onPressed: () => _removeVideo(index),
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                onTap: () => _previewVideo(videoPath),
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  void _previewVideo(String videoPath) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Center(
                  child: VideoPlayerWidget(videoPath: videoPath),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;

  const VideoPlayerWidget({super.key, required this.videoPath});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  // Helper function to check if a path is a network URL or server path
  bool _isNetworkPath(String path) {
    if (path.isEmpty) return false;
    return path.startsWith('http://') || 
           path.startsWith('https://') || 
           path.startsWith('uploads/') ||
           path.startsWith('/uploads/') ||
           path.startsWith('blob:');
  }

  // Helper function to get full URL for server paths
  Future<String> _getFullVideoUrl(String path) async {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path; // Already a full URL
    }
    
    if (path.startsWith('uploads/') || path.startsWith('/uploads/')) {
      // Get base URL from config and construct web-accessible URL
      try {
        final baseUrl = await AppConfig.baseUrl;
        // baseUrl is like "http://192.168.0.115/OBO-LGU/api"
        // We need to convert it to web root: "http://192.168.0.115/OBO-LGU"
        final webBaseUrl = baseUrl.replaceAll('/api', '');
        final cleanPath = path.startsWith('/') ? path.substring(1) : path;
        return '$webBaseUrl/$cleanPath';
      } catch (e) {
        print('Error getting base URL for video: $e');
        // Fallback: return path as-is
        return path.startsWith('/') ? path : '/$path';
      }
    }
    
    return path;
  }

  Future<void> _initializeVideo() async {
    try {
      // Check if it's a network path or local file
      if (_isNetworkPath(widget.videoPath)) {
        // Network path - get full URL and use network controller
        final videoUrl = await _getFullVideoUrl(widget.videoPath);
        _controller = VideoPlayerController.network(videoUrl);
      } else {
        // Local file path
        if (kIsWeb) {
          // On web, if it's not a network path, it's invalid
          throw Exception('Invalid video path for web: ${widget.videoPath}');
        }
        _controller = VideoPlayerController.file(File(widget.videoPath));
      }
      
      // Add error listener
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          setState(() {
            _hasError = true;
            _errorMessage = _controller!.value.errorDescription;
          });
        }
      });
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Video Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage ?? 'Unknown error occurred',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _errorMessage = null;
                });
                _initializeVideo();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        VideoControls(controller: _controller!),
      ],
    );
  }
}

class VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoControls({super.key, required this.controller});

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.controller.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          VideoProgressIndicator(
            widget.controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white54,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 8),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Play/Pause button
              IconButton(
                onPressed: () {
                  if (_isPlaying) {
                    widget.controller.pause();
                  } else {
                    widget.controller.play();
                  }
                },
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              // Duration info
              Text(
                '${_formatDuration(widget.controller.value.position)} / ${_formatDuration(widget.controller.value.duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              // Volume button
              IconButton(
                onPressed: () {
                  // Toggle mute
                  widget.controller.setVolume(
                    widget.controller.value.volume > 0 ? 0.0 : 1.0,
                  );
                },
                icon: Icon(
                  widget.controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaPermissionModal extends StatefulWidget {
  final bool isVideo;
  final ImageSource source;
  final List<Permission> requiredPermissions;
  final Map<Permission, PermissionStatus> initialStatuses;

  const _MediaPermissionModal({
    required this.isVideo,
    required this.source,
    required this.requiredPermissions,
    required this.initialStatuses,
  });

  @override
  State<_MediaPermissionModal> createState() => _MediaPermissionModalState();
}

class _MediaPermissionModalState extends State<_MediaPermissionModal> {
  late Map<Permission, PermissionStatus> _permissionStatuses;
  final Map<Permission, bool> _isRequesting = {};

  @override
  void initState() {
    super.initState();
    _permissionStatuses = Map.from(widget.initialStatuses);
    // Initialize requesting states
    for (final permission in widget.requiredPermissions) {
      _isRequesting[permission] = false;
    }
    // Automatically request all permissions that are not granted
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    // Request all permissions that are not already granted
    for (final permission in widget.requiredPermissions) {
      final currentStatus = _permissionStatuses[permission] ?? PermissionStatus.denied;
      if (!currentStatus.isGranted && !currentStatus.isPermanentlyDenied) {
        await _requestPermission(permission);
      }
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    setState(() {
      _isRequesting[permission] = true;
    });

    try {
      final status = await permission.request();
      setState(() {
        _permissionStatuses[permission] = status;
        _isRequesting[permission] = false;
      });

      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Permission permanently denied. Please enable it in app settings.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Open Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isRequesting[permission] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Camera';
      case Permission.photos:
        return 'Photos';
      case Permission.videos:
        return 'Videos';
      case Permission.storage:
        return 'Storage';
      default:
        return 'Media Access';
    }
  }

  String _getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return widget.isVideo 
            ? 'Required to record videos'
            : 'Required to take photos';
      case Permission.photos:
        return 'Required to access photo library';
      case Permission.videos:
        return 'Required to access video library';
      case Permission.storage:
        return 'Required to save media files';
      default:
        return 'Required for media access';
    }
  }

  IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return widget.isVideo ? Icons.videocam : Icons.camera_alt;
      case Permission.photos:
        return Icons.photo_library;
      case Permission.videos:
        return Icons.video_library;
      case Permission.storage:
        return Icons.storage;
      default:
        return Icons.perm_media;
    }
  }

  Color _getPermissionColor(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return widget.isVideo ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
      case Permission.photos:
        return const Color(0xFF8B5CF6);
      case Permission.videos:
        return const Color(0xFF3B82F6);
      case Permission.storage:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  bool get _canProceed {
    return _permissionStatuses.values.every((status) => status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: isTablet ? (isLargeTablet ? 500 : 450) : 350,
        padding: EdgeInsets.all(isTablet ? 28 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isVideo
                          ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                          : [const Color(0xFF10B981), const Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.isVideo ? Icons.videocam : Icons.camera_alt,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isVideo ? 'Video Capture' : 'Photo Capture',
                        style: TextStyle(
                          fontSize: isTablet ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Permissions Required',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              widget.isVideo
                  ? 'To capture or select videos, the app needs access to your camera and video library.'
                  : 'To capture or select photos, the app needs access to your camera and photo library.',
              style: TextStyle(
                fontSize: isTablet ? 15 : 13,
                color: const Color(0xFF374151),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Permission sections
            ...widget.requiredPermissions.map((permission) {
              final status = _permissionStatuses[permission] ?? PermissionStatus.denied;
              final isGranted = status.isGranted;
              final isDenied = status.isDenied;
              final isPermanentlyDenied = status.isPermanentlyDenied;
              final isRequesting = _isRequesting[permission] ?? false;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPermissionSection(
                  icon: _getPermissionIcon(permission),
                  title: _getPermissionName(permission),
                  description: _getPermissionDescription(permission),
                  isGranted: isGranted,
                  isDenied: isDenied,
                  isPermanentlyDenied: isPermanentlyDenied,
                  isLoading: isRequesting,
                  onTap: isGranted 
                      ? null 
                      : () => _requestPermission(permission),
                  color: _getPermissionColor(permission),
                  isTablet: isTablet,
                ),
              );
            }).toList(),

            const SizedBox(height: 8),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFF6B7280)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
                      padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: isTablet ? 15 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionSection({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required bool isDenied,
    required bool isPermanentlyDenied,
    required bool isLoading,
    required VoidCallback? onTap,
    required Color color,
    required bool isTablet,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16 : 14),
        decoration: BoxDecoration(
          color: isGranted ? color.withOpacity(0.1) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGranted ? color : const Color(0xFFE2E8F0),
            width: isGranted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isGranted ? color : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isGranted ? Colors.white : color,
                size: isTablet ? 22 : 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  if (isPermanentlyDenied) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Please enable in app settings',
                      style: TextStyle(
                        fontSize: isTablet ? 11 : 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
              )
            else if (isGranted)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else if (isPermanentlyDenied)
              IconButton(
                onPressed: () => openAppSettings(),
                icon: const Icon(
                  Icons.settings,
                  color: Colors.orange,
                  size: 20,
                ),
                tooltip: 'Open Settings',
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: isTablet ? 16 : 14,
              ),
          ],
        ),
      ),
    );
  }
}
