import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../services/inspection_service.dart';

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
        String finalPath = image.path;
        if (!kIsWeb) {
          finalPath = await _saveToInspectionsDir(image, subdir: 'photos');
        }
        // Try to upload to server to get web-accessible path
        String serverPath = finalPath;
        try {
          serverPath = await InspectionService.uploadMediaFile(
            finalPath,
            section: widget.sectionName ?? 'Unknown',
            type: 'image',
          );
        } catch (_) {}
        setState(() {
          widget.imagePaths.add(serverPath);
        });
        widget.onImagesChanged(widget.imagePaths);
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
        if (kIsWeb) {
          // On web, use the blob/object URL directly (no dart:io validation)
          setState(() {
            widget.videoPaths.add(video.path);
          });
          widget.onVideosChanged(widget.videoPaths);
        } else {
          // Validate video file (mobile)
          final file = File(video.path);
          if (await file.exists()) {
            final fileSize = await file.length();
            if (fileSize > 0) {
              String finalPath = await _saveToInspectionsDir(video, subdir: 'videos');
              // Try to upload to server to get web-accessible path
              String serverPath = finalPath;
              try {
                serverPath = await InspectionService.uploadMediaFile(
                  finalPath,
                  section: widget.sectionName ?? 'Unknown',
                  type: 'video',
                );
              } catch (_) {}
              setState(() {
                widget.videoPaths.add(serverPath);
              });
              widget.onVideosChanged(widget.videoPaths);
            } else {
              _showErrorDialog('Video file is empty or corrupted.');
            }
          } else {
            _showErrorDialog('Video file not found.');
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
      final Directory baseDir = await getApplicationDocumentsDirectory();
      final Directory inspectionsDir = Directory(p.join(baseDir.path, 'inspections', subdir));
      if (!(await inspectionsDir.exists())) {
        await inspectionsDir.create(recursive: true);
      }

      final String ext = p.extension(xfile.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(xfile.path)}$ext';
      final String destPath = p.join(inspectionsDir.path, fileName);

      // Copy to destination
      final File destFile = File(destPath);
      await destFile.writeAsBytes(await xfile.readAsBytes(), flush: true);
      return destPath;
    } catch (e) {
      // Fallback: try temporary directory
      try {
        final Directory tmpDir = await getTemporaryDirectory();
        final Directory inspectionsTmp = Directory(p.join(tmpDir.path, 'inspections', subdir));
        if (!(await inspectionsTmp.exists())) {
          await inspectionsTmp.create(recursive: true);
        }
        final String ext = p.extension(xfile.path);
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(xfile.path)}$ext';
        final String destPath = p.join(inspectionsTmp.path, fileName);
        final File destFile = File(destPath);
        await destFile.writeAsBytes(await xfile.readAsBytes(), flush: true);
        return destPath;
      } catch (e2) {
        // As last resort return original path
        debugPrint('Media save failed: $e | Fallback failed: $e2');
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
                      child: kIsWeb 
                        ? Image.network(
                            widget.imagePaths[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Image.file(
                            File(widget.imagePaths[index]),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
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

  Future<void> _initializeVideo() async {
    try {
      if (kIsWeb) {
        _controller = VideoPlayerController.network(widget.videoPath);
      } else {
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
