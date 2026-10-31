import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../services/history_service.dart';
import '../services/location_service.dart';
import '../services/sos_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import 'speak_button.dart';

/// SOS / Quick Alert card — 100% offline distress broadcast.
///
/// Port of `QuickAlertCard.tsx`: pick a distress type, confirm the emergency
/// number, and one tap opens the SMS composer with GPS coordinates, a Google
/// Maps link and a bilingual plea for help.
class SosCard extends StatefulWidget {
  const SosCard({super.key});

  @override
  State<SosCard> createState() => _SosCardState();
}

class _SosCardState extends State<SosCard> {
  final SosService _sos = SosService();
  final LocationService _location = LocationService();
  final StorageService _storage = StorageService.instance;
  final TextEditingController _phoneController =
      TextEditingController(text: SosService.defaultContact);
  final TextEditingController _noteController = TextEditingController();

  bool _expanded = false;
  bool _sending = false;
  bool _locating = false;
  bool _editingPhone = false;
  String _distressId = 'medical';
  CachedLocation? _coords;
  StreamSubscription<CachedLocation>? _locationStream;

  DistressType get _distress => SosService.distressById(_distressId);

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final stored = await _storage.getString(SosService.contactStorageKey);
    final cached = await _location.lastKnownLocation();
    if (!mounted) return;
    setState(() {
      if (stored != null && stored.isNotEmpty) {
        _phoneController.text = stored;
      }
      _coords = cached;
    });
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _toggleExpanded() async {
    setState(() => _expanded = !_expanded);
    if (_expanded) await _startLocating();
  }

  Future<void> _startLocating() async {
    if (_locating) return;
    setState(() => _locating = true);
    unawaited(_acquireOnce());
    _locationStream ??= _location.positionStream().listen(
      (location) {
        if (!mounted) return;
        setState(() => _coords = location);
        _location.saveLocation(location);
      },
      onError: (Object error) {
        debugPrint('[SosCard] position stream error: $error');
      },
    );
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _acquireOnce() async {
    final best = await _location.bestEffort();
    if (!mounted || best == null) return;
    setState(() => _coords = best);
  }

  Future<void> _savePhone() async {
    final value = _phoneController.text.trim();
    if (value.isNotEmpty) {
      await _storage.setString(SosService.contactStorageKey, value);
    }
    setState(() => _editingPhone = false);
  }

  String get _smsBody => SosService.buildSmsBody(
        distress: _distress,
        hausa: AppScope.read(context).isHausa,
        location: _coords,
        note: _noteController.text,
      );

  Future<void> _sendSms() async {
    final state = AppScope.read(context);
    setState(() => _sending = true);
    final ok = await _sos.sendSms(
      phone: _phoneController.text,
      body: _smsBody,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (!ok) {
      await Clipboard.setData(ClipboardData(text: _smsBody));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.pick(
              'No SMS app answered. The alert text was copied — paste it into any message.',
              'Babu manhajar SMS. An kwafe saƙon — liƙa shi a kowanne saƙo.',
            ),
          ),
        ),
      );
      return;
    }

    await state.recordHistory(
      type: HistoryType.mapPin,
      title: 'SOS: ${_distress.nameEn}',
      detail: _smsBody,
    );
  }

  Future<void> _copy() async {
    final state = AppScope.read(context);
    await Clipboard.setData(ClipboardData(text: _smsBody));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.pick('Alert copied', 'An kwafe saƙon')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;
    final location = _coords;
    final age = location == null
        ? null
        : LocationService.formatAge(location.timestamp);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFB91C1C), Color(0xFF7F1D1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.faint(AppColors.danger, 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('🆘', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          hausa
                              ? 'S.O.S — Faɗakarwar Gaggawa'
                              : 'SOS — Emergency Alert',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hausa
                              ? 'Aika coordinates na GPS da saƙon neman ɗauki ta SMS ba tare da intanet ba'
                              : 'Broadcast live GPS coordinates & distress signal via SMS without internet',
                          style: const TextStyle(
                            color: Color(0xFFFEE2E2),
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...<Widget>[
            const Divider(color: Color(0x33FFFFFF), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: SosService.distressTypes.map((type) {
                      final selected = type.id == _distressId;
                      return GestureDetector(
                        onTap: () => setState(() => _distressId = type.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : const Color(0x26FFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : const Color(0x4DFFFFFF),
                            ),
                          ),
                          child: Text(
                            '${type.emoji} ${type.displayName(hausa)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.danger
                                  : Colors.white,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: hausa
                          ? 'Ƙarin bayani (misali: mutum biyu suka ji rauni)'
                          : 'Extra detail (e.g. two people injured)',
                      hintStyle: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: const Color(0x26FFFFFF),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.my_location,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                location == null
                                    ? (hausa
                                        ? 'Ana neman GPS...'
                                        : 'Searching for GPS...')
                                    : 'Lat ${location.latText}, Long ${location.lngText}'
                                        '${location.accuracy > 0 ? ' (±${location.accuracy.round()}m)' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (age != null)
                                Text(
                                  location!.source ==
                                          LocationSource.liveSatellite
                                      ? (hausa
                                          ? 'Sabon GPS — ${age.ageLabelHa}'
                                          : 'Live fix — ${age.ageLabelEn}')
                                      : (hausa
                                          ? 'Wuri na baya — ${age.ageLabelHa}'
                                          : 'Last known — ${age.ageLabelEn}'),
                                  style: TextStyle(
                                    color: age.isOld
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFFFEE2E2),
                                    fontSize: 10.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _acquireOnce,
                          icon: const Icon(Icons.refresh,
                              color: Colors.white, size: 18),
                          tooltip: hausa ? 'Sabunta GPS' : 'Refresh GPS',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.sms_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _editingPhone
                            ? TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Color(0x26FFFFFF),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              )
                            : Text(
                                '${hausa ? 'Lambar gaggawa' : 'Emergency number'}: ${_phoneController.text}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (_editingPhone) {
                            _savePhone();
                          } else {
                            setState(() => _editingPhone = true);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          _editingPhone
                              ? (hausa ? 'Adana' : 'Save')
                              : (hausa ? 'Canza' : 'Change'),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sending ? null : _sendSms,
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.danger,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            hausa ? 'Aika ta SMS' : 'Send SOS via SMS',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.danger,
                            minimumSize: const Size.fromHeight(46),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _copy,
                        tooltip: hausa ? 'Kwafe saƙon' : 'Copy alert',
                        icon: const Icon(Icons.copy_all, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x33FFFFFF),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SpeakButton(
                        textBuilder: _smsBody,
                        color: Colors.white,
                        background: const Color(0x33FFFFFF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
