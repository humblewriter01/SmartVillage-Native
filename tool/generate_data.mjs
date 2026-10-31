// Code-generates the Dart datasets in lib/data/ from the JSON snapshot of the
// original React/TypeScript datasets kept in tool/source_data/.
// Usage:  node tool/generate_data.mjs   (run from the smartvillage_flutter root)
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Paths are resolved relative to this script so the generator works from any
// clone of the repository:  dart tool/generate_data.mjs
const HERE = path.dirname(fileURLToPath(import.meta.url));
const JSON_DIR = path.join(HERE, 'source_data');
const OUT_DIR = path.join(HERE, '..', 'lib', 'data');

mkdirSync(OUT_DIR, { recursive: true });

const read = (name) => JSON.parse(readFileSync(path.join(JSON_DIR, `${name}.json`), 'utf8'));

// ---------------------------------------------------------------- helpers
const esc = (s) =>
  String(s)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')
    .replace(/\r/g, '')
    .replace(/\n/g, '\\n');

const str = (s) => (s === undefined || s === null ? 'null' : `'${esc(s)}'`);

const strList = (arr) =>
  arr && arr.length
    ? `<String>[${arr.map((s) => str(s)).join(', ')}]`
    : '<String>[]';

const num = (v) => {
  if (v === undefined || v === null) return '0';
  return Number.isInteger(v) ? String(v) : String(v);
};

const header = (imports, note) =>
  `// GENERATED FILE — do not edit by hand.\n` +
  `// Source: ${note}\n` +
  `// Regenerate with: node tool/generate_data.mjs (see README).\n` +
  (imports.length ? imports.map((i) => `import '${i}';`).join('\n') + '\n' : '') +
  '\n';

// Parse the reference dataset's offline SVG illustrations back into ARGB
// colours so the Flutter vector leaf painter can reproduce the same look.
function colorsFromSvg(svgDataUri) {
  const fallback = { leaf: 0xff2e7d32, spot: 0xffb71c1c };
  if (!svgDataUri || typeof svgDataUri !== 'string') return fallback;
  let svg = svgDataUri;
  const comma = svg.indexOf(',');
  if (comma >= 0) svg = decodeURIComponent(svg.slice(comma + 1));
  const fills = [...svg.matchAll(/fill="#([0-9a-fA-F]{6})"/g)].map((m) => m[1]);
  const leaf = fills[1] ? 0xff000000 + parseInt(fills[1], 16) : fallback.leaf;
  const spot = fills[2] ? 0xff000000 + parseInt(fills[2], 16) : fallback.spot;
  return { leaf, spot };
}

const argb = (n) => '0x' + (n >>> 0).toString(16).padStart(8, '0');

// ---------------------------------------------------------------- crops
const crops = read('cropReferenceData');
let out = header(
  ['../models/crop.dart'],
  'src/data/cropReferenceData.ts (CROP_REFERENCE_DATA)',
);
out += `/// All ${crops.length} crops and their disease libraries from the React blueprint.\n`;
out += `///\n/// 13 crops documented: ${crops.map((c) => c.crop).join(', ')}.\n`;
out += 'const List<Crop> cropReferenceData = <Crop>[\n';
for (const crop of crops) {
  const c = colorsFromSvg(crop.healthy_image);
  out += `  Crop(\n`;
  out += `    id: ${str(crop.id)},\n`;
  out += `    crop: ${str(crop.crop)},\n`;
  out += `    hausaName: ${str(crop.hausa_name)},\n`;
  out += `    emoji: ${str(crop.emoji || '🌱')},\n`;
  out += `    description: ${str(crop.description)},\n`;
  out += `    descriptionHausa: ${str(crop.description_hausa)},\n`;
  out += `    leafColor: ${argb(c.leaf)},\n`;
  out += `    diseases: <Disease>[\n`;
  for (const d of crop.diseases) {
    const dc = colorsFromSvg(d.image);
    out += `      Disease(\n`;
    out += `        id: ${str(d.id)},\n`;
    out += `        name: ${str(d.name)},\n`;
    out += `        hausaName: ${str(d.hausa_name)},\n`;
    out += `        affectedParts: ${strList(d.affected_parts)},\n`;
    out += `        causes: ${str(d.causes)},\n`;
    out += `        causesHausa: ${str(d.causes_hausa)},\n`;
    out += `        symptoms: ${str(d.symptoms)},\n`;
    out += `        symptomsHausa: ${str(d.symptoms_hausa)},\n`;
    out += `        treatment: ${str(d.treatment)},\n`;
    out += `        treatmentHausa: ${str(d.treatment_hausa)},\n`;
    out += `        prevention: ${str(d.prevention)},\n`;
    out += `        preventionHausa: ${str(d.prevention_hausa)},\n`;
    out += `        leafColor: ${argb(dc.leaf)},\n`;
    out += `        spotColor: ${argb(dc.spot)},\n`;
    out += `      ),\n`;
  }
  out += `    ],\n`;
  out += `  ),\n`;
}
out += '];\n\n';
out += `Crop? cropById(String id) {
  for (final crop in cropReferenceData) {
    if (crop.id == id) return crop;
  }
  return null;
}

Disease? diseaseById(String id) {
  for (final crop in cropReferenceData) {
    for (final disease in crop.diseases) {
      if (disease.id == id) return disease;
    }
  }
  return null;
}

Crop? cropForDisease(String diseaseId) {
  for (final crop in cropReferenceData) {
    for (final disease in crop.diseases) {
      if (disease.id == diseaseId) return crop;
    }
  }
  return null;
}
`;
writeFileSync(path.join(OUT_DIR, 'crop_data.dart'), out, 'utf8');

