/// Weather models (mirrors `src/services/weatherService.ts`).
library;

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.max,
    required this.min,
    required this.rain,
  });

  final String date;
  final double max;
  final double min;
  final double rain;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'max': max,
        'min': min,
        'rain': rain,
      };

  static WeatherDay fromJson(Map<String, dynamic> json) => WeatherDay(
        date: json['date'] as String? ?? '',
        max: (json['max'] as num?)?.toDouble() ?? 0,
        min: (json['min'] as num?)?.toDouble() ?? 0,
        rain: (json['rain'] as num?)?.toDouble() ?? 0,
      );
}

class NigerianLocation {
  const NigerianLocation({
    required this.name,
    required this.state,
    required this.lat,
    required this.lon,
  });

  final String name;
  final String state;
  final double lat;
  final double lon;
}
