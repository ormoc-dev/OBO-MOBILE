import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import '../models/inspection.dart';
import '../services/hive_offline_database.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../utils/location_service.dart';
import '../widgets/map_widget.dart';
import '../widgets/media_capture_widget.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class InspectionFormScreen extends StatefulWidget {
  final String? scannedData;
  final Inspection? existingInspection;
  final bool isEditing;
  
  const InspectionFormScreen({
    super.key, 
    this.scannedData,
    this.existingInspection,
    this.isEditing = false,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _FeeFieldConfig {
  final String key;
  final String label;
  final String shortLabel;
  final String unitLabel;
  final double rate;
  final String group;
  final String? helperText;

  const _FeeFieldConfig({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.unitLabel,
    required this.rate,
    required this.group,
    this.helperText,
  });
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Section selection
  Map<String, bool> _selectedSections = {};

  // Controllers for each section
  final Map<String, TextEditingController> _remarksControllers = {};
  final Map<String, TextEditingController> _assessmentControllers = {};
  
  // Status for each section
  final Map<String, String> _sectionStatus = {};

  // Permit information
  bool? _hasBuildingPermit;
  bool? _hasOccupancyPermit;
  final TextEditingController _occupancyPermitYearController = TextEditingController();
  String? _buildingPermitRecommendation;
  String? _occupancyPermitRecommendation;
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  // Annual inspection fees (Architectural)
  final TextEditingController _floorAreaController = TextEditingController();
  final TextEditingController _appendageCountController = TextEditingController();
  double _architecturalFeeTotal = 0;
  List<String> _architecturalFeeBreakdown = [];

  // Sanitary / Plumbing fees
  final TextEditingController _sanitaryPlumbingUnitsController = TextEditingController();
  double _sanitaryFeeTotal = 0;
  List<String> _sanitaryFeeBreakdown = [];
  bool _architecturalFloorAreaEnabled = true;
  bool _architecturalAppendageEnabled = false;
  bool _sanitaryUnitsEnabled = false;

  // Electrical fees
  final TextEditingController _connectedLoadController = TextEditingController();
  final TextEditingController _transformerCapacityController = TextEditingController();
  final TextEditingController _powerPoleCountController = TextEditingController();
  final TextEditingController _guyingAttachmentCountController = TextEditingController();
  final TextEditingController _electricalAdditionalFeeController = TextEditingController();
  double _electricalFeeTotal = 0;
  List<String> _electricalFeeBreakdown = [];
  List<String> _electricalCombinedBreakdown = [];
  bool _electricalConnectedLoadEnabled = false;
  bool _electricalCapacityEnabled = false;
  bool _electricalPolesEnabled = false;
  bool _electricalAttachmentsEnabled = false;
  bool _electricalManualEnabled = false;

  // Electronics fees (Electrical/Electronics section)
  final Map<String, TextEditingController> _electronicsFeeControllers = {};
  final TextEditingController _electronicsAdditionalFeeController = TextEditingController();
  double _electronicsFeeTotal = 0;
  List<String> _electronicsFeeBreakdown = [];
  final Map<String, bool> _electronicsGroupEnabled = {
    'core': false,
    'peripherals': false,
    'infrastructure': false,
  };
  bool _electronicsManualEnabled = false;

  // Mechanical fees
  final Map<String, TextEditingController> _mechanicalFeeControllers = {};
  final TextEditingController _mechanicalAdditionalFeeController = TextEditingController();
  double _mechanicalFeeTotal = 0;
  List<String> _mechanicalFeeBreakdown = [];
  final Map<String, bool> _mechanicalGroupEnabled = {
    'refrigeration': false,
    'packaged_ac': false,
    'ventilation': false,
    'conveyance': false,
    'elevators': false,
    'boilers': false,
    'engines': false,
    'misc': false,
  };
  bool _mechanicalManualEnabled = false;

  static const Map<String, String> _mechanicalGroupTitles = {
    'refrigeration': 'Refrigeration & Ice Plant',
    'packaged_ac': 'Packaged / Centralized Air Conditioning',
    'ventilation': 'Mechanical Ventilation',
    'conveyance': 'Escalators, Moving Walks & Cable Systems',
    'elevators': 'Elevators & Related Equipment',
    'boilers': 'Boilers, Heaters & Pumps',
    'engines': 'Engines & Generators',
    'misc': 'Miscellaneous Mechanical Equipment',
  };

  static const List<_FeeFieldConfig> _mechanicalFeeFieldConfigs = [
    _FeeFieldConfig(
      key: 'mech_ref_up_to_100',
      label: 'Up to 100 tons (enter tons within this range)',
      shortLabel: 'Refrigeration ≤100t',
      unitLabel: 'tons',
      rate: 25.0,
      group: 'refrigeration',
    ),
    _FeeFieldConfig(
      key: 'mech_ref_100_to_150',
      label: 'Above 100 to 150 tons',
      shortLabel: 'Refrigeration 100–150t',
      unitLabel: 'tons',
      rate: 20.0,
      group: 'refrigeration',
    ),
    _FeeFieldConfig(
      key: 'mech_ref_150_to_300',
      label: 'Above 150 to 300 tons',
      shortLabel: 'Refrigeration 150–300t',
      unitLabel: 'tons',
      rate: 15.0,
      group: 'refrigeration',
    ),
    _FeeFieldConfig(
      key: 'mech_ref_300_to_500',
      label: 'Above 300 to 500 tons',
      shortLabel: 'Refrigeration 300–500t',
      unitLabel: 'tons',
      rate: 10.0,
      group: 'refrigeration',
    ),
    _FeeFieldConfig(
      key: 'mech_ref_above_500',
      label: 'Above 500 tons',
      shortLabel: 'Refrigeration >500t',
      unitLabel: 'tons',
      rate: 5.0,
      group: 'refrigeration',
      helperText: 'Per ton or fraction thereof.',
    ),
    _FeeFieldConfig(
      key: 'mech_pack_first_100',
      label: 'First 100 tons',
      shortLabel: 'Packaged ≤100t',
      unitLabel: 'tons',
      rate: 25.0,
      group: 'packaged_ac',
    ),
    _FeeFieldConfig(
      key: 'mech_pack_100_to_150',
      label: 'Above 100 to 150 tons',
      shortLabel: 'Packaged 100–150t',
      unitLabel: 'tons',
      rate: 20.0,
      group: 'packaged_ac',
    ),
    _FeeFieldConfig(
      key: 'mech_pack_150_to_300',
      label: 'Above 150 to 300 tons',
      shortLabel: 'Packaged 150–300t',
      unitLabel: 'tons',
      rate: 15.0,
      group: 'packaged_ac',
      helperText: 'Assumed rate – please verify with updated schedule.',
    ),
    _FeeFieldConfig(
      key: 'mech_pack_300_to_500',
      label: 'Above 300 to 500 tons',
      shortLabel: 'Packaged 300–500t',
      unitLabel: 'tons',
      rate: 10.0,
      group: 'packaged_ac',
      helperText: 'Assumed rate – please verify with updated schedule.',
    ),
    _FeeFieldConfig(
      key: 'mech_pack_above_500',
      label: 'Above 500 tons',
      shortLabel: 'Packaged >500t',
      unitLabel: 'tons',
      rate: 8.0,
      group: 'packaged_ac',
      helperText: 'Per ton or fraction thereof.',
    ),
    _FeeFieldConfig(
      key: 'mech_window_ac_units',
      label: 'Window-type air conditioning (number of units)',
      shortLabel: 'Window AC units',
      unitLabel: 'units',
      rate: 40.0,
      group: 'packaged_ac',
    ),
    _FeeFieldConfig(
      key: 'mech_vent_unit_upto1',
      label: 'Mechanical ventilation – units up to 1 kW',
      shortLabel: 'Ventilation ≤1kW units',
      unitLabel: 'units',
      rate: 10.0,
      group: 'ventilation',
    ),
    _FeeFieldConfig(
      key: 'mech_vent_unit_1_to_7_5',
      label: 'Mechanical ventilation – units above 1 to 7.5 kW',
      shortLabel: 'Ventilation 1–7.5kW units',
      unitLabel: 'units',
      rate: 50.0,
      group: 'ventilation',
    ),
    _FeeFieldConfig(
      key: 'mech_vent_kw_above_7_5',
      label: 'Mechanical ventilation – kW above 7.5',
      shortLabel: 'Ventilation >7.5kW',
      unitLabel: 'kW',
      rate: 20.0,
      group: 'ventilation',
    ),
    _FeeFieldConfig(
      key: 'mech_escalator_units',
      label: 'Escalators / moving walks (units)',
      shortLabel: 'Escalators',
      unitLabel: 'units',
      rate: 120.0,
      group: 'conveyance',
    ),
    _FeeFieldConfig(
      key: 'mech_funicular_kw',
      label: 'Funicular (installed kW)',
      shortLabel: 'Funicular kW',
      unitLabel: 'kW',
      rate: 50.0,
      group: 'conveyance',
    ),
    _FeeFieldConfig(
      key: 'mech_funicular_meter',
      label: 'Funicular (lineal meters of travel)',
      shortLabel: 'Funicular meters',
      unitLabel: 'meters',
      rate: 10.0,
      group: 'conveyance',
    ),
    _FeeFieldConfig(
      key: 'mech_cablecar_kw',
      label: 'Cable car (installed kW)',
      shortLabel: 'Cable car kW',
      unitLabel: 'kW',
      rate: 25.0,
      group: 'conveyance',
    ),
    _FeeFieldConfig(
      key: 'mech_cablecar_meter',
      label: 'Cable car (lineal meters of travel)',
      shortLabel: 'Cable car meters',
      unitLabel: 'meters',
      rate: 2.0,
      group: 'conveyance',
    ),
    _FeeFieldConfig(
      key: 'mech_passenger_elevator',
      label: 'Passenger elevators (units)',
      shortLabel: 'Passenger elevators',
      unitLabel: 'units',
      rate: 500.0,
      group: 'elevators',
    ),
    _FeeFieldConfig(
      key: 'mech_freight_elevator',
      label: 'Freight elevators (units)',
      shortLabel: 'Freight elevators',
      unitLabel: 'units',
      rate: 400.0,
      group: 'elevators',
    ),
    _FeeFieldConfig(
      key: 'mech_dumbwaiter',
      label: 'Dumbwaiter / food lifts (units)',
      shortLabel: 'Dumbwaiters',
      unitLabel: 'units',
      rate: 50.0,
      group: 'elevators',
    ),
    _FeeFieldConfig(
      key: 'mech_construction_elevator',
      label: 'Construction elevators (materials hoists)',
      shortLabel: 'Construction elevators',
      unitLabel: 'units',
      rate: 400.0,
      group: 'elevators',
    ),
    _FeeFieldConfig(
      key: 'mech_car_elevator',
      label: 'Car elevators (units)',
      shortLabel: 'Car elevators',
      unitLabel: 'units',
      rate: 500.0,
      group: 'elevators',
    ),
    _FeeFieldConfig(
      key: 'mech_extra_landing',
      label: 'Additional landings above first five',
      shortLabel: 'Extra elevator landings',
      unitLabel: 'landings',
      rate: 50.0,
      group: 'elevators',
    ),
    _FeeFieldConfig(
      key: 'mech_boiler_upto_7_5',
      label: 'Steam boilers up to 7.5 kW (units)',
      shortLabel: 'Boilers ≤7.5kW',
      unitLabel: 'units',
      rate: 400.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_boiler_7_5_to_22',
      label: 'Steam boilers 7.5 – 22 kW (units)',
      shortLabel: 'Boilers 7.5–22kW',
      unitLabel: 'units',
      rate: 550.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_boiler_22_to_37',
      label: 'Steam boilers 22 – 37 kW (units)',
      shortLabel: 'Boilers 22–37kW',
      unitLabel: 'units',
      rate: 600.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_boiler_37_to_52',
      label: 'Steam boilers 37 – 52 kW (units)',
      shortLabel: 'Boilers 37–52kW',
      unitLabel: 'units',
      rate: 650.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_boiler_52_to_67',
      label: 'Steam boilers 52 – 67 kW (units)',
      shortLabel: 'Boilers 52–67kW',
      unitLabel: 'units',
      rate: 800.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_boiler_67_to_74',
      label: 'Steam boilers 67 – 74 kW (units)',
      shortLabel: 'Boilers 67–74kW',
      unitLabel: 'units',
      rate: 900.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_boiler_above_74',
      label: 'Steam boilers above 74 kW (enter kW above 74)',
      shortLabel: 'Boilers >74kW',
      unitLabel: 'kW',
      rate: 4.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_pressurized_heater',
      label: 'Pressurized water heaters (units)',
      shortLabel: 'Pressurized heaters',
      unitLabel: 'units',
      rate: 120.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_fire_extinguisher_heads',
      label: 'Automatic fire extinguisher heads',
      shortLabel: 'Extinguisher heads',
      unitLabel: 'heads',
      rate: 2.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_pump_upto_5kw',
      label: 'Water / sump / sewage pumps up to 5 kW (units)',
      shortLabel: 'Pumps ≤5kW',
      unitLabel: 'units',
      rate: 55.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_pump_5_to_10kw',
      label: 'Water / sump / sewage pumps 5 – 10 kW (units)',
      shortLabel: 'Pumps 5–10kW',
      unitLabel: 'units',
      rate: 90.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_pump_above_10kw',
      label: 'Water / sump / sewage pumps above 10 kW (enter kW above 10)',
      shortLabel: 'Pumps >10kW',
      unitLabel: 'kW',
      rate: 2.0,
      group: 'boilers',
    ),
    _FeeFieldConfig(
      key: 'mech_engine_upto_50kw',
      label: 'Diesel / gasoline engines up to 50 kW (enter kW)',
      shortLabel: 'Engines ≤50kW',
      unitLabel: 'kW',
      rate: 15.0,
      group: 'engines',
    ),
    _FeeFieldConfig(
      key: 'mech_engine_50_to_100kw',
      label: 'Diesel / gasoline engines 50 – 100 kW (enter kW)',
      shortLabel: 'Engines 50–100kW',
      unitLabel: 'kW',
      rate: 10.0,
      group: 'engines',
    ),
    _FeeFieldConfig(
      key: 'mech_engine_above_100kw',
      label: 'Diesel / gasoline engines above 100 kW (enter kW above 100)',
      shortLabel: 'Engines >100kW',
      unitLabel: 'kW',
      rate: 2.4,
      group: 'engines',
    ),
    _FeeFieldConfig(
      key: 'mech_compressed_outlets',
      label: 'Compressed air / vacuum / gas outlets',
      shortLabel: 'Compressed air outlets',
      unitLabel: 'outlets',
      rate: 10.0,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_power_piping_length',
      label: 'Power piping (lineal meters / cu. meters)',
      shortLabel: 'Power piping',
      unitLabel: 'meters or cu.m',
      rate: 2.0,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_cranes_units',
      label: 'Cranes / forklifts / mixers up to 10 kW (units)',
      shortLabel: 'Cranes ≤10kW units',
      unitLabel: 'units',
      rate: 100.0,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_cranes_kw_above_10',
      label: 'Cranes / forklifts / mixers – kW above 10',
      shortLabel: 'Cranes >10kW',
      unitLabel: 'kW',
      rate: 3.0,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_pressure_vessel_volume',
      label: 'Pressure vessels (cubic meters)',
      shortLabel: 'Pressure vessels',
      unitLabel: 'cu.m',
      rate: 40.0,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_pneumatic_length',
      label: 'Pneumatic tubes / conveyors (lineal meters)',
      shortLabel: 'Pneumatic tubes',
      unitLabel: 'meters',
      rate: 2.4,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_weighing_scale_ton',
      label: 'Weighing scale structures (tons)',
      shortLabel: 'Weighing scale structures',
      unitLabel: 'tons',
      rate: 30.0,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_pressure_gauge_units',
      label: 'Pressure gauge testing units',
      shortLabel: 'Pressure gauge testing',
      unitLabel: 'units',
      rate: 24.0,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_gas_meter_units',
      label: 'Gas meter testing units',
      shortLabel: 'Gas meter testing',
      unitLabel: 'units',
      rate: 30.0,
      group: 'misc',
    ),
    _FeeFieldConfig(
      key: 'mech_rides_units',
      label: 'Mechanical rides (Ferris wheels, etc.)',
      shortLabel: 'Mechanical rides',
      unitLabel: 'units',
      rate: 30.0,
      group: 'misc',
    ),
  ];

  static const Map<String, String> _electronicsGroupTitles = {
    'core': 'Core Electronics Facilities',
    'peripherals': 'Peripheral Equipment',
    'infrastructure': 'Support Infrastructure',
  };

  static const List<_FeeFieldConfig> _electronicsFeeFieldConfigs = [
    _FeeFieldConfig(
      key: 'elec_switch_ports',
      label: 'Central office switching / PBX ports',
      shortLabel: 'Switching ports',
      unitLabel: 'ports',
      rate: 2.4,
      group: 'core',
    ),
    _FeeFieldConfig(
      key: 'elec_broadcast_locations',
      label: 'Broadcast stations (Radio / TV)',
      shortLabel: 'Broadcast stations',
      unitLabel: 'locations',
      rate: 1000.0,
      group: 'core',
    ),
    _FeeFieldConfig(
      key: 'elec_catv_locations',
      label: 'CATV headend / relay / call centers',
      shortLabel: 'CATV / call centers',
      unitLabel: 'locations',
      rate: 1000.0,
      group: 'core',
    ),
    _FeeFieldConfig(
      key: 'elec_atm_units',
      label: 'ATM / ticketing / vending machines',
      shortLabel: 'ATM / vending units',
      unitLabel: 'units',
      rate: 10.0,
      group: 'peripherals',
    ),
    _FeeFieldConfig(
      key: 'elec_payphone_units',
      label: 'Telephone booths / pay phones',
      shortLabel: 'Pay phones',
      unitLabel: 'units',
      rate: 10.0,
      group: 'peripherals',
    ),
    _FeeFieldConfig(
      key: 'elec_outlets',
      label: 'Electronics & communication outlets',
      shortLabel: 'Electronics outlets',
      unitLabel: 'outlets',
      rate: 2.4,
      group: 'peripherals',
    ),
    _FeeFieldConfig(
      key: 'elec_alarm_terminations',
      label: 'Alarm / fire / CCTV / PA terminations',
      shortLabel: 'Alarm / CCTV points',
      unitLabel: 'terminations',
      rate: 2.4,
      group: 'peripherals',
    ),
    _FeeFieldConfig(
      key: 'elec_studio_locations',
      label: 'Studios / theaters / auditoriums',
      shortLabel: 'Studios / theaters',
      unitLabel: 'locations',
      rate: 1000.0,
      group: 'core',
    ),
    _FeeFieldConfig(
      key: 'elec_antenna_structures',
      label: 'Antenna towers / masts',
      shortLabel: 'Antenna structures',
      unitLabel: 'structures',
      rate: 1000.0,
      group: 'infrastructure',
    ),
    _FeeFieldConfig(
      key: 'elec_signage_units',
      label: 'Electronic signage / displays',
      shortLabel: 'Electronic signage',
      unitLabel: 'units',
      rate: 50.0,
      group: 'peripherals',
    ),
    _FeeFieldConfig(
      key: 'elec_poles_owner',
      label: 'Poles (owner-installed)',
      shortLabel: 'Electronics poles',
      unitLabel: 'poles',
      rate: 20.0,
      group: 'infrastructure',
    ),
    _FeeFieldConfig(
      key: 'elec_attachments',
      label: 'Attachments / guying (others)',
      shortLabel: 'Electronics attachments',
      unitLabel: 'attachments',
      rate: 20.0,
      group: 'infrastructure',
    ),
    _FeeFieldConfig(
      key: 'elec_other_devices',
      label: 'Other electronics devices / equipment',
      shortLabel: 'Other electronics devices',
      unitLabel: 'units',
      rate: 50.0,
      group: 'peripherals',
    ),
  ];
  
  // Location data for Civil/Structural section
  LatLng? _civilStructuralLocation;
  
  // Media capture data for each section
  Map<String, List<String>> _sectionImagePaths = {};
  Map<String, List<String>> _sectionVideoPaths = {};
  
  // Inspection timing
  DateTime? _inspectionStartTime;
  DateTime? _inspectionEndTime;
  
  // Initialization flag
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFeeControllers();
    _initializeData();
  }

  void _initializeFeeControllers() {
    _floorAreaController.addListener(_computeArchitecturalFees);
    _appendageCountController.addListener(_computeArchitecturalFees);

    _sanitaryPlumbingUnitsController.addListener(_computeSanitaryFees);

    _connectedLoadController.addListener(_computeElectricalFees);
    _transformerCapacityController.addListener(_computeElectricalFees);
    _powerPoleCountController.addListener(_computeElectricalFees);
    _guyingAttachmentCountController.addListener(_computeElectricalFees);
    _electricalAdditionalFeeController.addListener(_computeElectricalFees);

    _electronicsAdditionalFeeController.addListener(_computeElectronicsFees);
    for (final config in _electronicsFeeFieldConfigs) {
      final controller = TextEditingController();
      controller.addListener(_computeElectronicsFees);
      _electronicsFeeControllers[config.key] = controller;
    }

    _mechanicalAdditionalFeeController.addListener(_computeMechanicalFees);
    for (final config in _mechanicalFeeFieldConfigs) {
      final controller = TextEditingController();
      controller.addListener(_computeMechanicalFees);
      _mechanicalFeeControllers[config.key] = controller;
    }

    _recomputeAllFees();
  }

  void _initializeData() {
    // Initialize section selection map
    _selectedSections = {
      'Mechanical': false,
      'Line and Grade': false,
      'Architectural': false,
      'Civil/Structural': false,
      'Sanitary/Plumbing': false,
      'Electrical/Electronics': false,
    };

    // Ensure media maps are initialized
    _sectionImagePaths = {};
    _sectionVideoPaths = {};

    // Reset fee controllers & toggles
    _architecturalFloorAreaEnabled = true;
    _architecturalAppendageEnabled = false;
    _sanitaryUnitsEnabled = false;
    _electricalConnectedLoadEnabled = false;
    _electricalCapacityEnabled = false;
    _electricalPolesEnabled = false;
    _electricalAttachmentsEnabled = false;
    _electricalManualEnabled = false;
    _electronicsGroupEnabled.updateAll((key, value) => false);
    _electronicsManualEnabled = false;
    _mechanicalGroupEnabled.updateAll((key, value) => false);
    _mechanicalManualEnabled = false;
    _floorAreaController.clear();
    _appendageCountController.clear();
    _sanitaryPlumbingUnitsController.clear();
    _connectedLoadController.clear();
    _transformerCapacityController.clear();
    _powerPoleCountController.clear();
    _guyingAttachmentCountController.clear();
    _electricalAdditionalFeeController.clear();
    _electronicsAdditionalFeeController.clear();
    _mechanicalAdditionalFeeController.clear();
    for (final controller in _electronicsFeeControllers.values) {
      controller.clear();
    }
    for (final controller in _mechanicalFeeControllers.values) {
      controller.clear();
    }
    _recomputeAllFees();

    // Initialize controllers and status
    for (String section in _selectedSections.keys) {
      _remarksControllers[section] = TextEditingController();
      _assessmentControllers[section] = TextEditingController();
      _sectionStatus[section] = 'not_passed'; // Default status
      _sectionImagePaths[section] = []; // Initialize empty image list for each section
      _sectionVideoPaths[section] = []; // Initialize empty video list for each section
    }

    // Reset permit information for new inspections
    _hasBuildingPermit = null;
    _hasOccupancyPermit = null;
    _occupancyPermitYearController.clear();
    _buildingPermitRecommendation = null;
    _occupancyPermitRecommendation = null;
    
    // Handle editing mode - pre-fill data from existing inspection
    if (widget.isEditing && widget.existingInspection != null) {
      _loadExistingInspectionData(widget.existingInspection!);
    } else {
      // Set inspection start time when form is initialized (only for new inspections)
      _inspectionStartTime = DateTime.now();
    }
    
    // Mark as initialized
    _isInitialized = true;
  }

  void _loadExistingInspectionData(Inspection inspection) {
    // Load existing section data
    final sections = {
      'Mechanical': {'remarks': inspection.mechanicalRemarks, 'assessment': inspection.mechanicalAssessment},
      'Line and Grade': {'remarks': inspection.lineGradeRemarks, 'assessment': inspection.lineGradeAssessment},
      'Architectural': {'remarks': inspection.architecturalRemarks, 'assessment': inspection.architecturalAssessment},
      'Civil/Structural': {'remarks': inspection.civilStructuralRemarks, 'assessment': inspection.civilStructuralAssessment},
      'Sanitary/Plumbing': {'remarks': inspection.sanitaryPlumbingRemarks, 'assessment': inspection.sanitaryPlumbingAssessment},
      'Electrical/Electronics': {'remarks': inspection.electricalElectronicsRemarks, 'assessment': inspection.electricalElectronicsAssessment},
    };

    // Pre-fill section data and restore selected state based on stored content
    for (String section in sections.keys) {
      final sectionData = sections[section]!;
      final remarks = sectionData['remarks']!;
      final assessment = sectionData['assessment']!;

      _remarksControllers[section]?.text = remarks;
      _assessmentControllers[section]?.text = assessment;
      _selectedSections[section] = _shouldSelectSection(inspection, section);
    }

    // Load section status
    if (inspection.sectionStatus.isNotEmpty) {
      inspection.sectionStatus.forEach((section, status) {
        _sectionStatus[section] = status;
      });
    }

    // Load section-specific media
    if (inspection.sectionImagePaths != null) {
      inspection.sectionImagePaths!.forEach((section, images) {
        _sectionImagePaths[section] = List<String>.from(images);
      });
    }
    
    if (inspection.sectionVideoPaths != null) {
      inspection.sectionVideoPaths!.forEach((section, videos) {
        _sectionVideoPaths[section] = List<String>.from(videos);
      });
    }

    // Load location data for Civil/Structural
    if (inspection.latitude != null && inspection.longitude != null) {
      _civilStructuralLocation = LatLng(inspection.latitude!, inspection.longitude!);
    }

    // Load timing data
    _inspectionStartTime = inspection.inspectionStartTime;
    _inspectionEndTime = inspection.inspectionEndTime;

    // Load permit information
    _hasBuildingPermit = inspection.hasBuildingPermit;
    _hasOccupancyPermit = inspection.hasOccupancyPermit;
    if (inspection.occupancyPermitIssuedYear != null) {
      _occupancyPermitYearController.text = inspection.occupancyPermitIssuedYear!.toString();
    }
    _buildingPermitRecommendation = inspection.buildingPermitRecommendation ?? _computeBuildingPermitRecommendation();
    _occupancyPermitRecommendation = inspection.occupancyPermitRecommendation ?? _computeOccupancyPermitRecommendation();
  }

  bool _shouldSelectSection(Inspection inspection, String section) {
    bool hasText = false;
    switch (section) {
      case 'Mechanical':
        hasText = inspection.mechanicalRemarks.isNotEmpty || inspection.mechanicalAssessment.isNotEmpty;
        break;
      case 'Line and Grade':
        hasText = inspection.lineGradeRemarks.isNotEmpty || inspection.lineGradeAssessment.isNotEmpty;
        break;
      case 'Architectural':
        hasText = inspection.architecturalRemarks.isNotEmpty || inspection.architecturalAssessment.isNotEmpty;
        break;
      case 'Civil/Structural':
        hasText = inspection.civilStructuralRemarks.isNotEmpty || inspection.civilStructuralAssessment.isNotEmpty;
        break;
      case 'Sanitary/Plumbing':
        hasText = inspection.sanitaryPlumbingRemarks.isNotEmpty || inspection.sanitaryPlumbingAssessment.isNotEmpty;
        break;
      case 'Electrical/Electronics':
        hasText = inspection.electricalElectronicsRemarks.isNotEmpty || inspection.electricalElectronicsAssessment.isNotEmpty;
        break;
    }

    if (hasText) return true;

    final sectionImages = inspection.sectionImagePaths?[section] ?? const [];
    if (sectionImages.isNotEmpty) return true;

    final sectionVideos = inspection.sectionVideoPaths?[section] ?? const [];
    if (sectionVideos.isNotEmpty) return true;

    final statusValue = inspection.sectionStatus[section];
    if (statusValue != null && statusValue.trim().isNotEmpty) return true;

    if (section == 'Civil/Structural' && inspection.latitude != null && inspection.longitude != null) {
      return true;
    }

    return false;
  }

  Map<String, List<String>> _cloneSectionMediaMap(Map<String, List<String>> source) {
    final Map<String, List<String>> clone = {};
    source.forEach((key, value) {
      clone[key] = List<String>.from(value);
    });
    return clone;
  }

  @override
  void dispose() {
    for (var controller in _remarksControllers.values) {
      controller.dispose();
    }
    for (var controller in _assessmentControllers.values) {
      controller.dispose();
    }
    _occupancyPermitYearController.dispose();
    _floorAreaController.dispose();
    _appendageCountController.dispose();
    _sanitaryPlumbingUnitsController.dispose();
    _connectedLoadController.dispose();
    _transformerCapacityController.dispose();
    _powerPoleCountController.dispose();
    _guyingAttachmentCountController.dispose();
    _electricalAdditionalFeeController.dispose();
    _electronicsAdditionalFeeController.dispose();
    _mechanicalAdditionalFeeController.dispose();
    for (final controller in _electronicsFeeControllers.values) {
      controller.dispose();
    }
    for (final controller in _mechanicalFeeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure initialization is complete
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 32.0 : 16.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Scanned Data Info
                  _buildScannedDataCard(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Permit Section (first list in the form)
                  _buildPermitsCard(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Inspection Timing
                  _buildInspectionTimingCard(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Section Selection
                  _buildSectionSelection(context, isTablet),
                  const SizedBox(height: 24),
                  
                  // Selected Sections
                  ..._buildSelectedSections(context, isTablet),
                  
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  _buildSubmitButton(context, isTablet),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildCalculatorFAB(context, isTablet),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inspection Form',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete inspection details',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermitsCard(BuildContext context, bool isTablet) {
    final buildingRecommendation = _buildingPermitRecommendation;
    final occupancyRecommendation = _occupancyPermitRecommendation;
    final bool? hasBuildingPermit = _hasBuildingPermit;
    final bool? hasOccupancyPermit = _hasOccupancyPermit;

    Color _occupancyRecommendationColor(String? recommendation) {
      if (recommendation == null) return const Color(0xFF94A3B8);
      if (hasOccupancyPermit == true && recommendation == 'Approved') {
        return const Color(0xFF10B981);
      }
      if (hasOccupancyPermit == true) {
        return const Color(0xFFF59E0B);
      }
      return const Color(0xFFEF4444);
    }

    IconData _occupancyRecommendationIcon(String? recommendation) {
      if (recommendation == null) return Icons.info_outline_rounded;
      if (hasOccupancyPermit == true && recommendation == 'Approved') {
        return Icons.check_circle_rounded;
      }
      if (hasOccupancyPermit == true) {
        return Icons.warning_amber_rounded;
      }
      return Icons.error_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Permit Requirements',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Building Permit',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildPermitOption(
                label: 'Yes',
                icon: Icons.check_rounded,
                isSelected: hasBuildingPermit == true,
                onTap: () => _handleBuildingPermitSelection(true),
                color: const Color(0xFF10B981),
                isTablet: isTablet,
              ),
              _buildPermitOption(
                label: 'No',
                icon: Icons.close_rounded,
                isSelected: hasBuildingPermit == false,
                onTap: () => _handleBuildingPermitSelection(false),
                color: const Color(0xFFF97316),
                isTablet: isTablet,
              ),
            ],
          ),
          if (buildingRecommendation != null) ...[
            const SizedBox(height: 12),
            _buildRecommendationBanner(
              buildingRecommendation,
              hasBuildingPermit == true
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              hasBuildingPermit == true
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF97316),
              isTablet,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Occupancy Permit',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildPermitOption(
                label: 'Yes',
                icon: Icons.check_rounded,
                isSelected: hasOccupancyPermit == true,
                onTap: () => _handleOccupancyPermitSelection(true),
                color: const Color(0xFF3B82F6),
                isTablet: isTablet,
              ),
              _buildPermitOption(
                label: 'No',
                icon: Icons.close_rounded,
                isSelected: hasOccupancyPermit == false,
                onTap: () => _handleOccupancyPermitSelection(false),
                color: const Color(0xFFEF4444),
                isTablet: isTablet,
              ),
            ],
          ),
          if (hasOccupancyPermit == true) ...[
            const SizedBox(height: 12),
            Text(
              'Issued Year',
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _occupancyPermitYearController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Enter year (e.g. 2015)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                if (_hasOccupancyPermit == true) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Please enter the issued year.';
                  }
                  final year = int.tryParse(trimmed);
                  final currentYear = DateTime.now().year;
                  if (year == null || year < 1900 || year > currentYear) {
                    return 'Enter a valid year between 1900 and $currentYear.';
                  }
                }
                return null;
              },
              onChanged: _handleOccupancyYearChanged,
            ),
            const SizedBox(height: 8),
            Text(
              'If the occupancy permit is older than 15 years, the system will recommend issuing a Certificate of Structural Permit.',
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
          if (occupancyRecommendation != null) ...[
            const SizedBox(height: 12),
            _buildRecommendationBanner(
              occupancyRecommendation,
              _occupancyRecommendationIcon(occupancyRecommendation),
              _occupancyRecommendationColor(occupancyRecommendation),
              isTablet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermitOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: isTablet ? 18 : 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationBanner(
    String message,
    IconData icon,
    Color color,
    bool isTablet,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: isTablet ? 18 : 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: isTablet ? 13 : 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannedDataCard(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Business ID (scanned QR)',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Text(
              widget.scannedData ?? 'No business ID available',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: const Color(0xFF374151),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionTimingCard(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Inspection Timing',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Start Time
          Row(
            children: [
              Expanded(
                child: _buildTimeField(
                  'Start Time',
                  _inspectionStartTime,
                  Icons.play_arrow_rounded,
                  const Color(0xFF10B981),
                  isTablet,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: _buildTimeField(
                  'End Time',
                  _inspectionEndTime,
                  Icons.stop_rounded,
                  const Color(0xFFEF4444),
                  isTablet,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Duration calculation
          if (_inspectionStartTime != null && _inspectionEndTime != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(0),
                border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    color: Color(0xFF0EA5E9),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_calculateDuration()}',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: const Color(0xFF0EA5E9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, DateTime? time, IconData icon, Color color, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _selectTime(label),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: isTablet ? 20 : 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    time != null 
                        ? '${time.day}/${time.month}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                        : 'Tap to set $label',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: time != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                      fontWeight: time != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(String type) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: type == 'Start Time' 
          ? (_inspectionStartTime ?? DateTime.now())
          : (_inspectionEndTime ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: type == 'Start Time' 
            ? TimeOfDay.fromDateTime(_inspectionStartTime ?? DateTime.now())
            : TimeOfDay.fromDateTime(_inspectionEndTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        final DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (type == 'Start Time') {
            _inspectionStartTime = selectedDateTime;
          } else {
            _inspectionEndTime = selectedDateTime;
          }
        });
      }
    }
  }

  String _calculateDuration() {
    if (_inspectionStartTime == null || _inspectionEndTime == null) {
      return 'N/A';
    }

    final duration = _inspectionEndTime!.difference(_inspectionStartTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String? _computeBuildingPermitRecommendation() {
    if (_hasBuildingPermit == null) {
      return null;
    }
    return _hasBuildingPermit!
        ? 'Approved'
        : 'Secure building permit before proceeding to the next step.';
  }

  String? _computeOccupancyPermitRecommendation() {
    if (_hasOccupancyPermit == null) {
      return null;
    }
    if (_hasOccupancyPermit == false) {
      return 'Secure occupancy permit before proceeding to the next step.';
    }

    final rawYear = _occupancyPermitYearController.text.trim();
    if (rawYear.isEmpty) {
      return null;
    }

    final year = int.tryParse(rawYear);
    final currentYear = DateTime.now().year;
    if (year == null || year < 1900 || year > currentYear) {
      return null;
    }

    final age = currentYear - year;
    if (age <= 15) {
      return 'Approved';
    }
    return 'Issue a Certificate of Structural Permit.';
  }

  void _handleBuildingPermitSelection(bool hasPermit) {
    setState(() {
      _hasBuildingPermit = hasPermit;
      _buildingPermitRecommendation = _computeBuildingPermitRecommendation();
    });
  }

  void _handleOccupancyPermitSelection(bool hasPermit) {
    setState(() {
      _hasOccupancyPermit = hasPermit;
      if (!hasPermit) {
        _occupancyPermitYearController.clear();
      }
      _occupancyPermitRecommendation = _computeOccupancyPermitRecommendation();
    });
  }

  void _handleOccupancyYearChanged(String value) {
    setState(() {
      _occupancyPermitRecommendation = _computeOccupancyPermitRecommendation();
    });
  }

  void _toggleArchitecturalFloorArea(bool enabled) {
    setState(() {
      _architecturalFloorAreaEnabled = enabled;
      if (!enabled) {
        _floorAreaController.clear();
      }
      _computeArchitecturalFees();
    });
  }

  void _toggleArchitecturalAppendage(bool enabled) {
    setState(() {
      _architecturalAppendageEnabled = enabled;
      if (!enabled) {
        _appendageCountController.clear();
      }
      _computeArchitecturalFees();
    });
  }

  void _toggleSanitaryUnits(bool enabled) {
    setState(() {
      _sanitaryUnitsEnabled = enabled;
      if (!enabled) {
        _sanitaryPlumbingUnitsController.clear();
      }
      _computeSanitaryFees();
    });
  }

  void _toggleElectricalFlag(String flag, bool enabled) {
    setState(() {
      switch (flag) {
        case 'connected':
          _electricalConnectedLoadEnabled = enabled;
          if (!enabled) _connectedLoadController.clear();
          break;
        case 'capacity':
          _electricalCapacityEnabled = enabled;
          if (!enabled) _transformerCapacityController.clear();
          break;
        case 'poles':
          _electricalPolesEnabled = enabled;
          if (!enabled) _powerPoleCountController.clear();
          break;
        case 'attachments':
          _electricalAttachmentsEnabled = enabled;
          if (!enabled) _guyingAttachmentCountController.clear();
          break;
        case 'manual':
          _electricalManualEnabled = enabled;
          if (!enabled) _electricalAdditionalFeeController.clear();
          break;
      }
      _computeElectricalFees();
    });
  }

  void _toggleElectronicsGroup(String group, bool enabled) {
    setState(() {
      _electronicsGroupEnabled[group] = enabled;
      if (!enabled) {
        for (final config in _electronicsFeeFieldConfigs.where((c) => c.group == group)) {
          _electronicsFeeControllers[config.key]?.clear();
        }
      }
      _computeElectronicsFees();
    });
  }

  void _toggleElectronicsManual(bool enabled) {
    setState(() {
      _electronicsManualEnabled = enabled;
      if (!enabled) {
        _electronicsAdditionalFeeController.clear();
      }
      _computeElectronicsFees();
    });
  }

  void _toggleMechanicalGroup(String group, bool enabled) {
    setState(() {
      _mechanicalGroupEnabled[group] = enabled;
      if (!enabled) {
        for (final config in _mechanicalFeeFieldConfigs.where((c) => c.group == group)) {
          _mechanicalFeeControllers[config.key]?.clear();
        }
      }
      _computeMechanicalFees();
    });
  }

  void _toggleMechanicalManual(bool enabled) {
    setState(() {
      _mechanicalManualEnabled = enabled;
      if (!enabled) {
        _mechanicalAdditionalFeeController.clear();
      }
      _computeMechanicalFees();
    });
  }

  Widget _buildFeeCard({
    required String title,
    required bool isTablet,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: isTablet ? 12 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          tilePadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 18 : 14,
            vertical: isTablet ? 8 : 6,
          ),
          childrenPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 18 : 14,
            vertical: isTablet ? 14 : 12,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
              letterSpacing: 0.2,
            ),
          ),
          iconColor: const Color(0xFF0F172A),
          collapsedIconColor: const Color(0xFF0F172A),
          children: children,
        ),
      ),
    );
  }

  Widget _buildFeeGroupHeader(String title, bool isTablet) {
    return Padding(
      padding: EdgeInsets.only(
        top: isTablet ? 16 : 12,
        bottom: isTablet ? 8 : 6,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isTablet ? 14 : 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildNumericFeeField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool isTablet,
    bool enabled = true,
    String? helperText,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? 12 : 10),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          suffixText: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14 : 12,
            vertical: isTablet ? 14 : 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFeeSummaryWidget({
    required double total,
    required List<String> breakdown,
    required bool isTablet,
    String emptyMessage = 'No fee inputs provided yet.',
  }) {
    final bool hasData = breakdown.isNotEmpty && total > 0;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: isTablet ? 8 : 6),
      padding: EdgeInsets.all(isTablet ? 14 : 12),
      decoration: BoxDecoration(
        color: hasData ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasData ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Section total: ${_formatCurrency(total)}',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w700,
              color: hasData ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          if (!hasData)
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: isTablet ? 12 : 11,
                color: const Color(0xFF64748B),
              ),
            )
          else
            ...breakdown.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $line',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 11,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArchitecturalFeeCalculator(bool isTablet) {
    return _buildFeeCard(
      title: 'Annual Inspection Fees Calculator',
      isTablet: isTablet,
      children: [
        SwitchListTile.adaptive(
          value: _architecturalFloorAreaEnabled,
          onChanged: _toggleArchitecturalFloorArea,
          contentPadding: EdgeInsets.zero,
          title: const Text('Include floor area computation'),
          subtitle: const Text('Calculates the base fee based on total floor area.'),
        ),
        _buildNumericFeeField(
          controller: _floorAreaController,
          label: 'Floor area covered',
          suffix: 'sq.m',
          isTablet: isTablet,
          enabled: _architecturalFloorAreaEnabled,
          helperText: 'Enter the total floor area in square meters.',
        ),
        SwitchListTile.adaptive(
          value: _architecturalAppendageEnabled,
          onChanged: _toggleArchitecturalAppendage,
          contentPadding: EdgeInsets.zero,
          title: const Text('Include appendages / projections'),
          subtitle: const Text('Enable if the building has balconies, marquees, canopies, etc.'),
        ),
        _buildNumericFeeField(
          controller: _appendageCountController,
          label: 'Appendages / projections',
          suffix: 'units',
          isTablet: isTablet,
          enabled: _architecturalAppendageEnabled,
          helperText: 'For canopies, marquees, awnings, balconies, etc.',
        ),
        _buildFeeSummaryWidget(
          total: _architecturalFeeTotal,
          breakdown: _architecturalFeeBreakdown,
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildSanitaryFeeCalculator(bool isTablet) {
    return _buildFeeCard(
      title: 'Annual Plumbing Inspection Fee',
      isTablet: isTablet,
      children: [
        SwitchListTile.adaptive(
          value: _sanitaryUnitsEnabled,
          onChanged: _toggleSanitaryUnits,
          contentPadding: EdgeInsets.zero,
          title: const Text('Include plumbing fixtures'),
          subtitle: const Text('Enable if fixtures were inspected during the visit.'),
        ),
        _buildNumericFeeField(
          controller: _sanitaryPlumbingUnitsController,
          label: 'Plumbing fixtures inspected',
          suffix: 'units',
          isTablet: isTablet,
          enabled: _sanitaryUnitsEnabled,
          helperText: 'Fee of ₱60.00 is applied per plumbing unit.',
        ),
        _buildFeeSummaryWidget(
          total: _sanitaryFeeTotal,
          breakdown: _sanitaryFeeBreakdown,
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildElectricalFeeCalculator(bool isTablet) {
    return _buildFeeCard(
      title: 'Electrical Inspection Fees',
      isTablet: isTablet,
      children: [
        SwitchListTile.adaptive(
          value: _electricalConnectedLoadEnabled,
          onChanged: (value) => _toggleElectricalFlag('connected', value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Total connected load'),
          subtitle: const Text('Progressive schedule based on kVA.'),
        ),
        _buildNumericFeeField(
          controller: _connectedLoadController,
          label: 'Total connected load',
          suffix: 'kVA',
          isTablet: isTablet,
          enabled: _electricalConnectedLoadEnabled,
          helperText: 'Automatic computation follows the progressive schedule.',
        ),
        SwitchListTile.adaptive(
          value: _electricalCapacityEnabled,
          onChanged: (value) => _toggleElectricalFlag('capacity', value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Transformer / UPS / generator capacity'),
          subtitle: const Text('Enable if auxiliary power equipment is present.'),
        ),
        _buildNumericFeeField(
          controller: _transformerCapacityController,
          label: 'Total transformer / UPS / generator capacity',
          suffix: 'kVA',
          isTablet: isTablet,
          enabled: _electricalCapacityEnabled,
        ),
        SwitchListTile.adaptive(
          value: _electricalPolesEnabled,
          onChanged: (value) => _toggleElectricalFlag('poles', value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Power supply poles'),
        ),
        _buildNumericFeeField(
          controller: _powerPoleCountController,
          label: 'Power supply poles installed',
          suffix: 'poles',
          isTablet: isTablet,
          enabled: _electricalPolesEnabled,
        ),
        SwitchListTile.adaptive(
          value: _electricalAttachmentsEnabled,
          onChanged: (value) => _toggleElectricalFlag('attachments', value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Guying attachments / supports'),
        ),
        _buildNumericFeeField(
          controller: _guyingAttachmentCountController,
          label: 'Guying attachments / supports',
          suffix: 'attachments',
          isTablet: isTablet,
          enabled: _electricalAttachmentsEnabled,
        ),
        SwitchListTile.adaptive(
          value: _electricalManualEnabled,
          onChanged: (value) => _toggleElectricalFlag('manual', value),
          contentPadding: EdgeInsets.zero,
          title: const Text('Manual adjustments / others'),
        ),
        _buildNumericFeeField(
          controller: _electricalAdditionalFeeController,
          label: 'Manual adjustments / others',
          suffix: '₱',
          isTablet: isTablet,
          enabled: _electricalManualEnabled,
          helperText: 'Use for any electrical fees not captured automatically.',
        ),
        _buildFeeSummaryWidget(
          total: _electricalFeeTotal,
          breakdown: _electricalFeeBreakdown,
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _buildElectronicsFeeCalculator(bool isTablet) {
    final List<Widget> children = [];
    for (final entry in _electronicsGroupTitles.entries) {
      final groupFields = _electronicsFeeFieldConfigs.where((config) => config.group == entry.key).toList();
      if (groupFields.isEmpty) continue;
      children.add(
        SwitchListTile.adaptive(
          value: _electronicsGroupEnabled[entry.key]!,
          onChanged: (value) => _toggleElectronicsGroup(entry.key, value),
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value),
          subtitle: const Text('Enable to enter devices under this category.'),
        ),
      );
      if (_electronicsGroupEnabled[entry.key]!) {
        children.addAll(
          groupFields.map(
            (config) => _buildNumericFeeField(
              controller: _electronicsFeeControllers[config.key]!,
              label: config.label,
              suffix: config.unitLabel,
              isTablet: isTablet,
              enabled: true,
              helperText: config.helperText,
            ),
          ),
        );
      }
    }

    children.add(
      SwitchListTile.adaptive(
        value: _electronicsManualEnabled,
        onChanged: _toggleElectronicsManual,
        contentPadding: EdgeInsets.zero,
        title: const Text('Manual electronics adjustments'),
      ),
    );

    children.add(
      _buildNumericFeeField(
        controller: _electronicsAdditionalFeeController,
        label: 'Manual electronics adjustments',
        suffix: '₱',
        isTablet: isTablet,
        enabled: _electronicsManualEnabled,
        helperText: 'Enter any additional electronics-related fees.',
      ),
    );

    children.add(
      _buildFeeSummaryWidget(
        total: _electronicsFeeTotal,
        breakdown: _electronicsFeeBreakdown,
        isTablet: isTablet,
      ),
    );

    children.add(
      _buildFeeSummaryWidget(
        total: _electricalFeeTotal + _electronicsFeeTotal,
        breakdown: _electricalCombinedBreakdown.isEmpty
            ? []
            : _electricalCombinedBreakdown,
        isTablet: isTablet,
        emptyMessage: 'No electrical / electronics fees computed yet.',
      ),
    );

    return _buildFeeCard(
      title: 'Electronics & Low Voltage Systems',
      isTablet: isTablet,
      children: children,
    );
  }

  Widget _buildMechanicalFeeCalculator(bool isTablet) {
    final List<Widget> children = [];

    for (final entry in _mechanicalGroupTitles.entries) {
      final groupFields = _mechanicalFeeFieldConfigs.where((config) => config.group == entry.key).toList();
      if (groupFields.isEmpty) continue;
      children.add(
        SwitchListTile.adaptive(
          value: _mechanicalGroupEnabled[entry.key]!,
          onChanged: (value) => _toggleMechanicalGroup(entry.key, value),
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value),
          subtitle: const Text('Enable to capture equipment under this category.'),
        ),
      );
      if (_mechanicalGroupEnabled[entry.key]!) {
        children.addAll(
          groupFields.map(
            (config) => _buildNumericFeeField(
              controller: _mechanicalFeeControllers[config.key]!,
              label: config.label,
              suffix: config.unitLabel,
              isTablet: isTablet,
              enabled: true,
              helperText: config.helperText,
            ),
          ),
        );
      }
    }

    children.add(
      SwitchListTile.adaptive(
        value: _mechanicalManualEnabled,
        onChanged: _toggleMechanicalManual,
        contentPadding: EdgeInsets.zero,
        title: const Text('Manual mechanical adjustments'),
      ),
    );

    children.add(
      _buildNumericFeeField(
        controller: _mechanicalAdditionalFeeController,
        label: 'Manual mechanical adjustments',
        suffix: '₱',
        isTablet: isTablet,
        enabled: _mechanicalManualEnabled,
        helperText: 'Enter any additional or miscellaneous mechanical charges.',
      ),
    );

    children.add(
      _buildFeeSummaryWidget(
        total: _mechanicalFeeTotal,
        breakdown: _mechanicalFeeBreakdown,
        isTablet: isTablet,
      ),
    );

    return _buildFeeCard(
      title: 'Mechanical Inspection Fees',
      isTablet: isTablet,
      children: children,
    );
  }

  void _recomputeAllFees() {
    _computeArchitecturalFees();
    _computeSanitaryFees();
    _computeElectricalFees();
    _computeElectronicsFees();
    _computeMechanicalFees();
  }

  String _formatCurrency(double value) => _currencyFormatter.format(
        value.isNaN || value.isInfinite ? 0 : value,
      );

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    if (value == value.floorToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  bool _isAutoGeneratedAssessment(String text) => text.trim().startsWith('Total Fees:');

  void _updateSectionAssessment(String section, double total, String summary) {
    final controller = _assessmentControllers[section];
    if (controller == null) return;

    if (total <= 0) {
      if (_isAutoGeneratedAssessment(controller.text)) {
        controller.clear();
      }
      return;
    }

    final buffer = StringBuffer('Total Fees: ${_formatCurrency(total)}');
    if (summary.trim().isNotEmpty) {
      buffer.writeln();
      buffer.write(summary.trim());
    }

    final newText = buffer.toString();
    if (controller.text != newText) {
      controller.text = newText;
    }
  }

  double _calculateFloorAreaFee(double area) {
    if (area <= 0) return 0;
    if (area <= 100) return 120;
    if (area <= 200) return 240;
    if (area <= 350) return 480;
    if (area <= 500) return 720;
    if (area <= 750) return 960;
    if (area <= 1000) return 1200;
    final excess = area - 1000;
    final increments = (excess / 1000).ceil();
    return 1200 + (increments * 1200);
  }

  void _computeArchitecturalFees() {
    final double floorArea = _architecturalFloorAreaEnabled
        ? double.tryParse(_floorAreaController.text) ?? 0
        : 0;
    final int appendages = _architecturalAppendageEnabled
        ? int.tryParse(_appendageCountController.text) ?? 0
        : 0;

    final double floorFee = _calculateFloorAreaFee(floorArea);
    final double appendageFee = appendages > 0 ? appendages * 150.0 : 0.0;

    final double total = floorFee + appendageFee;
    final List<String> breakdown = [];
    if (floorFee > 0) {
      breakdown.add(
        'Floor area (${_formatNumber(floorArea)} sq.m): ${_formatCurrency(floorFee)}',
      );
    }
    if (appendageFee > 0) {
      breakdown.add(
        'Appendages ($appendages units): ${_formatCurrency(appendageFee)}',
      );
    }

    setState(() {
      _architecturalFeeTotal = total;
      _architecturalFeeBreakdown = breakdown;
    });

    _updateSectionAssessment('Architectural', total, breakdown.join('\n'));
  }

  void _computeSanitaryFees() {
    final int units = _sanitaryUnitsEnabled
        ? int.tryParse(_sanitaryPlumbingUnitsController.text) ?? 0
        : 0;
    final double total = units * 60.0;
    final List<String> breakdown = [];
    if (units > 0) {
      breakdown.add('Plumbing inspection fee ($units unit${units == 1 ? '' : 's'}): ${_formatCurrency(total)}');
    }

    setState(() {
      _sanitaryFeeTotal = total;
      _sanitaryFeeBreakdown = breakdown;
    });

    _updateSectionAssessment('Sanitary/Plumbing', total, breakdown.join('\n'));
  }

  double _calculateConnectedLoadFee(double load) {
    if (load <= 0) return 0;
    if (load <= 5) return 200;
    if (load <= 50) {
      return 200 + (load - 5) * 20;
    }
    if (load <= 300) {
      return 1100 + (load - 50) * 10;
    }
    if (load <= 1500) {
      return 3600 + (load - 300) * 5;
    }
    if (load <= 6000) {
      return 9600 + (load - 1500) * 2.5;
    }
    return 20850 + (load - 6000) * 1.25;
  }

  double _calculateTransformerCapacityFee(double capacity) {
    if (capacity <= 0) return 0;
    if (capacity <= 5) return 40;
    if (capacity <= 50) {
      return 40 + (capacity - 5) * 4;
    }
    if (capacity <= 300) {
      return 220 + (capacity - 50) * 2;
    }
    if (capacity <= 1500) {
      return 720 + (capacity - 300) * 1;
    }
    if (capacity <= 6000) {
      return 1920 + (capacity - 1500) * 0.5;
    }
    return 4170 + (capacity - 6000) * 0.25;
  }

  void _computeElectricalFees() {
    final double connectedLoad = _electricalConnectedLoadEnabled
        ? double.tryParse(_connectedLoadController.text) ?? 0
        : 0;
    final double transformerCapacity = _electricalCapacityEnabled
        ? double.tryParse(_transformerCapacityController.text) ?? 0
        : 0;
    final int poleCount = _electricalPolesEnabled
        ? int.tryParse(_powerPoleCountController.text) ?? 0
        : 0;
    final int attachmentCount = _electricalAttachmentsEnabled
        ? int.tryParse(_guyingAttachmentCountController.text) ?? 0
        : 0;
    final double manualAdjustments = _electricalManualEnabled
        ? double.tryParse(_electricalAdditionalFeeController.text) ?? 0
        : 0;

    final double connectedLoadFee = _calculateConnectedLoadFee(connectedLoad);
    final double capacityFee = _calculateTransformerCapacityFee(transformerCapacity);
    final double poleFee = poleCount * 30.0;
    final double attachmentFee = attachmentCount * 30.0;

    final double total = connectedLoadFee + capacityFee + poleFee + attachmentFee + manualAdjustments;

    final List<String> breakdown = [];
    if (connectedLoadFee > 0) {
      breakdown.add(
        'Total connected load (${_formatNumber(connectedLoad)} kVA): ${_formatCurrency(connectedLoadFee)}',
      );
    }
    if (capacityFee > 0) {
      breakdown.add(
        'Transformer / UPS / generator capacity (${_formatNumber(transformerCapacity)} kVA): ${_formatCurrency(capacityFee)}',
      );
    }
    if (poleFee > 0) {
      breakdown.add('Power supply poles ($poleCount): ${_formatCurrency(poleFee)}');
    }
    if (attachmentFee > 0) {
      breakdown.add('Guying attachments ($attachmentCount): ${_formatCurrency(attachmentFee)}');
    }
    if (manualAdjustments > 0) {
      breakdown.add('Additional adjustments: ${_formatCurrency(manualAdjustments)}');
    }

    setState(() {
      _electricalFeeTotal = total;
      _electricalFeeBreakdown = breakdown;
    });

    _updateElectricalSectionAssessment();
  }

  void _computeElectronicsFees() {
    double total = 0;
    final List<String> breakdown = [];

    for (final config in _electronicsFeeFieldConfigs) {
      if (!_electronicsGroupEnabled[config.group]!) {
        continue;
      }
      final controller = _electronicsFeeControllers[config.key];
      if (controller == null) continue;
      final double value = double.tryParse(controller.text) ?? 0;
      if (value <= 0) continue;
      final double fee = value * config.rate;
      total += fee;
      breakdown.add(
        '${config.shortLabel}: ${_formatCurrency(fee)} (${_formatNumber(value)} ${config.unitLabel})',
      );
    }

    final double manual = _electronicsManualEnabled
        ? double.tryParse(_electronicsAdditionalFeeController.text) ?? 0
        : 0;
    if (manual > 0) {
      total += manual;
      breakdown.add('Additional electronics adjustments: ${_formatCurrency(manual)}');
    }

    setState(() {
      _electronicsFeeTotal = total;
      _electronicsFeeBreakdown = breakdown;
    });

    _updateElectricalSectionAssessment();
  }

  void _computeMechanicalFees() {
    double total = 0;
    final List<String> breakdown = [];

    for (final config in _mechanicalFeeFieldConfigs) {
      if (!_mechanicalGroupEnabled[config.group]!) {
        continue;
      }
      final controller = _mechanicalFeeControllers[config.key];
      if (controller == null) continue;
      final double value = double.tryParse(controller.text) ?? 0;
      if (value <= 0) continue;
      final double fee = value * config.rate;
      total += fee;
      breakdown.add(
        '${config.shortLabel}: ${_formatCurrency(fee)} (${_formatNumber(value)} ${config.unitLabel})',
      );
    }

    final double manualAdjustments = _mechanicalManualEnabled
        ? double.tryParse(_mechanicalAdditionalFeeController.text) ?? 0
        : 0;
    if (manualAdjustments > 0) {
      total += manualAdjustments;
      breakdown.add('Additional mechanical adjustments: ${_formatCurrency(manualAdjustments)}');
    }

    setState(() {
      _mechanicalFeeTotal = total;
      _mechanicalFeeBreakdown = breakdown;
    });

    _updateSectionAssessment('Mechanical', total, breakdown.join('\n'));
  }

  void _updateElectricalSectionAssessment() {
    final double total = _electricalFeeTotal + _electronicsFeeTotal;
    final List<String> combined = [];

    if (_electricalFeeBreakdown.isNotEmpty) {
      combined.add('Electrical fees subtotal: ${_formatCurrency(_electricalFeeTotal)}');
      combined.addAll(
        _electricalFeeBreakdown.map((line) => '  $line'),
      );
    }

    if (_electronicsFeeBreakdown.isNotEmpty) {
      combined.add('Electronics fees subtotal: ${_formatCurrency(_electronicsFeeTotal)}');
      combined.addAll(
        _electronicsFeeBreakdown.map((line) => '  $line'),
      );
    }

    setState(() {
      _electricalCombinedBreakdown = combined;
    });

    _updateSectionAssessment('Electrical/Electronics', total, combined.join('\n'));
  }

  Widget _buildSectionSelection(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Select Inspection Sections',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Choose which sections you want to inspect:',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _selectedSections.isNotEmpty 
                ? _selectedSections.keys.map((section) {
                    return _buildSectionChip(section, isTablet);
                  }).toList()
                : [],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChip(String section, bool isTablet) {
    final isSelected = _selectedSections[section] ?? false;
    final sectionData = _getSectionData(section);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSections[section] = !isSelected;
          // Initialize media paths only if absent; do not overwrite existing media
          if (!isSelected) {
            _sectionImagePaths.putIfAbsent(section, () => []);
            _sectionVideoPaths.putIfAbsent(section, () => []);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 12 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? sectionData['color'] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? sectionData['color'] : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sectionData['icon'],
              color: isSelected ? Colors.white : sectionData['color'],
              size: isTablet ? 20 : 18,
            ),
            const SizedBox(width: 8),
            Text(
              section,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSelectedSections(BuildContext context, bool isTablet) {
    if (_selectedSections.isEmpty) {
      return [];
    }
    
    final selectedSections = _selectedSections.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedSections.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: const Color(0xFF6B7280),
                size: isTablet ? 48 : 40,
              ),
              const SizedBox(height: 16),
              Text(
                'No sections selected',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please select at least one inspection section above.',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }

    return selectedSections.map((section) {
      try {
        // Ensure media paths are initialized for this section
        if (_sectionImagePaths[section] == null) {
          _sectionImagePaths[section] = [];
        }
        if (_sectionVideoPaths[section] == null) {
          _sectionVideoPaths[section] = [];
        }
        
        final sectionData = _getSectionData(section);
        return Column(
          children: [
            _buildDynamicSectionCard(
              context,
              isTablet,
              section,
              sectionData['icon'],
              sectionData['color'],
            ),
            const SizedBox(height: 16),
          ],
        );
      } catch (e) {
        print('Error building section $section: $e');
        return Container(); // Return empty container on error
      }
    }).toList();
  }

  Map<String, dynamic> _getSectionData(String section) {
    switch (section) {
      case 'Mechanical':
        return {
          'icon': Icons.build_rounded,
          'color': const Color(0xFF10B981),
        };
      case 'Line and Grade':
        return {
          'icon': Icons.straighten_rounded,
          'color': const Color(0xFF3B82F6),
        };
      case 'Architectural':
        return {
          'icon': Icons.architecture_rounded,
          'color': const Color(0xFF8B5CF6),
        };
      case 'Civil/Structural':
        return {
          'icon': Icons.construction_rounded,
          'color': const Color(0xFFF59E0B),
        };
      case 'Sanitary/Plumbing':
        return {
          'icon': Icons.plumbing_rounded,
          'color': const Color(0xFF06B6D4),
        };
      case 'Electrical/Electronics':
        return {
          'icon': Icons.electrical_services_rounded,
          'color': const Color(0xFFEF4444),
        };
      default:
        return {
          'icon': Icons.construction_rounded,
          'color': const Color(0xFF6B7280),
        };
    }
  }

  Widget _buildDynamicSectionCard(
    BuildContext context,
    bool isTablet,
    String title,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3748),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Status Selection
          _buildStatusSelection(title, isTablet, color),
          const SizedBox(height: 20),
          
          if (title == 'Architectural') ...[
            _buildArchitecturalFeeCalculator(isTablet),
            const SizedBox(height: 20),
          ],
          if (title == 'Sanitary/Plumbing') ...[
            _buildSanitaryFeeCalculator(isTablet),
            const SizedBox(height: 20),
          ],
          if (title == 'Electrical/Electronics') ...[
            _buildElectricalFeeCalculator(isTablet),
            _buildElectronicsFeeCalculator(isTablet),
            const SizedBox(height: 20),
          ],
          if (title == 'Mechanical') ...[
            _buildMechanicalFeeCalculator(isTablet),
            const SizedBox(height: 20),
          ],

          // Map for Civil/Structural section
          if (title == 'Civil/Structural') ...[
            _buildMapSection(title, isTablet, color),
            const SizedBox(height: 20),
          ],
          
          // Remarks Field
          Text(
            'Remarks',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _remarksControllers[title],
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter remarks for $title...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          
          // Assessment Field
          Text(
            'Assessment',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _assessmentControllers[title],
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter assessment for $title...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),
          
          // Media Capture Section
          _buildMediaCaptureSection(title, isTablet, color),
        ],
      ),
    );
  }

  Widget _buildStatusSelection(String section, bool isTablet, Color color) {
    final currentStatus = _sectionStatus[section] ?? 'not_passed';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildStatusChip(
              'Not Passed',
              'not_passed',
              currentStatus,
              const Color(0xFFEF4444),
              Icons.close_rounded,
              isTablet,
              () => _updateStatus(section, 'not_passed'),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              'In Progress',
              'in_progress',
              currentStatus,
              const Color(0xFFF59E0B),
              Icons.hourglass_empty_rounded,
              isTablet,
              () => _updateStatus(section, 'in_progress'),
            ),
            const SizedBox(width: 8),
            _buildStatusChip(
              'Passed',
              'passed',
              currentStatus,
              const Color(0xFF10B981),
              Icons.check_circle_rounded,
              isTablet,
              () => _updateStatus(section, 'passed'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    String label,
    String value,
    String currentStatus,
    Color color,
    IconData icon,
    bool isTablet,
    VoidCallback onTap,
  ) {
    final isSelected = currentStatus == value;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 12 : 8,
          vertical: isTablet ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: isTablet ? 16 : 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(String section, String status) {
    setState(() {
      _sectionStatus[section] = status;
    });
  }

  Widget _buildMediaCaptureSection(String title, bool isTablet, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Media Capture (Optional)',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Add photos or videos to document your inspection:',
          style: TextStyle(
            fontSize: isTablet ? 12 : 10,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        MediaCaptureWidget(
          imagePaths: _sectionImagePaths[title] ?? [],
          videoPaths: _sectionVideoPaths[title] ?? [],
          onImagesChanged: (images) {
            setState(() {
              _sectionImagePaths[title] = images;
            });
          },
          onVideosChanged: (videos) {
            setState(() {
              _sectionVideoPaths[title] = videos;
            });
          },
          isTablet: isTablet,
          sectionName: title,
        ),
      ],
    );
  }

  Widget _buildMapSection(String title, bool isTablet, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.map_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Location Mapping',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tap on the map to mark the inspection location:',
          style: TextStyle(
            fontSize: isTablet ? 12 : 10,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        MapWidget(
          title: 'Civil/Structural Inspection Location',
          initialLocation: _civilStructuralLocation,
          enableLocationPicker: true,
          showSearchBar: true,
          showAddressInfo: true,
          height: 450,
          customMarkerColor: const Color(0xFF3B82F6), // Blue color for pin pointer
          onLocationSelected: (location) {
            setState(() {
              _civilStructuralLocation = location;
            });
          },
        ),
        if (_civilStructuralLocation != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0EA5E9), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF0EA5E9),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location marked: ${_civilStructuralLocation!.latitude.toStringAsFixed(8)}, ${_civilStructuralLocation!.longitude.toStringAsFixed(8)}',
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
        ],
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, bool isTablet) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 16 : 14,
            horizontal: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            SizedBox(width: isTablet ? 12 : 8),
            Text(
              'Submit Inspection',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
    // Check if at least one section is selected
    if (_selectedSections.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Sections Available'),
          content: const Text('Please wait for the form to load completely.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    final selectedSections = _selectedSections.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedSections.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Sections Selected'),
          content: const Text('Please select at least one inspection section before submitting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final String? buildingRecommendation = _computeBuildingPermitRecommendation();
      final String? occupancyRecommendation = _computeOccupancyPermitRecommendation();
      final int? occupancyIssuedYear = _hasOccupancyPermit == true
          ? int.tryParse(_occupancyPermitYearController.text.trim())
          : null;

      setState(() {
        _buildingPermitRecommendation = buildingRecommendation;
        _occupancyPermitRecommendation = occupancyRecommendation;
      });

      try {
        // Set inspection end time when submitting
        _inspectionEndTime = DateTime.now();
        
        // Get current user ID
        final currentUser = await AuthService.getCurrentUser();
        final userId = currentUser?.id.toString();

        // Collect all media from all sections (avoid duplicates)
        final allImagePaths = _sectionImagePaths.values
            .whereType<List<String>>()
            .expand((paths) => paths)
            .toSet()
            .toList();
        final allVideoPaths = _sectionVideoPaths.values
            .whereType<List<String>>()
            .expand((paths) => paths)
            .toSet()
            .toList();

        // Build section status map, keeping every stored status value
        final Map<String, String> savedSectionStatus = Map.fromEntries(
          _sectionStatus.entries.where((entry) => entry.value.trim().isNotEmpty),
        );

        if (widget.isEditing && widget.existingInspection != null) {
          widget.existingInspection!.sectionStatus.forEach((section, value) {
            if (!savedSectionStatus.containsKey(section) && value.isNotEmpty) {
              savedSectionStatus[section] = value;
            }
          });
        }

        // Create inspection object with dynamic data
        final inspection = widget.isEditing && widget.existingInspection != null
            ? Inspection(
                id: widget.existingInspection!.id, // Keep existing ID
                scannedData: widget.existingInspection!.scannedData, // Keep existing scanned data
                mechanicalRemarks: _getSectionText('Mechanical', 'remarks'),
                mechanicalAssessment: _getSectionText('Mechanical', 'assessment'),
                lineGradeRemarks: _getSectionText('Line and Grade', 'remarks'),
                lineGradeAssessment: _getSectionText('Line and Grade', 'assessment'),
                architecturalRemarks: _getSectionText('Architectural', 'remarks'),
                architecturalAssessment: _getSectionText('Architectural', 'assessment'),
                civilStructuralRemarks: _getSectionText('Civil/Structural', 'remarks'),
                civilStructuralAssessment: _getSectionText('Civil/Structural', 'assessment'),
                sanitaryPlumbingRemarks: _getSectionText('Sanitary/Plumbing', 'remarks'),
                sanitaryPlumbingAssessment: _getSectionText('Sanitary/Plumbing', 'assessment'),
                electricalElectronicsRemarks: _getSectionText('Electrical/Electronics', 'remarks'),
                electricalElectronicsAssessment: _getSectionText('Electrical/Electronics', 'assessment'),
                imagePaths: allImagePaths,
                videoPaths: allVideoPaths,
                sectionImagePaths: _cloneSectionMediaMap(_sectionImagePaths),
                sectionVideoPaths: _cloneSectionMediaMap(_sectionVideoPaths),
                inspectionStartTime: _inspectionStartTime,
                inspectionEndTime: _inspectionEndTime,
                sectionStatus: Map<String, String>.from(savedSectionStatus),
                isSynced: false,
                createdAt: widget.existingInspection!.createdAt, // Keep original creation time
                updatedAt: DateTime.now(), // Update modification time
                userId: widget.existingInspection!.userId,
                latitude: _civilStructuralLocation?.latitude,
                longitude: _civilStructuralLocation?.longitude,
                hasBuildingPermit: _hasBuildingPermit,
                buildingPermitRecommendation: buildingRecommendation,
                hasOccupancyPermit: _hasOccupancyPermit,
                occupancyPermitIssuedYear: occupancyIssuedYear,
                occupancyPermitRecommendation: occupancyRecommendation,
              )
            : Inspection.fromFormData(
                scannedData: widget.scannedData ?? 'No QR data',
                mechanicalRemarks: _getSectionText('Mechanical', 'remarks'),
                mechanicalAssessment: _getSectionText('Mechanical', 'assessment'),
                lineGradeRemarks: _getSectionText('Line and Grade', 'remarks'),
                lineGradeAssessment: _getSectionText('Line and Grade', 'assessment'),
                architecturalRemarks: _getSectionText('Architectural', 'remarks'),
                architecturalAssessment: _getSectionText('Architectural', 'assessment'),
                civilStructuralRemarks: _getSectionText('Civil/Structural', 'remarks'),
                civilStructuralAssessment: _getSectionText('Civil/Structural', 'assessment'),
                sanitaryPlumbingRemarks: _getSectionText('Sanitary/Plumbing', 'remarks'),
                sanitaryPlumbingAssessment: _getSectionText('Sanitary/Plumbing', 'assessment'),
                electricalElectronicsRemarks: _getSectionText('Electrical/Electronics', 'remarks'),
                electricalElectronicsAssessment: _getSectionText('Electrical/Electronics', 'assessment'),
                userId: userId,
                latitude: _civilStructuralLocation?.latitude,
                longitude: _civilStructuralLocation?.longitude,
                imagePaths: allImagePaths,
                videoPaths: allVideoPaths,
                sectionImagePaths: _cloneSectionMediaMap(_sectionImagePaths),
                sectionVideoPaths: _cloneSectionMediaMap(_sectionVideoPaths),
                inspectionStartTime: _inspectionStartTime,
                inspectionEndTime: _inspectionEndTime,
                sectionStatus: Map<String, String>.from(savedSectionStatus),
                hasBuildingPermit: _hasBuildingPermit,
                buildingPermitRecommendation: buildingRecommendation,
                hasOccupancyPermit: _hasOccupancyPermit,
                occupancyPermitIssuedYear: occupancyIssuedYear,
                occupancyPermitRecommendation: occupancyRecommendation,
              );

        // Save to Hive database first (offline-first approach)
        await HiveOfflineDatabase.saveInspection(inspection);
        
        print('Inspection saved to Hive: ${inspection.id}');
        print('Scanned data: ${inspection.scannedData}');
        print('Selected sections: $selectedSections');
        print('Images captured: ${allImagePaths.length}');
        print('Videos captured: ${allVideoPaths.length}');
        print('Inspection duration: ${_calculateDuration()}');

        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(widget.isEditing ? 'Inspection Updated' : 'Inspection Submitted'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your inspection for ${selectedSections.length} section(s) has been ${widget.isEditing ? 'updated' : 'saved'} successfully${allImagePaths.isNotEmpty || allVideoPaths.isNotEmpty ? ' with ${allImagePaths.length} photo(s) and ${allVideoPaths.length} video(s)' : ''}${_inspectionStartTime != null && _inspectionEndTime != null ? ' (Duration: ${_calculateDuration()})' : ''}.'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saved locally. Use "Export Report" in Inspection Reports when you are online to send this to the server.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to previous screen
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        print('Error saving inspection: $e');
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to save inspection: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  String _getSectionText(String section, String type) {
    if (type == 'remarks') {
      return _remarksControllers[section]?.text ?? '';
    } else if (type == 'assessment') {
      return _assessmentControllers[section]?.text ?? '';
    }
    return '';
  }

  Widget _buildCalculatorFAB(BuildContext context, bool isTablet) {
    return FloatingActionButton(
      onPressed: () => _showCalculator(context, isTablet),
      backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
      foregroundColor: Colors.white,
      elevation: 8,
      child: const Icon(Icons.calculate_rounded, size: 28),
    );
  }

  void _showCalculator(BuildContext context, bool isTablet) {
    showDialog(
      context: context,
      builder: (context) => CalculatorDialog(isTablet: isTablet),
    );
  }
}

class CalculatorDialog extends StatefulWidget {
  final bool isTablet;
  
  const CalculatorDialog({super.key, required this.isTablet});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> with TickerProviderStateMixin {
  String _display = '0';
  String _operation = '';
  double _firstNumber = 0;
  double _secondNumber = 0;
  bool _waitingForOperand = false;
  
  // Memory functions
  double _memory = 0;
  bool _memoryIndicator = false;
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 900;
    final isSmallScreen = screenHeight < 600;
    
    // Responsive sizing
    final dialogWidth = isLargeTablet 
        ? screenWidth * 0.5 
        : isTablet 
            ? screenWidth * 0.7 
            : screenWidth * 0.9;
    final dialogHeight = isSmallScreen 
        ? screenHeight * 0.85 
        : isLargeTablet 
            ? screenHeight * 0.75 
            : isTablet 
                ? screenHeight * 0.8 
                : screenHeight * 0.85;
    
    final headerPadding = isTablet ? 24.0 : 16.0;
    final buttonSpacing = isTablet ? 8.0 : 6.0;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        constraints: BoxConstraints(
          maxWidth: isTablet ? 600 : double.infinity,
          maxHeight: screenHeight * 0.9,
        ),
        padding: EdgeInsets.all(headerPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(8, 111, 222, 0.977),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calculate_rounded,
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 10),
                Expanded(
                  child: Text(
                    'Professional Calculator',
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                ),
                if (_memoryIndicator)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 8,
                      vertical: isTablet ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'M',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 13 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                SizedBox(width: isTablet ? 10 : 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: isTablet ? 24 : 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: const Color(0xFF6B7280),
                    padding: EdgeInsets.all(isTablet ? 12 : 8),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 20 : 16),
            
            // Realistic Calculator Display (LCD-style)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 24 : 20,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E293B), // Dark slate
                    Color(0xFF0F172A), // Darker slate
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  const BoxShadow(
                    color: Color(0xFF1E293B),
                    blurRadius: 2,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Operation display (smaller, secondary)
                  if (_operation.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: isTablet ? 8 : 6),
                      child: Text(
                        _formatOperation(_firstNumber, _operation),
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 14,
                          color: const Color(0xFF94A3B8),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Main display
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatDisplay(_display),
                      style: TextStyle(
                        fontSize: isTablet ? 48 : 36,
                        fontWeight: FontWeight.w300,
                        color: const Color(0xFFE2E8F0), // Light text on dark background
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isTablet ? 20 : 16),
            
            // Calculator Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildUnifiedCalculator(isTablet, buttonSpacing),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDisplay(String display) {
    // Format large numbers with commas for readability
    if (display == 'Error' || display == 'Infinity' || display == 'NaN') {
      return display;
    }
    
    // Handle scientific notation
    if (display.contains('e') || display.contains('E')) {
      return display;
    }
    
    try {
      final num = double.parse(display);
      if (num.isInfinite || num.isNaN) {
        return 'Error';
      }
      
      if (num % 1 == 0) {
        // Integer - format with commas
        final intValue = num.toInt();
        if (intValue.abs() > 999) {
          return intValue.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
        }
        return intValue.toString();
      } else {
        // Decimal - format with appropriate precision
        final parts = display.split('.');
        if (parts.length == 2) {
          // Remove trailing zeros
          final decimalPart = parts[1].replaceAll(RegExp(r'0+$'), '');
          final integerPart = int.tryParse(parts[0]) ?? 0;
          
          if (integerPart.abs() > 999) {
            final formattedInt = integerPart.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            );
            return decimalPart.isEmpty ? formattedInt : '$formattedInt.$decimalPart';
          }
          
          return decimalPart.isEmpty ? integerPart.toString() : '$integerPart.$decimalPart';
        }
      }
    } catch (e) {
      // If parsing fails, return as is
    }
    return display;
  }
  
  String _formatOperation(double number, String operation) {
    final formatted = number % 1 == 0 
        ? number.toInt().toString()
        : number.toString();
    return '$formatted ${_getOperationSymbol(operation)}';
  }
  
  String _getOperationSymbol(String operation) {
    switch (operation) {
      case '+':
        return '+';
      case '-':
        return '−';
      case '×':
        return '×';
      case '÷':
        return '÷';
      case '^':
        return '^';
      default:
        return operation;
    }
  }

  // Unified Calculator
  Widget _buildUnifiedCalculator(bool isTablet, double buttonSpacing) {
    return Column(
      children: [
        // Memory functions row
        _buildButtonRow(['MC', 'MR', 'M+', 'M-'], isTablet, isLastRow: false),
        SizedBox(height: buttonSpacing),
        
        // Scientific functions row 1
        _buildButtonRow(['π', 'e', '√', 'x²'], isTablet, isLastRow: false),
        SizedBox(height: buttonSpacing),
        
        // Scientific functions row 2
        _buildButtonRow(['sin', 'cos', 'tan', 'log'], isTablet, isLastRow: false),
        SizedBox(height: buttonSpacing),
        
        // Scientific functions row 3
        _buildButtonRow(['ln', '1/x', 'x!', '^'], isTablet, isLastRow: false),
        SizedBox(height: buttonSpacing),
        
        // Basic operations row 1
        _buildButtonRow(['(', ')', 'C', '÷'], isTablet, isLastRow: false),
        SizedBox(height: buttonSpacing),
        
        // Basic operations row 2
        _buildButtonRow(['7', '8', '9', '×'], isTablet, isLastRow: false),
        SizedBox(height: buttonSpacing),
        
        // Basic operations row 3
        _buildButtonRow(['4', '5', '6', '-'], isTablet, isLastRow: false),
        SizedBox(height: buttonSpacing),
        
        // Basic operations row 4
        _buildButtonRow(['1', '2', '3', '+'], isTablet, isLastRow: false),
        SizedBox(height: buttonSpacing),
        
        // Basic operations row 5
        _buildButtonRow(['±', '0', '.', '='], isTablet, isLastRow: true),
      ],
    );
  }


  Widget _buildButtonRow(List<String> buttons, bool isTablet, {bool isLastRow = false}) {
    return Row(
      children: buttons.map((button) {
        if (isLastRow && button == '0') {
          // Make 0 button wider
          return Expanded(
            flex: 2,
            child: _buildCalculatorButton(button, isTablet),
          );
        } else {
          return Expanded(
            child: _buildCalculatorButton(button, isTablet),
          );
        }
      }).toList(),
    );
  }


  Widget _buildCalculatorButton(String text, bool isTablet) {
    final bool isNumber = RegExp(r'[0-9]').hasMatch(text);
    final bool isOperator = ['+', '-', '×', '÷', '='].contains(text);
    final bool isMemory = ['MC', 'MR', 'M+', 'M-'].contains(text);
    final bool isSpecial = ['C', '±', '%'].contains(text);
    final bool isScientific = ['π', 'e', '√', 'x²', 'sin', 'cos', 'tan', 'log', 'ln', '1/x', 'x!', '^', '(', ')'].contains(text);
    final bool isDecimal = text == '.';

    Color backgroundColor;
    Color textColor;

    if (isNumber || isDecimal) {
      backgroundColor = Colors.white;
      textColor = const Color(0xFF1F2937);
    } else if (isOperator) {
      backgroundColor = const Color.fromRGBO(8, 111, 222, 0.977);
      textColor = Colors.white;
    } else if (isMemory) {
      backgroundColor = const Color(0xFF10B981);
      textColor = Colors.white;
    } else if (isScientific) {
      backgroundColor = const Color(0xFF8B5CF6);
      textColor = Colors.white;
    } else if (isSpecial) {
      backgroundColor = const Color(0xFFF3F4F6);
      textColor = const Color(0xFF6B7280);
    } else {
      backgroundColor = Colors.white;
      textColor = const Color(0xFF1F2937);
    }

    // Responsive button sizing
    final buttonHeight = isTablet ? 56.0 : 48.0;
    final buttonMargin = isTablet ? 6.0 : 4.0;
    final fontSize = isTablet ? 18.0 : 16.0;
    final minFontSize = isTablet ? 14.0 : 12.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: buttonMargin),
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: () => _onButtonPressed(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 14 : 12,
            horizontal: isTablet ? 8 : 6,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            textScaleFactor: 1.0,
          ),
        ),
      ),
    );
  }

  void _onButtonPressed(String buttonText) {
    setState(() {
      if (RegExp(r'[0-9]').hasMatch(buttonText)) {
        _onNumberPressed(buttonText);
      } else if (buttonText == '.') {
        _onDecimalPressed();
      } else if (['+', '-', '×', '÷'].contains(buttonText)) {
        _onOperatorPressed(buttonText);
      } else if (buttonText == '=') {
        _onEqualsPressed();
      } else if (buttonText == 'C') {
        _onClearPressed();
      } else if (buttonText == '±') {
        _onSignPressed();
      } else if (buttonText == '%') {
        _onPercentPressed();
      } else if (['MC', 'MR', 'M+', 'M-'].contains(buttonText)) {
        _onMemoryPressed(buttonText);
      } else if (['π', 'e', '√', 'x²', 'sin', 'cos', 'tan', 'log', 'ln', '1/x', 'x!', '^'].contains(buttonText)) {
        _onScientificPressed(buttonText);
      } else if (['(', ')'].contains(buttonText)) {
        _onParenthesisPressed(buttonText);
      }
    });
  }

  void _onNumberPressed(String number) {
    if (_waitingForOperand) {
      _display = number;
      _waitingForOperand = false;
    } else {
      _display = _display == '0' ? number : _display + number;
    }
  }

  void _onDecimalPressed() {
    if (_waitingForOperand) {
      _display = '0.';
      _waitingForOperand = false;
    } else if (!_display.contains('.')) {
      _display += '.';
    }
  }

  void _onOperatorPressed(String operator) {
    if (_operation.isNotEmpty && !_waitingForOperand) {
      _onEqualsPressed();
    }

    _firstNumber = double.parse(_display);
    _operation = operator;
    _waitingForOperand = true;
  }

  void _onEqualsPressed() {
    if (_operation.isEmpty) return;

    _secondNumber = double.parse(_display);
    double result = 0;

    switch (_operation) {
      case '+':
        result = _firstNumber + _secondNumber;
        break;
      case '-':
        result = _firstNumber - _secondNumber;
        break;
      case '×':
        result = _firstNumber * _secondNumber;
        break;
      case '÷':
        if (_secondNumber != 0) {
          result = _firstNumber / _secondNumber;
        } else {
          _display = 'Error';
          return;
        }
        break;
      case '^':
        result = pow(_firstNumber, _secondNumber).toDouble();
        break;
    }

    // Format result appropriately
    if (result.isInfinite || result.isNaN) {
      _display = 'Error';
    } else {
      // Limit decimal places for very large numbers
      if (result.abs() > 1000000) {
        _display = result.toStringAsExponential(6);
      } else if (result.abs() < 0.000001 && result != 0) {
        _display = result.toStringAsExponential(6);
      } else {
        // Format with appropriate decimal places
        final formatted = result.toStringAsFixed(10).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
        _display = formatted;
      }
    }
    
    _operation = '';
    _waitingForOperand = true;
  }

  void _onClearPressed() {
    _display = '0';
    _operation = '';
    _firstNumber = 0;
    _secondNumber = 0;
    _waitingForOperand = false;
  }

  void _onSignPressed() {
    if (_display != '0') {
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else {
        _display = '-$_display';
      }
    }
  }

  void _onPercentPressed() {
    double number = double.parse(_display);
    _display = (number / 100).toString();
  }

  // Memory functions
  void _onMemoryPressed(String operation) {
    double currentValue = double.parse(_display);
    
    switch (operation) {
      case 'MC':
        _memory = 0;
        _memoryIndicator = false;
        break;
      case 'MR':
        _display = _memory.toString();
        _waitingForOperand = true;
        break;
      case 'M+':
        _memory += currentValue;
        _memoryIndicator = true;
        break;
      case 'M-':
        _memory -= currentValue;
        _memoryIndicator = true;
        break;
    }
  }

  // Scientific functions
  void _onScientificPressed(String function) {
    double value = double.parse(_display);
    double result = 0;
    
    switch (function) {
      case 'π':
        result = 3.14159265359;
        break;
      case 'e':
        result = 2.71828182846;
        break;
      case '√':
        result = value >= 0 ? sqrt(value) : 0;
        break;
      case 'x²':
        result = value * value;
        break;
      case 'sin':
        result = sin(value);
        break;
      case 'cos':
        result = cos(value);
        break;
      case 'tan':
        result = tan(value);
        break;
      case 'log':
        result = value > 0 ? log(value) / ln10 : 0;
        break;
      case 'ln':
        result = value > 0 ? log(value) : 0;
        break;
      case '1/x':
        result = value != 0 ? 1 / value : 0;
        break;
      case 'x!':
        result = _factorial(value.toInt());
        break;
      case '^':
        _operation = '^';
        _firstNumber = value;
        _waitingForOperand = true;
        return;
    }
    
    _display = result % 1 == 0 ? result.toInt().toString() : result.toString();
    _waitingForOperand = true;
  }

  // Parenthesis handling
  void _onParenthesisPressed(String parenthesis) {
    // Simple implementation - could be enhanced for complex expressions
    if (parenthesis == '(') {
      _display = '0';
      _waitingForOperand = true;
    }
  }

  // Helper functions
  double _factorial(int n) {
    if (n < 0) return 0;
    if (n == 0 || n == 1) return 1;
    double result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }
}
