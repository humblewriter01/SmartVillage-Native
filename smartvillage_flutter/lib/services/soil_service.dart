import '../data/soil_data.dart';
import '../models/soil.dart';

/// Soil pH / moisture evaluation ported from `soilService.evaluateSoilConditions`.
///
/// Scoring: pH contributes 60%, moisture 40%. Advice strings are generated in
/// both languages with the crop name interpolated, exactly like the web app.
class SoilService {
  const SoilService._();

  static List<CropSoilRequirement> get requirements => cropSoilRequirements;

  static CropSoilRequirement _requirementFor(String cropId) =>
      soilRequirementById(cropId) ??
      soilRequirementById('soybeans') ??
      cropSoilRequirements.first;

  static SoilConditionAdvice evaluate({
    required String cropId,
    required double ph,
    required double moisture,
  }) {
    final req = _requirementFor(cropId);
    final phLabel = ph.toStringAsFixed(1);
    final moistureLabel = moisture.toStringAsFixed(0);

    // ---- pH ---------------------------------------------------------------
    var phStatus = 'optimal';
    var phTextEn = 'Optimal pH';
    var phTextHa = 'Daidaitaccen Tsami';
    var phAdviceEn = '';
    var phAdviceHa = '';
    var phScore = 100;

    if (ph < 5.5) {
      phStatus = 'strongly_acidic';
      phTextEn = 'Strongly Acidic (Severe)';
      phTextHa = 'Tsami Mai Tsanani';
      phScore = 40;
      phAdviceEn =
          'Critical acidity! At pH $phLabel, vital nutrients (phosphorus, calcium, magnesium) are chemically locked out. For ${req.name}, apply agricultural lime (calcium carbonate) at 400-500 kg/ha or broadcast sifted dry wood ash (toka) at 600 kg/ha onto beds. Work in well-rotted cow/goat manure (takin gargajiya) to buffer the soil. Avoid Ammonium Sulfate fertilizer.';
      phAdviceHa =
          'Ƙasar tana da tsami mai tsanani (pH $phLabel)! Wannan na hana ${req.hausaName} shan takin phosphorus da calcium. Shawara: Zuba farar ƙasa (agricultural lime) ko tokar itace (toka) kilo 500 a kan gona kafin shuka. Sanya takin gargajiya na dabbobi don gyara ƙasa. Kada a yi amfani da takin Ammonium Sulfate.';
    } else if (ph < req.optimalPhMin) {
      phStatus = 'slightly_acidic';
      phTextEn = 'Slightly Acidic';
      phTextHa = 'Ɗan Tsami';
      phScore = 70;
      phAdviceEn =
          'Slightly below optimal pH ($phLabel vs target ${_fmt(req.optimalPhMin)}-${_fmt(req.optimalPhMax)}). For ${req.name}, broadcast 2-3 bags of dry cooking wood ash (toka) or 150 kg of dolomite lime per hectare, and incorporate farmyard compost during ridge preparation.';
      phAdviceHa =
          'Ƙasar tana da ɗan tsami ($phLabel maimakon ${_fmt(req.optimalPhMin)}-${_fmt(req.optimalPhMax)}). Domin ${req.hausaName}, zuba buhu 2-3 na tokar itace (toka) ko takin dolomite a gona, sannan a sa takin gargajiya yayin shuka kunya.';
    } else if (ph > req.optimalPhMax + 0.7) {
      phStatus = 'strongly_alkaline';
      phTextEn = 'Strongly Alkaline (High Salinity)';
      phTextHa = 'Gishiri/Alkaline Mai Yawa';
      phScore = 45;
      phAdviceEn =
          'Soil is excessively alkaline (pH $phLabel). Micronutrients like iron, zinc, and manganese are precipitated out. For ${req.name}, incorporate generous amounts of well-composted organic matter, cattle manure, or elemental sulfur (50-100 kg/ha). Mulch heavily with neem leaves to slowly lower pH.';
      phAdviceHa =
          'Ƙasar tana da gishirin alkaline mai yawa (pH $phLabel). Wannan na hana ${req.hausaName} shan sinadarin iron da zinc. Shawara: Zuba takin kaji ko shanu mai yawa, ko takin sulfur. Sanya ciyawa ko ganyen dogon-yaro a matsayin shinfiɗa (mulch) domin rage alkalinity a hankali.';
    } else if (ph > req.optimalPhMax) {
      phStatus = 'alkaline';
      phTextEn = 'Moderately Alkaline';
      phTextHa = 'Ɗan Gishirin Alkaline';
      phScore = 75;
      phAdviceEn =
          'Slightly alkaline for ${req.name} (pH $phLabel vs target ${_fmt(req.optimalPhMin)}-${_fmt(req.optimalPhMax)}). Top-dress with composted organic manure and avoid hard water with high calcium bicarbonate when irrigating.';
      phAdviceHa =
          'Ƙasar tana da ɗan gishirin alkaline ga ${req.hausaName} ($phLabel). Zuba takin gargajiya mai kyau a gona kuma a kiyaye yin ban ruwa da ruwa mai tsananin gishiri.';
    } else {
      phStatus = 'optimal';
      phTextEn =
          'Optimal for ${req.name} (${_fmt(req.optimalPhMin)} - ${_fmt(req.optimalPhMax)})';
      phTextHa = 'Daidaitaccen Yanayi ga ${req.hausaName}';
      phScore = 100;
      phAdviceEn =
          'Soil pH $phLabel is in the prime sweet spot for ${req.name}! Root absorption of N-P-K and microbial activity are performing at peak potential. Maintain current organic soil management practices.';
      phAdviceHa =
          "Ma'aunin pH $phLabel ya cika daidai ga ${req.hausaName}! Saiwar shuka na shan dukkan takin NPK da sauran sinadarai yadda ya kamata. Ci gaba da kula da gonar da takin gargajiya.";
    }

    // ---- Moisture ---------------------------------------------------------
    var moistureStatus = 'optimal';
    var moistureTextEn = 'Optimal Moisture';
    var moistureTextHa = 'Daidaitacciyar Laima';
    var moistureAdviceEn = '';
    var moistureAdviceHa = '';
    var moistureScore = 100;

    if (moisture < 35) {
      moistureStatus = 'critically_dry';
      moistureTextEn = 'Critically Dry (Drought Stress)';
      moistureTextHa = 'Bushewa Mai Tsanani';
      moistureScore = 40;
      moistureAdviceEn =
          'Soil moisture is low ($moistureLabel%). Plants are facing drought stress. Irrigate immediately in early morning or late evening. Apply a 5-8 cm mulch blanket using rice straw, groundnut haulms, or dried sorghum stalks to prevent rapid evaporation under hot Harmattan winds.';
      moistureAdviceHa =
          'Laimar ƙasa ta yi ƙasa sosai ($moistureLabel%). Shuka na fuskantar bushewa da fari. Shayar da gona da gaggawa da sassafe ko da yamma. Shimfiɗa ciyawa, karan dawa, ko danyar shinkafa (mulch) santimita 5-8 don hana iskar rani busar da ƙasa.';
    } else if (moisture < req.optimalMoistureMin) {
      moistureStatus = 'moderate';
      moistureTextEn = 'Low to Moderate Moisture';
      moistureTextHa = 'Matsakaiciyar Laima';
      moistureScore = 75;
      moistureAdviceEn =
          'Moisture level ($moistureLabel%) is slightly below optimal range (${_fmt(req.optimalMoistureMin)}%-${_fmt(req.optimalMoistureMax)}%). Schedule a light furrow irrigation within the next 48 hours to prevent moisture stress during critical growth stages.';
      moistureAdviceHa =
          'Laimar ƙasa ($moistureLabel%) ta ɗan yi ƙasa da buƙata (${_fmt(req.optimalMoistureMin)}%-${_fmt(req.optimalMoistureMax)}%). Yi shirin shayarwa a cikin sa'o\'i 48 masu zuwa don shuka ba ta dakata da girma ba.';
    } else if (cropId != 'rice' && moisture > 80) {
      moistureStatus = 'waterlogged';
      moistureTextEn = 'Waterlogged / Flooded Soil';
      moistureTextHa = 'Ruwa Ya Yi Yawa / Ambaliya';
      moistureScore = 45;
      moistureAdviceEn =
          'Soil is oversaturated ($moistureLabel%). Danger of root suffocation, Pythium damping-off, and Fusarium crown rot for ${req.name}. Deepen drain channels between ridges to let excess water escape immediately. Withhold irrigation until topsoil dries to touch.';
      moistureAdviceHa =
          'Ruwa ya cika a gonar ${req.hausaName} ($moistureLabel%). Wannan na iya sa saiwa ta rube sakamakon cutar ruwa. Bude magudanar ruwa a tsakanin kunyoyi don ruwa ya gudu. Dakatar da ban ruwa har sai ƙasar ta sha iska.';
    } else {
      moistureStatus = 'optimal';
      moistureTextEn =
          'Optimal Moisture (${_fmt(req.optimalMoistureMin)}% - ${_fmt(req.optimalMoistureMax)}%)';
      moistureTextHa = 'Laima Mai Kyau ga ${req.hausaName}';
      moistureScore = 100;
      moistureAdviceEn =
          'Soil moisture ($moistureLabel%) is ideal! Provides excellent root aeration and nutrient dissolution for ${req.name}. Continue your current irrigation interval.';
      moistureAdviceHa =
          'Laimar ƙasa ($moistureLabel%) tana da kyau sosai! Tana ba saiwar ${req.hausaName} damar numfashi da shan sinadarai ba tare da matsi ba. Ci gaba da wannan tsari na ban ruwa.';
    }

    final overallScore = (phScore * 0.6 + moistureScore * 0.4).round();
    var overallRating = 'good';
    if (overallScore >= 90) {
      overallRating = 'excellent';
    } else if (overallScore >= 70) {
      overallRating = 'good';
    } else if (overallScore >= 50) {
      overallRating = 'fair';
    } else {
      overallRating = 'poor';
    }

    return SoilConditionAdvice(
      phStatus: phStatus,
      phScoreTextEn: phTextEn,
      phScoreTextHa: phTextHa,
      phAdviceEn: phAdviceEn,
      phAdviceHa: phAdviceHa,
      moistureStatus: moistureStatus,
      moistureTextEn: moistureTextEn,
      moistureTextHa: moistureTextHa,
      moistureAdviceEn: moistureAdviceEn,
      moistureAdviceHa: moistureAdviceHa,
      overallRating: overallRating,
      overallScore: overallScore,
    );
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  static String soilTypeLabel(String soilType, bool hausa) {
    switch (soilType) {
      case 'sandy_loam':
        return hausa ? 'Yashi mai laima' : 'Sandy loam';
      case 'loamy':
        return hausa ? 'Ƙasa mai kyau (Loam)' : 'Loamy';
      case 'clay':
        return hausa ? 'Ƙasa mai laka (Clay)' : 'Clay';
      case 'sandy':
        return hausa ? 'Yashi' : 'Sandy';
      default:
        return soilType;
    }
  }

  static String overallLabel(String rating, bool hausa) {
    switch (rating) {
      case 'excellent':
        return hausa ? 'Kyakkyawa Ƙwarai' : 'Excellent';
      case 'good':
        return hausa ? 'Mai Kyau' : 'Good';
      case 'fair':
        return hausa ? 'Matsakaici' : 'Fair';
      default:
        return hausa ? 'Rashin Kyau' : 'Poor';
    }
  }
}