// ---------------------------------------------------------------- livestock
const animals = read('livestockAnimals');
const livestockDiseases = read('livestockDiseases');
out = header(
  ['../models/livestock.dart'],
  'src/services/livestockService.ts (LIVESTOCK_ANIMALS, LIVESTOCK_DISEASES)',
);
out += `/// ${animals.length} animals / birds and ${livestockDiseases.length} weighted diseases.\n`;
out += 'const List<Animal> livestockAnimals = <Animal>[\n';
for (const a of animals) {
  out += `  Animal(\n`;
  out += `    id: ${str(a.id)},\n`;
  out += `    name: ${str(a.name)},\n`;
  out += `    hausaName: ${str(a.hausa_name)},\n`;
  out += `    emoji: ${str(a.emoji)},\n`;
  out += `    commonSymptoms: ${strList(a.commonSymptoms)},\n`;
  out += `    commonSymptomsHausa: ${strList(a.commonSymptomsHausa)},\n`;
  out += `  ),\n`;
}
out += '];\n\n';
out += `const List<AnimalDisease> livestockDiseases = <AnimalDisease>[\n`;
for (const d of livestockDiseases) {
  out += `  AnimalDisease(\n`;
  out += `    id: ${str(d.id)},\n`;
  out += `    animalId: ${str(d.animalId)},\n`;
  out += `    name: ${str(d.name)},\n`;
  out += `    hausaName: ${str(d.hausa_name)},\n`;
  out += `    keySymptoms: ${strList(d.keySymptoms)},\n`;
  out += `    weightedSymptoms: <SymptomWeight>[\n`;
  for (const w of d.weightedSymptoms) {
    out += `      SymptomWeight(symptom: ${str(w.symptom)}, weight: ${num(w.weight)}),\n`;
  }
  out += `    ],\n`;
  out += `    causes: ${str(d.causes)},\n`;
  out += `    causesHausa: ${str(d.causes_hausa)},\n`;
  out += `    treatment: ${str(d.treatment)},\n`;
  out += `    treatmentHausa: ${str(d.treatment_hausa)},\n`;
  out += `    prevention: ${str(d.prevention)},\n`;
  out += `    preventionHausa: ${str(d.prevention_hausa)},\n`;
  out += `    isUrgentContagious: ${d.isUrgentContagious ? 'true' : 'false'},\n`;
  out += `  ),\n`;
}
out += '];\n\n';
out += `Animal? animalById(String id) {
  for (final animal in livestockAnimals) {
    if (animal.id == id) return animal;
  }
  return null;
}

List<AnimalDisease> diseasesForAnimal(String animalId) =>
    livestockDiseases.where((d) => d.animalId == animalId).toList();
`;
writeFileSync(path.join(OUT_DIR, 'livestock_data.dart'), out, 'utf8');

