import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// About / Game da SmartVillage.
/// Port of `AboutScreen.tsx`.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF1F7A4C), Color(0xFF14512F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🌿', style: TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'SmartVillage v2.0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          hausa
                              ? 'Flutter na asali — sauri, ba intanet'
                              : 'Native Flutter build — fast and offline',
                          style: const TextStyle(
                            color: Color(0xFFD1FAE5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SpeakButton(
                    color: Colors.white,
                    background: const Color(0x33FFFFFF),
                    textBuilder: () => hausa
                        ? 'SmartVillage shine manhajar taimakon manoma ba tare da intanet ba. Tana da binciken cututtukan shuke-shuke, lafiyar iyali, tsabtar ruwa, likitancin dabbobi, taswira da kalandar noma. Duk aiki a cikin waya.'
                        : 'SmartVillage is an offline-first farm and family health assistant. It covers crop disease diagnosis, human symptom triage, water safety, livestock checks, offline mapping and a planting calendar. Everything runs on the phone.',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                hausa
                    ? 'An gina shi ga al\'ummar karkara a Arewacin Najeriya: aiki ba tare da intanet, murya ta Hausa, da bayanan gona 13 da dabbobi 9.'
                    : 'Built for rural communities in Northern Nigeria: works with no internet, speaks Hausa, and ships 13 crop libraries plus 9 livestock species.',
                style: const TextStyle(
                  color: Color(0xFFECFDF5),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: hausa ? 'Yadda ake aiki' : 'How it works',
          accent: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Bullet(
                icon: Icons.offline_bolt_outlined,
                text: hausa
                    ? 'Duk bincike a cikin waya — babu aika hoto zuwa intanet.'
                    : 'All analysis happens on-device — no images are uploaded.',
              ),
              _Bullet(
                icon: Icons.record_voice_over_outlined,
                text: hausa
                    ? 'Muryar Hausa (Murya ONNX) tana aiki a cikin waya.'
                    : 'The Hausa voice (Murya ONNX) runs natively on the phone.',
              ),
              _Bullet(
                icon: Icons.translate,
                text: hausa
                    ? 'Dukkan rubutu cikin Turanci da Hausa.'
                    : 'Every screen is fully bilingual (English / Hausa).',
              ),
              _Bullet(
                icon: Icons.lock_outline,
                text: hausa
                    ? 'Bayanan manomi suna a wayarsa kawai.'
                    : 'Farmer data stays on the device, stored locally.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: hausa ? 'Bayanai da tushe' : 'Data sources & credits',
          accent: AppColors.info,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Bullet(
                icon: Icons.agriculture,
                text: hausa
                    ? 'Bayanan cututtukan shuka: IITA, NRCRI, IAR da littattafan noma.'
                    : 'Crop disease guidance: IITA, NRCRI, IAR and extension literature.',
              ),
              _Bullet(
                icon: Icons.pets,
                text: hausa
                    ? 'Likitancin dabbobi: jagororin FDA/Nigeria Veterinary Council.'
                    : 'Livestock guidance: veterinary extension references.',
              ),
              _Bullet(
                icon: Icons.water_drop,
                text: 'WHO / NSDWQ drinking-water standards.',
              ),
              _Bullet(
                icon: Icons.cloud,
                text: 'Weather: Open-Meteo (cached for offline use).',
              ),
              _Bullet(
                icon: Icons.graphic_eq,
                text: hausa
                    ? 'Muryar Hausa: Murya ONNX (a waya).'
                    : 'Hausa voice: Murya ONNX model (on-device).',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: state.t('notMedical'),
          accent: AppColors.warning,
          child: Text(
            hausa
                ? 'SmartVillage ba ya maye gurbin likita, likitan dabbobi ko malamin gona. Yana taimakawa ne kawai wajen yanke shawara cikin gaggawa.'
                : 'SmartVillage does not replace a doctor, veterinarian or extension officer. It is a decision aid for the field.',
            style: const TextStyle(fontSize: 11.5, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'SmartVillage · SmartVillage-Native · MIT licence',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
