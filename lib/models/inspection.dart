import 'package:hive/hive.dart';

part 'inspection.g.dart';

@HiveType(typeId: 3)
class Inspection extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String scannedData;

  @HiveField(2)
  String mechanicalRemarks;

  @HiveField(3)
  String mechanicalAssessment;

  @HiveField(4)
  String lineGradeRemarks;

  @HiveField(5)
  String lineGradeAssessment;

  @HiveField(6)
  String architecturalRemarks;

  @HiveField(7)
  String architecturalAssessment;

  @HiveField(8)
  String civilStructuralRemarks;

  @HiveField(9)
  String civilStructuralAssessment;

  @HiveField(10)
  String sanitaryPlumbingRemarks;

  @HiveField(11)
  String sanitaryPlumbingAssessment;

  @HiveField(12)
  String electricalElectronicsRemarks;

  @HiveField(13)
  String electricalElectronicsAssessment;

  @HiveField(14)
  DateTime createdAt;

  @HiveField(15)
  DateTime updatedAt;

  @HiveField(16)
  bool isSynced;

  @HiveField(17)
  String? userId;

  @HiveField(18)
  double? latitude;

  @HiveField(19)
  double? longitude;

  @HiveField(20)
  List<String> imagePaths;

  @HiveField(21)
  List<String> videoPaths;

  @HiveField(22)
  DateTime? inspectionStartTime;

  @HiveField(23)
  DateTime? inspectionEndTime;

  @HiveField(24)
  Map<String, String> sectionStatus;

  @HiveField(25)
  Map<String, List<String>>? sectionImagePaths;

  @HiveField(26)
  Map<String, List<String>>? sectionVideoPaths;

  @HiveField(27)
  bool? hasBuildingPermit;

  @HiveField(28)
  bool? hasOccupancyPermit;

  @HiveField(29)
  int? occupancyPermitIssuedYear;

  @HiveField(30)
  String? occupancyPermitRecommendation;

  @HiveField(31)
  String? buildingPermitRecommendation;

  @HiveField(32)
  String? buildingPermitId;

  @HiveField(33)
  String? occupancyPermitId;

  Inspection({
    required this.id,
    required this.scannedData,
    required this.mechanicalRemarks,
    required this.mechanicalAssessment,
    required this.lineGradeRemarks,
    required this.lineGradeAssessment,
    required this.architecturalRemarks,
    required this.architecturalAssessment,
    required this.civilStructuralRemarks,
    required this.civilStructuralAssessment,
    required this.sanitaryPlumbingRemarks,
    required this.sanitaryPlumbingAssessment,
    required this.electricalElectronicsRemarks,
    required this.electricalElectronicsAssessment,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.userId,
    this.latitude,
    this.longitude,
    this.imagePaths = const [],
    this.videoPaths = const [],
    this.sectionImagePaths,
    this.sectionVideoPaths,
    this.inspectionStartTime,
    this.inspectionEndTime,
    this.sectionStatus = const {},
    this.hasBuildingPermit,
    this.hasOccupancyPermit,
    this.occupancyPermitIssuedYear,
    this.occupancyPermitRecommendation,
    this.buildingPermitRecommendation,
    this.buildingPermitId,
    this.occupancyPermitId,
  });

  // Factory constructor for creating from form data
  factory Inspection.fromFormData({
    required String scannedData,
    required String mechanicalRemarks,
    required String mechanicalAssessment,
    required String lineGradeRemarks,
    required String lineGradeAssessment,
    required String architecturalRemarks,
    required String architecturalAssessment,
    required String civilStructuralRemarks,
    required String civilStructuralAssessment,
    required String sanitaryPlumbingRemarks,
    required String sanitaryPlumbingAssessment,
    required String electricalElectronicsRemarks,
    required String electricalElectronicsAssessment,
    String? userId,
    double? latitude,
    double? longitude,
    List<String> imagePaths = const [],
    List<String> videoPaths = const [],
    Map<String, List<String>>? sectionImagePaths,
    Map<String, List<String>>? sectionVideoPaths,
    DateTime? inspectionStartTime,
    DateTime? inspectionEndTime,
    Map<String, String> sectionStatus = const {},
    bool? hasBuildingPermit,
    bool? hasOccupancyPermit,
    int? occupancyPermitIssuedYear,
    String? occupancyPermitRecommendation,
    String? buildingPermitRecommendation,
    String? buildingPermitId,
    String? occupancyPermitId,
  }) {
    final now = DateTime.now();
    return Inspection(
      id: 'inspection_${now.millisecondsSinceEpoch}',
      scannedData: scannedData,
      mechanicalRemarks: mechanicalRemarks,
      mechanicalAssessment: mechanicalAssessment,
      lineGradeRemarks: lineGradeRemarks,
      lineGradeAssessment: lineGradeAssessment,
      architecturalRemarks: architecturalRemarks,
      architecturalAssessment: architecturalAssessment,
      civilStructuralRemarks: civilStructuralRemarks,
      civilStructuralAssessment: civilStructuralAssessment,
      sanitaryPlumbingRemarks: sanitaryPlumbingRemarks,
      sanitaryPlumbingAssessment: sanitaryPlumbingAssessment,
      electricalElectronicsRemarks: electricalElectronicsRemarks,
      electricalElectronicsAssessment: electricalElectronicsAssessment,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      imagePaths: imagePaths,
      videoPaths: videoPaths,
      sectionImagePaths: sectionImagePaths,
      sectionVideoPaths: sectionVideoPaths,
      inspectionStartTime: inspectionStartTime,
      inspectionEndTime: inspectionEndTime,
      sectionStatus: sectionStatus,
      hasBuildingPermit: hasBuildingPermit,
      hasOccupancyPermit: hasOccupancyPermit,
      occupancyPermitIssuedYear: occupancyPermitIssuedYear,
      occupancyPermitRecommendation: occupancyPermitRecommendation,
      buildingPermitRecommendation: buildingPermitRecommendation,
      buildingPermitId: buildingPermitId,
      occupancyPermitId: occupancyPermitId,
    );
  }

  // Convert to JSON for API submission
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scanned_data': scannedData,
      'mechanical_remarks': mechanicalRemarks,
      'mechanical_assessment': mechanicalAssessment,
      'line_grade_remarks': lineGradeRemarks,
      'line_grade_assessment': lineGradeAssessment,
      'architectural_remarks': architecturalRemarks,
      'architectural_assessment': architecturalAssessment,
      'civil_structural_remarks': civilStructuralRemarks,
      'civil_structural_assessment': civilStructuralAssessment,
      'sanitary_plumbing_remarks': sanitaryPlumbingRemarks,
      'sanitary_plumbing_assessment': sanitaryPlumbingAssessment,
      'electrical_electronics_remarks': electricalElectronicsRemarks,
      'electrical_electronics_assessment': electricalElectronicsAssessment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'image_paths': imagePaths,
      'video_paths': videoPaths,
      'section_image_paths': sectionImagePaths ?? {},
      'section_video_paths': sectionVideoPaths ?? {},
      'inspection_start_time': inspectionStartTime?.toIso8601String(),
      'inspection_end_time': inspectionEndTime?.toIso8601String(),
      'section_status': sectionStatus,
      'has_building_permit': hasBuildingPermit,
      'has_occupancy_permit': hasOccupancyPermit,
      'occupancy_permit_issued_year': occupancyPermitIssuedYear,
      'occupancy_permit_recommendation': occupancyPermitRecommendation,
      'building_permit_recommendation': buildingPermitRecommendation,
      'building_permit_id': buildingPermitId,
      'occupancy_permit_id': occupancyPermitId,
    };
  }

  // Update inspection data
  void updateData({
    String? mechanicalRemarks,
    String? mechanicalAssessment,
    String? lineGradeRemarks,
    String? lineGradeAssessment,
    String? architecturalRemarks,
    String? architecturalAssessment,
    String? civilStructuralRemarks,
    String? civilStructuralAssessment,
    String? sanitaryPlumbingRemarks,
    String? sanitaryPlumbingAssessment,
    String? electricalElectronicsRemarks,
    String? electricalElectronicsAssessment,
    Map<String, String>? sectionStatus,
    Map<String, List<String>>? sectionImagePaths,
    Map<String, List<String>>? sectionVideoPaths,
    bool? hasBuildingPermit,
    bool? hasOccupancyPermit,
    int? occupancyPermitIssuedYear,
    String? occupancyPermitRecommendation,
    String? buildingPermitRecommendation,
  }) {
    if (mechanicalRemarks != null) this.mechanicalRemarks = mechanicalRemarks;
    if (mechanicalAssessment != null) this.mechanicalAssessment = mechanicalAssessment;
    if (lineGradeRemarks != null) this.lineGradeRemarks = lineGradeRemarks;
    if (lineGradeAssessment != null) this.lineGradeAssessment = lineGradeAssessment;
    if (architecturalRemarks != null) this.architecturalRemarks = architecturalRemarks;
    if (architecturalAssessment != null) this.architecturalAssessment = architecturalAssessment;
    if (civilStructuralRemarks != null) this.civilStructuralRemarks = civilStructuralRemarks;
    if (civilStructuralAssessment != null) this.civilStructuralAssessment = civilStructuralAssessment;
    if (sanitaryPlumbingRemarks != null) this.sanitaryPlumbingRemarks = sanitaryPlumbingRemarks;
    if (sanitaryPlumbingAssessment != null) this.sanitaryPlumbingAssessment = sanitaryPlumbingAssessment;
    if (electricalElectronicsRemarks != null) this.electricalElectronicsRemarks = electricalElectronicsRemarks;
    if (electricalElectronicsAssessment != null) this.electricalElectronicsAssessment = electricalElectronicsAssessment;
    if (sectionStatus != null) this.sectionStatus = sectionStatus;
    if (sectionImagePaths != null) this.sectionImagePaths = sectionImagePaths;
    if (sectionVideoPaths != null) this.sectionVideoPaths = sectionVideoPaths;
    if (hasBuildingPermit != null) this.hasBuildingPermit = hasBuildingPermit;
    if (hasOccupancyPermit != null) this.hasOccupancyPermit = hasOccupancyPermit;
    if (occupancyPermitIssuedYear != null) this.occupancyPermitIssuedYear = occupancyPermitIssuedYear;
    if (occupancyPermitRecommendation != null) this.occupancyPermitRecommendation = occupancyPermitRecommendation;
    if (buildingPermitRecommendation != null) this.buildingPermitRecommendation = buildingPermitRecommendation;
    if (buildingPermitId != null) this.buildingPermitId = buildingPermitId;
    if (occupancyPermitId != null) this.occupancyPermitId = occupancyPermitId;
    
    updatedAt = DateTime.now();
    save(); // Save to Hive
  }

  // Mark as synced
  void markAsSynced() {
    isSynced = true;
    updatedAt = DateTime.now();
    save();
  }
}