// ---------------------------------------------------------------- health
const conditions = read('healthConditions');
const catMap = {
  infectious: 'HealthCategory.infectious',
  respiratory: 'HealthCategory.respiratory',
  emergency: 'HealthCategory.emergency',
  environmental: 'HealthCategory.environmental',
  skin: 'HealthCategory.skin',
};
const urgMap = {
  critical: 'Urgency.critical',
  high: 'Urgency.high',
  moderate: 'Urgency.moderate',
  mild: 'Urgency.mild',
};
out = header(
  ['../models/health_condition.dart'],
  'src/services/healthService.ts (MANUAL_HEALTH_CONDITIONS)',
);
out += `/// ${conditions.length} human health conditions with full English/Hausa triage text.\n`;
out += 'const List<ManualHealthCondition> manualHealthConditions =\n    <ManualHealthCondition>[\n';
for (const c of conditions) {
  out += `  ManualHealthCondition(\n`;
  out += `    id: ${str(c.id)},\n`;
  out += `    condition: ${str(c.condition)},\n`;
  out += `    conditionHausa: ${str(c.conditionHausa)},\n`;
  out += `    category: ${catMap[c.category] ?? 'HealthCategory.infectious'},\n`;
  out += `    urgency: ${urgMap[c.urgency] ?? 'Urgency.moderate'},\n`;
  out += `    urgencyLabel: ${str(c.urgencyLabel)},\n`;
  out += `    urgencyLabelHausa: ${str(c.urgencyLabelHausa)},\n`;
  out += `    symptoms: ${str(c.symptoms)},\n`;
  out += `    symptomsHausa: ${str(c.symptomsHausa)},\n`;
  out += `    firstAid: ${str(c.firstAid)},\n`;
  out += `    firstAidHausa: ${str(c.firstAidHausa)},\n`;
  out += `    clinicalAdvice: ${str(c.clinicalAdvice)},\n`;
  out += `    clinicalAdviceHausa: ${str(c.clinicalAdviceHausa)},\n`;
  out += `    dangerSigns: ${str(c.dangerSigns)},\n`;
  out += `    dangerSignsHausa: ${str(c.dangerSignsHausa)},\n`;
  out += `  ),\n`;
}
out += '];\n\n';
out += `ManualHealthCondition? healthConditionById(String id) {
  for (final condition in manualHealthConditions) {
    if (condition.id == id) return condition;
  }
  return null;
}
`;
writeFileSync(path.join(OUT_DIR, 'health_data.dart'), out, 'utf8');

// ---------------------------------------------------------------- calendar
const calendar = read('cropCalendar');
const seasonMap = {
  rainfed: 'SeasonType.rainfed',
  irrigated_dry: 'SeasonType.irrigatedDry',
  both: 'SeasonType.both',
};
out = header(
  ['../models/planting_calendar.dart'],
  'src/services/plantingCalendarService.ts (CROP_CALENDAR)',
);
out += `/// ${calendar.length} crops with Northern-Nigeria planting & harvest windows.\n`;
out += 'const List<CropCalendarSchedule> cropCalendar = <CropCalendarSchedule>[\n';
for (const c of calendar) {
  out += `  CropCalendarSchedule(\n`;
  out += `    id: ${str(c.id)},\n`;
  out += `    name: ${str(c.name)},\n`;
  out += `    hausaName: ${str(c.hausa_name)},\n`;
  out += `    seasonType: ${seasonMap[c.seasonType] ?? 'SeasonType.both'},\n`;
  out += `    plantingStartMonth: ${num(c.plantingStartMonth)},\n`;
  out += `    plantingStartDay: ${num(c.plantingStartDay)},\n`;
  out += `    plantingEndMonth: ${num(c.plantingEndMonth)},\n`;
  out += `    plantingEndDay: ${num(c.plantingEndDay)},\n`;
  out += `    harvestStartMonth: ${num(c.harvestStartMonth)},\n`;
  out += `    harvestEndMonth: ${num(c.harvestEndMonth)},\n`;
  out += `    plantingWindows: <PlantingWindow>[\n`;
  for (const w of c.plantingWindows || []) {
    out += `      PlantingWindow(seasonLabelEn: ${str(w.seasonLabelEn)}, seasonLabelHa: ${str(w.seasonLabelHa)}, startMonth: ${num(w.startMonth)}, startDay: ${num(w.startDay)}, endMonth: ${num(w.endMonth)}, endDay: ${num(w.endDay)}),\n`;
  }
  out += `    ],\n`;
  out += `    harvestWindows: <HarvestWindow>[\n`;
  for (const w of c.harvestWindows || []) {
    out += `      HarvestWindow(seasonLabelEn: ${str(w.seasonLabelEn)}, seasonLabelHa: ${str(w.seasonLabelHa)}, startMonth: ${num(w.startMonth)}, endMonth: ${num(w.endMonth)}),\n`;
  }
  out += `    ],\n`;
  out += `    carePeriodWeeks: ${num(c.carePeriodWeeks)},\n`;
  out += `    idealRainfall: ${str(c.idealRainfall)},\n`;
  out += `    idealTemp: ${str(c.idealTemp)},\n`;
  out += `    advice: ${str(c.advice)},\n`;
  out += `    adviceHausa: ${str(c.advice_hausa)},\n`;
  out += `    babyPlantCare: ${str(c.babyPlantCare)},\n`;
  out += `    babyPlantCareHausa: ${str(c.babyPlantCare_hausa)},\n`;
  out += `  ),\n`;
}
out += '];\n\n';
out += `CropCalendarSchedule? calendarCropById(String id) {
  for (final crop in cropCalendar) {
    if (crop.id == id) return crop;
  }
  return null;
}
`;
writeFileSync(path.join(OUT_DIR, 'calendar_data.dart'), out, 'utf8');

