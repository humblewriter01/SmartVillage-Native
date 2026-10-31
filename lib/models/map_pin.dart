/// Offline map-pin models.
///
/// Mirrors `src/services/mapService.ts` (`MapPin`).
library;

enum PinType { cropDisease, weatherStation, waterPoint, livestockAlert }

enum PinSeverity { low, moderate, high, critical }

class MapPin {
  const MapPin({
    required this.id,
    required this.type,
    required this.title,
    required this.titleHausa,
    required this.cropOrAnimal,
    required this.diseaseName,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.notes,
    required this.notesHausa,
    required this.createdAt,
    this.temperature,
    this.rainfall,
    this.humidity,
  });

  final String id;
  final PinType type;
  final String title;
  final String titleHausa;
  final String? cropOrAnimal;
  final String? diseaseName;
  final PinSeverity? severity;
  final double latitude;
  final double longitude;
  final String locationName;
  final String notes;
  final String? notesHausa;
  final String createdAt;

  /// Optional weather-station readings.
  final double? temperature;
  final double? rainfall;
  final double? humidity;

  String displayTitle(bool hausa) =>
      hausa && titleHausa.isNotEmpty ? titleHausa : title;

  String displayNotes(bool hausa) =>
      hausa && (notesHausa?.isNotEmpty ?? false) ? notesHausa! : notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'title': title,
        'title_hausa': titleHausa,
        'cropOrAnimal': cropOrAnimal,
        'diseaseName': diseaseName,
        'severity': severity?.name,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'notes': notes,
        'notes_hausa': notesHausa,
        'createdAt': createdAt,
        'temperature': temperature,
        'rainfall': rainfall,
        'humidity': humidity,
      };

  static MapPin fromJson(Map<String, dynamic> json) => MapPin(
        id: json['id'] as String? ?? '',
        type: _typeFromName(json['type'] as String?),
        title: json['title'] as String? ?? '',
        titleHausa: json['title_hausa'] as String? ?? '',
        cropOrAnimal: json['cropOrAnimal'] as String?,
        diseaseName: json['diseaseName'] as String?,
        severity: _severityFromName(json['severity'] as String?),
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        locationName: json['locationName'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        notesHausa: json['notes_hausa'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
        temperature: (json['temperature'] as num?)?.toDouble(),
        rainfall: (json['rainfall'] as num?)?.toDouble(),
        humidity: (json['humidity'] as num?)?.toDouble(),
      );

  static PinType _typeFromName(String? name) {
    switch (name) {
      case 'weather_station':
        return PinType.weatherStation;
      case 'water_point':
        return PinType.waterPoint;
      case 'livestock_alert':
        return PinType.livestockAlert;
      case 'crop_disease':
      default:
        return PinType.cropDisease;
    }
  }

  static PinSeverity? _severityFromName(String? name) {
    switch (name) {
      case 'low':
        return PinSeverity.low;
      case 'moderate':
        return PinSeverity.moderate;
      case 'high':
        return PinSeverity.high;
      case 'critical':
        return PinSeverity.critical;
      default:
        return null;
    }
  }
}

extension PinTypeLabels on PinType {
  String label(bool hausa) {
    switch (this) {
      case PinType.cropDisease:
        return hausa ? 'Cututtukan Shuka' : 'Crop Outbreaks';
      case PinType.weatherStation:
        return hausa ? 'Tashoshin Yanayi' : 'Weather Stations';
      case PinType.waterPoint:
        return hausa ? 'Wuraren Ruwa' : 'Water Points';
      case PinType.livestockAlert:
        return hausa ? 'Lafiyar Dabbobi' : 'Livestock Alerts';
    }
  }

  String get emoji {
    switch (this) {
      case PinType.cropDisease:
        return '🌾';
      case PinType.weatherStation:
        return '⛅';
      case PinType.waterPoint:
        return '💧';
      case PinType.livestockAlert:
        return '🐄';
    }
  }
}
