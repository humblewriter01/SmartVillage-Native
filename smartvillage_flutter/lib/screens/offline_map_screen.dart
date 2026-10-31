import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/map_pin.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';

/// Offline Farm & Disease Map.
///
/// Port of `OfflineMapScreen.tsx`. Because there is no tile server in the
/// field, the map is drawn as a coordinate canvas covering Northern Nigeria
/// (lat 7–14, lon 3–14) with pins placed by their latitude/longitude — fully
/// functional with zero network access.
class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final MapService _mapService = MapService();
  final LocationService _location = LocationService();

  List<MapPin> _pins = const <MapPin>[];
  PinType? _filter;
  MapPin? _selected;
  bool _loading = true;

  static const double _minLat = 6.5;
  static const double _maxLat = 14.5;
  static const double _minLon = 2.5;
  static const double _maxLon = 14.5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pins = await _mapService.allPins();
    if (!mounted) return;
    setState(() {
      _pins = pins;
      _loading = false;
    });
  }

  List<MapPin> get _visiblePins => _filter == null
      ? _pins
      : _pins.where((pin) => pin.type == _filter).toList(growable: false);

  Future<void> _addPin(bool hausa) async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    PinType type = PinType.cropDisease;
    PinSeverity severity = PinSeverity.moderate;
    var useGps = true;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppScope.read(context).t('addPin'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: AppScope.read(context).t('pinTitle'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: AppScope.read(context).t('pinNotes'),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: PinType.values.map((value) {
                  final selected = value == type;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(
                      '${value.emoji} ${value.label(hausa)}',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    onSelected: (_) => setSheetState(() => type = value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<PinSeverity>(
                      value: severity,
                      items: PinSeverity.values
                          .map(
                            (value) => DropdownMenuItem<PinSeverity>(
                              value: value,
                              child: Text(
                                value.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => severity = value);
                      },
                      decoration: InputDecoration(
                        labelText: AppScope.read(context).t('pinSeverity'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: useGps,
                      onChanged: (value) => setSheetState(() => useGps = value),
                      title: Text(
                        AppScope.read(context).t('pinGps'),
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(AppScope.read(context).t('savePin')),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true) return;

    var latitude = 12.0022;
    var longitude = 8.5919;
    if (useGps) {
      final fix = await _location.bestEffort();
      if (fix != null) {
        latitude = fix.latitude;
        longitude = fix.longitude;
      }
    }

    await _mapService.addPin(
      MapPin(
        id: 'pin-${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        title: titleController.text.trim().isEmpty
            ? (hausa ? 'Sabuwar Alama' : 'New pin')
            : titleController.text.trim(),
        titleHausa: titleController.text.trim(),
        cropOrAnimal: null,
        diseaseName: null,
        severity: severity,
        latitude: latitude,
        longitude: longitude,
        locationName: useGps
            ? '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}'
            : (hausa ? 'Wuri da aka zaɓa' : 'Selected location'),
        notes: notesController.text.trim(),
        notesHausa: notesController.text.trim(),
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        SectionCard(
          title: hausa ? 'Taswirar Gona da Cututtuka' : 'Farm & Disease Map',
          subtitle: state.t('clickToPinNotice'),
          accent: AppColors.map,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.faint(AppColors.map, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.map_outlined,
                color: AppColors.map, size: 18),
          ),
          child: Column(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1.15,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return Stack(
                              children: <Widget>[
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _MapPainter(
                                      pins: _visiblePins,
                                      selectedId: _selected?.id,
                                    ),
                                  ),
                                ),
                                ..._visiblePins.map((pin) {
                                  final position = _project(
                                    pin.latitude,
                                    pin.longitude,
                                    size,
                                  );
                                  return Positioned(
                                    left: position.dx - 13,
                                    top: position.dy - 13,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _selected = pin),
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: _pinColor(pin.type),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: const <BoxShadow>[
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          pin.type.emoji,
                                          style:
                                              const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ChoiceChip(
                    selected: _filter == null,
                    label: Text(
                      state.t('allPins'),
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  ...PinType.values.map(
                    (type) => ChoiceChip(
                      selected: _filter == type,
                      label: Text(
                        '${type.emoji} ${type.label(hausa)}',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                      onSelected: (_) => setState(() => _filter = type),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _addPin(hausa),
                      icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                      label: Text(state.t('addPin')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.map,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_selected != null) ...<Widget>[
          const SizedBox(height: 12),
          SectionCard(
            title: _selected!.displayTitle(hausa),
            subtitle:
                '${_selected!.type.label(hausa)} · ${_selected!.locationName}',
            accent: AppColors.map,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_selected!.cropOrAnimal != null)
                  InfoRow(
                    label: hausa ? 'Shuka/Dabba' : 'Crop/Animal',
                    value: _selected!.cropOrAnimal!,
                  ),
                if (_selected!.diseaseName != null)
                  InfoRow(
                    label: hausa ? 'Cuta' : 'Pathogen',
                    value: _selected!.diseaseName!,
                  ),
                if (_selected!.severity != null)
                  InfoRow(
                    label: state.t('pinSeverity'),
                    value: _selected!.severity!.name,
                    valueColor: _severityColor(_selected!.severity!),
                  ),
                InfoRow(
                  label: 'GPS',
                  value:
                      '${_selected!.latitude.toStringAsFixed(4)}, ${_selected!.longitude.toStringAsFixed(4)}',
                ),
                const SizedBox(height: 6),
                Text(
                  _selected!.displayNotes(hausa),
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: hausa ? 'Alamomin da ke kusa' : 'Pins in this view',
          subtitle: '${_visiblePins.length} ${hausa ? 'alamomi' : 'pins'}',
          accent: AppColors.map,
          child: Column(
            children: _visiblePins
                .map(
                  (pin) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text(pin.type.emoji,
                        style: const TextStyle(fontSize: 18)),
                    title: Text(
                      pin.displayTitle(hausa),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${pin.locationName} · ${pin.latitude.toStringAsFixed(3)}, ${pin.longitude.toStringAsFixed(3)}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    onTap: () => setState(() => _selected = pin),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Offset _project(double latitude, double longitude, Size size) {
    final x = ((longitude - _minLon) / (_maxLon - _minLon)).clamp(0.02, 0.98) *
        size.width;
    final y = (1 - (latitude - _minLat) / (_maxLat - _minLat)).clamp(0.03, 0.97) *
        size.height;
    return Offset(x, y);
  }

  static Color _pinColor(PinType type) {
    switch (type) {
      case PinType.cropDisease:
        return AppColors.crop;
      case PinType.weatherStation:
        return AppColors.water;
      case PinType.waterPoint:
        return AppColors.info;
      case PinType.livestockAlert:
        return AppColors.livestock;
    }
  }

  static Color _severityColor(PinSeverity severity) {
    switch (severity) {
      case PinSeverity.low:
        return AppColors.success;
      case PinSeverity.moderate:
        return AppColors.warning;
      case PinSeverity.high:
        return AppColors.map;
      case PinSeverity.critical:
        return AppColors.danger;
    }
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.pins, required this.selectedId});

  final List<MapPin> pins;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFF0F9F4);
    canvas.drawRect(Offset.zero & size, background);

    // Grid lines (every 2 degrees of lat/long).
    final grid = Paint()
      ..color = const Color(0xFFD6EAD9)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Stylised Niger / Benue river curves so the canvas reads as a map.
    final river = Paint()
      ..color = const Color(0xFFBEE3F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final riverPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.15)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.35,
        size.width * 0.3,
        size.height * 0.6,
        size.width * 0.62,
        size.height * 0.78,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.88,
        size.width * 0.85,
        size.height * 0.95,
        size.width * 0.95,
        size.height * 0.98,
      );
    canvas.drawPath(riverPath, river);

    // Compass.
    final compass = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2;
    final center = Offset(size.width - 22, 22);
    canvas.drawLine(center.translate(0, -9), center.translate(0, 9), compass);
    canvas.drawLine(center, center.translate(-6, -5), compass);
    canvas.drawLine(center, center.translate(6, -5), compass);

    // Pin halos for the selected pin.
    if (selectedId != null) {
      for (final pin in pins) {
        if (pin.id != selectedId) continue;
        final x = ((pin.longitude - MapProjection.minLon) /
                    (MapProjection.maxLon -
                        MapProjection.minLon))
                .clamp(0.02, 0.98) *
            size.width;
        final y = (1 -
                    (pin.latitude - MapProjection.minLat) /
                        (MapProjection.maxLat -
                            MapProjection.minLat))
                .clamp(0.03, 0.97) *
            size.height;
        canvas.drawCircle(
          Offset(x, y),
          18,
          Paint()..color = const Color(0x331F7A4C),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.pins.length != pins.length ||
      oldDelegate.selectedId != selectedId;
}

/// Shared bounds for the map projection.
class MapProjection {
  const MapProjection._();

  static const double minLat = 6.5;
  static const double maxLat = 14.5;
  static const double minLon = 2.5;
  static const double maxLon = 14.5;

  static Offset project(double latitude, double longitude, Size size) {
    final x = ((longitude - minLon) / (maxLon - minLon)).clamp(0.02, 0.98) *
        size.width;
    final y = (1 - (latitude - minLat) / (maxLat - minLat)).clamp(0.03, 0.97) *
        size.height;
    return Offset(x, y);
  }

  /// Great-circle distance in km (used by the "nearest pin" hint).
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    double radians(double degrees) => degrees * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