// ---------------------------------------------------------------- knowledge
const items = read('knowledgeItems');
const details = read('diseaseDetails');
const labels = read('cropLabels');
const kCatMap = {
  crop: 'KnowledgeCategory.crop',
  health: 'KnowledgeCategory.health',
  farm: 'KnowledgeCategory.farm',
  water: 'KnowledgeCategory.water',
  poultry: 'KnowledgeCategory.poultry',
};
out = header(
  ['../models/knowledge.dart'],
  'src/data/knowledgeData.ts (KNOWLEDGE_ITEMS, DISEASE_DETAILS, CROP_LABELS)',
);
out += `/// ${items.length} bilingual knowledge articles.\n`;
out += 'const List<KnowledgeItem> knowledgeItems = <KnowledgeItem>[\n';
for (const k of items) {
  out += `  KnowledgeItem(\n`;
  out += `    id: ${str(k.id)},\n`;
  out += `    category: ${kCatMap[k.category] ?? 'KnowledgeCategory.farm'},\n`;
  out += `    title: ${str(k.title)},\n`;
  out += `    titleEn: ${str(k.title_en || k.title)},\n`;
  out += `    titleHa: ${str(k.title_ha || k.hausa || k.title)},\n`;
  out += `    body: ${str(k.body)},\n`;
  out += `    bodyHa: ${str(k.body_ha || k.description_ha || k.body)},\n`;
  out += `    source: ${str(k.source)},\n`;
  out += `  ),\n`;
}
out += '];\n\n';
out += `/// Detailed disease monographs keyed by disease id.\n`;
out += 'const Map<String, DiseaseInfo> diseaseDetails = <String, DiseaseInfo>{\n';
for (const [key, d] of Object.entries(details)) {
  out += `  ${str(key)}: DiseaseInfo(\n`;
  out += `    diseaseId: ${str(d.disease_id)},\n`;
  out += `    commonName: ${str(d.common_name)},\n`;
  out += `    hausaName: ${str(d.hausa_name || '')},\n`;
  out += `    pathogenType: ${str(d.pathogen_type)},\n`;
  out += `    affectedCrops: ${strList(d.affected_crops)},\n`;
  out += `    causes: ${str(d.causes)},\n`;
  out += `    symptoms: ${str(d.symptoms)},\n`;
  out += `    treatments: TreatmentLevels(mild: ${str(d.treatments.mild)}, moderate: ${str(d.treatments.moderate)}, severe: ${str(d.treatments.severe)}),\n`;
  out += `    organicAlternative: ${str(d.organic_alternative)},\n`;
  out += `    preventionTips: ${strList(d.prevention_tips)},\n`;
  out += `  ),\n`;
}
out += '};\n\n';
out += `/// Labels produced by the bundled crop classifier (${labels.length} classes).\n`;
out += `const List<String> cropLabels = <String>[\n`;
for (const l of labels) out += `  ${str(l)},\n`;
out += '];\n';
writeFileSync(path.join(OUT_DIR, 'knowledge_data.dart'), out, 'utf8');

// ---------------------------------------------------------------- soil
const soil = read('cropSoilRequirements');
out = header(
  ['../models/soil.dart'],
  'src/services/soilService.ts (CROP_SOIL_REQUIREMENTS)',
);
out += `/// ${soil.length} crop-specific soil pH / moisture envelopes.\n`;
out += 'const List<CropSoilRequirement> cropSoilRequirements =\n    <CropSoilRequirement>[\n';
for (const s of soil) {
  out += `  CropSoilRequirement(\n`;
  out += `    cropId: ${str(s.cropId)},\n`;
  out += `    name: ${str(s.name)},\n`;
  out += `    hausaName: ${str(s.hausaName)},\n`;
  out += `    emoji: ${str(s.emoji)},\n`;
  out += `    minPh: ${num(s.minPh)},\n`;
  out += `    optimalPhMin: ${num(s.optimalPhMin)},\n`;
  out += `    optimalPhMax: ${num(s.optimalPhMax)},\n`;
  out += `    maxPh: ${num(s.maxPh)},\n`;
  out += `    optimalMoistureMin: ${num(s.optimalMoistureMin)},\n`;
  out += `    optimalMoistureMax: ${num(s.optimalMoistureMax)},\n`;
  out += `    criticalNotesEn: ${str(s.criticalNotesEn)},\n`;
  out += `    criticalNotesHa: ${str(s.criticalNotesHa)},\n`;
  out += `  ),\n`;
}
out += '];\n\n';
out += `CropSoilRequirement? soilRequirementById(String cropId) {
  for (final req in cropSoilRequirements) {
    if (req.cropId == cropId) return req;
  }
  return null;
}
`;
writeFileSync(path.join(OUT_DIR, 'soil_data.dart'), out, 'utf8');

// ---------------------------------------------------------------- map pins
const pins = read('initialPins');
const pinTypeMap = {
  crop_disease: 'PinType.cropDisease',
  weather_station: 'PinType.weatherStation',
  water_point: 'PinType.waterPoint',
  livestock_alert: 'PinType.livestockAlert',
};
const sevMap = {
  low: 'PinSeverity.low',
  moderate: 'PinSeverity.moderate',
  high: 'PinSeverity.high',
  critical: 'PinSeverity.critical',
};
out = header(['../models/map_pin.dart'], 'src/services/mapService.ts (INITIAL_COMMUNITY_PINS)');
out += `/// Seed pins shown before the farmer adds their own observations.\n`;
out += 'const List<MapPin> initialCommunityPins = <MapPin>[\n';
for (const p of pins) {
  out += `  MapPin(\n`;
  out += `    id: ${str(p.id)},\n`;
  out += `    type: ${pinTypeMap[p.type] ?? 'PinType.cropDisease'},\n`;
  out += `    title: ${str(p.title)},\n`;
  out += `    titleHausa: ${str(p.title_hausa)},\n`;
  out += `    cropOrAnimal: ${str(p.cropOrAnimal ?? null)},\n`;
  out += `    diseaseName: ${str(p.diseaseName ?? null)},\n`;
  out += `    severity: ${p.severity ? sevMap[p.severity] : 'null'},\n`;
  out += `    latitude: ${num(p.latitude)},\n`;
  out += `    longitude: ${num(p.longitude)},\n`;
  out += `    locationName: ${str(p.locationName)},\n`;
  out += `    notes: ${str(p.notes)},\n`;
  out += `    notesHausa: ${str(p.notes_hausa ?? null)},\n`;
  out += `    createdAt: ${str(p.createdAt)},\n`;
  if (p.weatherDetails) {
    out += `    temperature: ${num(p.weatherDetails.temperature)},\n`;
    out += `    rainfall: ${num(p.weatherDetails.rainfall)},\n`;
    out += `    humidity: ${num(p.weatherDetails.humidity)},\n`;
  }
  out += `  ),\n`;
}
out += '];\n';
writeFileSync(path.join(OUT_DIR, 'map_data.dart'), out, 'utf8');

// ---------------------------------------------------------------- locations
const locations = read('nigerianLocations');
out = header(['../models/weather.dart'], 'src/services/weatherService.ts (NIGERIAN_LOCATIONS)');
out += `/// Selectable regions for the weather forecast.\n`;
out += 'const List<NigerianLocation> nigerianLocations = <NigerianLocation>[\n';
for (const l of locations) {
  out += `  NigerianLocation(name: ${str(l.name)}, state: ${str(l.state)}, lat: ${num(l.lat)}, lon: ${num(l.lon)}),\n`;
}
out += '];\n';
writeFileSync(path.join(OUT_DIR, 'locations_data.dart'), out, 'utf8');

// ---------------------------------------------------------------- translations
const translations = read('translations');
out = `// GENERATED FILE — do not edit by hand.\n`;
out += `// Source: src/utils/translations.ts (translations, t())\n\n`;
out += `/// Bilingual strings. Key set is identical in both languages.\n`;
out += 'const Map<String, Map<String, String>> appTranslations =\n    <String, Map<String, String>>{\n';
for (const lang of ['en', 'ha']) {
  out += `  '${lang}': <String, String>{\n`;
  for (const [key, value] of Object.entries(translations[lang])) {
    out += `    '${key}': '${esc(value)}',\n`;
  }
  out += `  },\n`;
}
out += '};\n';
writeFileSync(path.join(OUT_DIR, 'translations_data.dart'), out, 'utf8');

console.log('generated files in', OUT_DIR);
