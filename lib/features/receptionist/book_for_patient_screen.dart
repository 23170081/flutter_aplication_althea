import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class BookForPatientScreen extends StatefulWidget {
  final String? patientId;
  const BookForPatientScreen({super.key, this.patientId});

  @override
  State<BookForPatientScreen> createState() => _BookForPatientScreenState();
}

class _BookForPatientScreenState extends State<BookForPatientScreen> {
  String? _selectedPatientId;
  String? _selectedDoctorId;
  Map<String, dynamic>? _selectedBranch;
  DateTime? _selectedDate;
  String? _selectedTime;
  String _paymentMethod = 'card';
  bool _showConfirmation = false;
  bool _isProcessing = false;
  String? _error;

  String _cardName = '';
  String _cardNumber = '';
  String _expiry = '';
  String _cvv = '';

  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _horariosDoctor = [];
  List<String> _bookedTimes = [];

  bool _isLoadingInitial = true;
  bool _isLoadingBranches = false;
  bool _isLoadingTimes = false;

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final supabase = Supabase.instance.client;
      final patientsData = await supabase
          .from('usuarios')
          .select('id, nombre_completo, telefono')
          .eq('rol', 'paciente');
      final doctorsData = await supabase
          .from('usuarios')
          .select('id, nombre_completo, doctores(especialidad)')
          .eq('rol', 'doctor');

      final parsedPatients = List<Map<String, dynamic>>.from(patientsData).map((p) => {
        'id': p['id'].toString(),
        'name': p['nombre_completo'] ?? 'Sin nombre',
        'phone': p['telefono'] ?? '',
      }).toList();

      final parsedDoctors = List<Map<String, dynamic>>.from(doctorsData).map((d) {
        String specialty = 'General';
        final doctoresMap = d['doctores'];
        if (doctoresMap != null) {
          if (doctoresMap is List && doctoresMap.isNotEmpty) {
            specialty = doctoresMap[0]['especialidad']?.toString() ?? 'General';
          } else if (doctoresMap is Map) {
            specialty = doctoresMap['especialidad']?.toString() ?? 'General';
          }
        }
        return {
          'id': d['id'].toString(),
          'name': d['nombre_completo'] ?? 'Doctor',
          'specialty': specialty,
          'display': '${d['nombre_completo']} - $specialty'
        };
      }).toList();

      if (mounted) {
        setState(() {
          _patients = parsedPatients;
          _doctors = parsedDoctors;
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInitial = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos iniciales: $e')),
        );
      }
    }
  }

  Future<void> _onDoctorSelected(String? doctorId) async {
    setState(() {
      _selectedDoctorId = doctorId;
      _selectedBranch = null;
      _selectedDate = null;
      _selectedTime = null;
      _branches = [];
      _horariosDoctor = [];
      _bookedTimes = [];
      if (doctorId != null) {
        _isLoadingBranches = true;
      }
    });

    if (doctorId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('horarios_doctor')
          .select('id, dia_semana, hora_inicio, hora_fin, sucursales(id, nombre)')
          .eq('doctor_id', doctorId);

      final List<Map<String, dynamic>> fetchedHorarios =
          List<Map<String, dynamic>>.from(data);
      final Map<String, Map<String, dynamic>> uniqueBranches = {};
      for (var h in fetchedHorarios) {
        final sucursal = h['sucursales'];
        if (sucursal != null) {
          uniqueBranches[sucursal['id']] = {
            'id': sucursal['id'],
            'nombre': sucursal['nombre'],
          };
        }
      }

      if (mounted) {
        setState(() {
          _horariosDoctor = fetchedHorarios;
          _branches = uniqueBranches.values.toList();
          _isLoadingBranches = false;
          if (_branches.length == 1) {
            _selectedBranch = _branches[0];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBranches = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar sucursales: $e')),
        );
      }
    }
  }

  Future<void> _fetchBookedTimesForDate() async {
    if (_selectedDate == null || _selectedBranch == null || _selectedDoctorId == null) return;

    setState(() {
      _isLoadingTimes = true;
      _bookedTimes = [];
    });

    try {
      final supabase = Supabase.instance.client;
      final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final data = await supabase
          .from('citas')
          .select('hora')
          .eq('doctor_id', _selectedDoctorId!)
          .eq('sucursal_id', _selectedBranch!['id'])
          .eq('fecha', dateFormatted)
          .neq('estado', 'cancelada');

      final List<String> booked = [];
      for (var row in data) {
        final timeString = row['hora'].toString();
        final parts = timeString.split(':');
        int h = int.parse(parts[0]);
        int displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        String amPm = h >= 12 ? 'PM' : 'AM';
        booked.add('$displayHour:00 $amPm');
      }

      if (mounted) {
        setState(() {
          _bookedTimes = booked;
          _isLoadingTimes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTimes = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar citas: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _currentBranchHorarios {
    if (_selectedBranch == null) return [];
    return _horariosDoctor
        .where((h) => h['sucursales']['id'] == _selectedBranch!['id'])
        .toList();
  }

  List<int> get _validSqlDays {
    return _currentBranchHorarios
        .map((h) => h['dia_semana'] as int)
        .toSet()
        .toList();
  }

  List<DateTime> _generateNext8Dates() {
    final validDays = _validSqlDays;
    if (validDays.isEmpty) return [];

    List<DateTime> dates = [];
    DateTime current = DateTime.now();
    current = DateTime(current.year, current.month, current.day);

    while (dates.length < 8) {
      final sqlDay = current.weekday - 1;
      if (validDays.contains(sqlDay)) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  List<String> get _times {
    if (_selectedDate == null || _selectedBranch == null) return [];
    final sqlDay = _selectedDate!.weekday - 1;
    final horario = _currentBranchHorarios.firstWhere(
      (h) => h['dia_semana'] == sqlDay,
      orElse: () => <String, dynamic>{},
    );

    if (horario.isEmpty) return [];

    final inicioParts = horario['hora_inicio'].toString().split(':');
    final finParts = horario['hora_fin'].toString().split(':');

    int startHour = int.parse(inicioParts[0]);
    int endHour = int.parse(finParts[0]);

    List<String> slots = [];
    final now = DateTime.now();
    final isToday =
        _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;

    for (int h = startHour; h < endHour; h++) {
      if (isToday && h <= now.hour) {
        continue;
      }
      int displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      String amPm = h >= 12 ? 'PM' : 'AM';
      slots.add('$displayHour:00 $amPm');
    }
    return slots;
  }

  bool get _isCardNameValid => _cardName.trim().length >= 3;

  bool get _isCardNumberValid {
    final clean = _cardNumber.replaceAll(RegExp(r'\D'), '');
    return clean.length == 16;
  }

  bool get _isExpiryValid {
    if (_expiry.length != 5) return false;
    final regExp = RegExp(r'^(0[1-9]|1[0-2])\/[0-9]{2}$');
    if (!regExp.hasMatch(_expiry)) return false;
    try {
      final parts = _expiry.split('/');
      final month = int.parse(parts[0]);
      final year = int.parse('20${parts[1]}');
      final now = DateTime.now();
      final expiryDate = DateTime(year, month + 1).subtract(const Duration(days: 1));
      return expiryDate.isAfter(now) || (expiryDate.year == now.year && expiryDate.month == now.month);
    } catch (_) {
      return false;
    }
  }

  bool get _isCvvValid {
    final clean = _cvv.replaceAll(RegExp(r'\D'), '');
    return clean.length == 3 || clean.length == 4;
  }

  bool get _isCardValid =>
      _paymentMethod != 'card' ||
      (_isCardNameValid && _isCardNumberValid && _isExpiryValid && _isCvvValid);

  void _handleBooking() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final timeParts = _selectedTime!.split(' ');
      final hourStr = timeParts[0].split(':')[0];
      int hour = int.parse(hourStr);
      if (timeParts[1] == 'PM' && hour != 12) hour += 12;
      if (timeParts[1] == 'AM' && hour == 12) hour = 0;
      final timeFormatted = '${hour.toString().padLeft(2, '0')}:00:00';
      final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      await supabase.from('citas').insert({
        'usuario_id': _selectedPatientId,
        'doctor_id': _selectedDoctorId,
        'sucursal_id': _selectedBranch!['id'],
        'fecha': dateFormatted,
        'hora': timeFormatted,
        'estado': 'programada',
      });

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _showConfirmation = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error al agendar la cita: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showConfirmation) {
      return _buildConfirmationScreen();
    }

    if (_isLoadingInitial) {
      return const Scaffold(
        backgroundColor: AltheaColors.lightBg,
        body: Center(
          child: CircularProgressIndicator(color: AltheaColors.navy),
        ),
      );
    }

    final isButtonEnabled = _selectedPatientId != null &&
        _selectedDoctorId != null &&
        _selectedBranch != null &&
        _selectedDate != null &&
        _selectedTime != null &&
        !_isProcessing &&
        _isCardValid;

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(
                top: 60,
                bottom: 40,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AltheaColors.navy,
                    AltheaColors.navyMid,
                    AltheaColors.navy,
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/receptionist/dashboard'),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Agendar para Paciente',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient selection or Display
                  if (widget.patientId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AltheaColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AltheaColors.gold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AltheaColors.gold,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Paciente Seleccionado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AltheaColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _patients.firstWhere(
                                    (p) => p['id'].toString() == _selectedPatientId,
                                    orElse: () => {'name': 'Cargando...'},
                                  )['name'] ?? 'Cargando...',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AltheaColors.navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    _CustomDropdownCard(
                      icon: Icons.person_search_rounded,
                      label: 'Selecciona un Paciente',
                      hint: 'Seleccionar paciente',
                      items: _patients
                          .map((p) => DropdownMenuItem(
                                value: p['id'].toString(),
                                child: Text('${p['name']} (${p['phone']})'),
                              ))
                          .toList(),
                      value: _selectedPatientId,
                      onChanged: (v) => setState(() {
                        _selectedPatientId = v;
                      }),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Doctor selection
                  _CustomDropdownCard(
                    icon: Icons.medical_services_rounded,
                    label: 'Selecciona un Doctor',
                    hint: 'Seleccionar doctor',
                    items: _doctors
                        .map((d) => DropdownMenuItem(
                              value: d['id'].toString(),
                              child: Text(d['display']),
                            ))
                        .toList(),
                    value: _selectedDoctorId,
                    onChanged: _onDoctorSelected,
                  ),
                  const SizedBox(height: 24),

                  // Branch selection (if doctor is selected)
                  if (_selectedDoctorId != null) ...[
                    if (_isLoadingBranches)
                      const Center(
                        child: CircularProgressIndicator(color: AltheaColors.navy),
                      )
                    else if (_branches.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AltheaColors.borderLight),
                        ),
                        child: const Center(
                          child: Text(
                            'Este doctor no tiene sucursales asignadas',
                            style: TextStyle(
                              color: AltheaColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AltheaColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AltheaColors.lightBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AltheaColors.borderLight,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.store,
                                    color: AltheaColors.gold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Selecciona una sucursal',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AltheaColors.navy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _branches.map((sucursal) {
                                final isSelected =
                                    _selectedBranch?['id'] == sucursal['id'];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedBranch = sucursal;
                                      _selectedDate = null;
                                      _selectedTime = null;
                                      _bookedTimes = [];
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AltheaColors.navy
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? AltheaColors.navy
                                            : AltheaColors.borderLight,
                                      ),
                                    ),
                                    child: Text(
                                      sucursal['nombre'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AltheaColors.navy,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  // Date Selection (if branch is selected)
                  if (_selectedBranch != null) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AltheaColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AltheaColors.lightBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AltheaColors.borderLight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.calendar_month,
                                  color: AltheaColors.gold,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selecciona una fecha',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AltheaColors.navy,
                                    ),
                                  ),
                                  Text(
                                    'Próximos días disponibles',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AltheaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                              },
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              child: Row(
                                children: _generateNext8Dates().map((date) {
                                  final isSelected =
                                      _selectedDate?.day == date.day &&
                                      _selectedDate?.month == date.month &&
                                      _selectedDate?.year == date.year;
                                  final monthStr = DateFormat(
                                    'MMM',
                                    'es_MX',
                                  ).format(date).toUpperCase();
                                  final dayStr = DateFormat(
                                    'EEE',
                                    'es_MX',
                                  ).format(date).replaceAll('.', '');

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedDate = date;
                                          _selectedTime = null;
                                        });
                                        _fetchBookedTimesForDate();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? const LinearGradient(
                                                  colors: [
                                                    AltheaColors.gold,
                                                    AltheaColors.goldLight,
                                                  ],
                                                )
                                              : null,
                                          color: isSelected
                                              ? null
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.transparent
                                                : AltheaColors.borderLight,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              monthStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isSelected
                                                    ? Colors.white.withOpacity(
                                                        0.8,
                                                      )
                                                    : AltheaColors
                                                          .textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${date.day}',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w900,
                                                color: isSelected
                                                    ? Colors.white
                                                    : AltheaColors.navy,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              dayStr,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.white.withOpacity(
                                                        0.9,
                                                      )
                                                    : AltheaColors.navy,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () async {
                              final validDays = _validSqlDays;
                              final now = DateTime.now();
                              final today = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );

                              DateTime initial = _selectedDate ?? today;
                              if (!validDays.contains(initial.weekday - 1)) {
                                initial = today;
                                while (!validDays.contains(
                                  initial.weekday - 1,
                                )) {
                                  initial = initial.add(
                                    const Duration(days: 1),
                                  );
                                  if (validDays.isEmpty ||
                                      initial.difference(today).inDays > 30) {
                                    initial = today;
                                    break;
                                  }
                                }
                              }

                              final d = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: today,
                                lastDate: today.add(const Duration(days: 90)),
                                selectableDayPredicate: (DateTime val) {
                                  final sqlDay = val.weekday - 1;
                                  return validDays.contains(sqlDay);
                                },
                              );
                              if (d != null) {
                                setState(() {
                                  _selectedDate = d;
                                  _selectedTime = null;
                                });
                                _fetchBookedTimesForDate();
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AltheaColors.lightBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AltheaColors.borderLight,
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: AltheaColors.navy,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'O selecciona en el calendario',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AltheaColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Time Selection
                    Opacity(
                      opacity: _selectedDate != null ? 1.0 : 0.5,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AltheaColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AltheaColors.lightBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AltheaColors.borderLight,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.access_time,
                                    color: AltheaColors.gold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selecciona una hora',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AltheaColors.navy,
                                      ),
                                    ),
                                    Text(
                                      'Horarios disponibles',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AltheaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_isLoadingTimes)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AltheaColors.navy,
                                  ),
                                ),
                              )
                            else if (_times.isEmpty)
                              const Center(
                                child: Text(
                                  'No hay horarios disponibles para este día',
                                  style: TextStyle(
                                    color: AltheaColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _times.map((time) {
                                  final isBooked = _bookedTimes.contains(time);
                                  final isSelected = _selectedTime == time;
                                  return GestureDetector(
                                    onTap: (_selectedDate != null && !isBooked)
                                        ? () => setState(
                                            () => _selectedTime = time,
                                          )
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isBooked
                                            ? AltheaColors.lightBg
                                            : (isSelected
                                                  ? AltheaColors.navy
                                                  : Colors.white),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isBooked
                                              ? AltheaColors.borderLight
                                              : (isSelected
                                                    ? AltheaColors.navy
                                                    : AltheaColors.borderLight),
                                        ),
                                      ),
                                      child: Text(
                                        time,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isBooked
                                              ? AltheaColors.textSecondary
                                                    .withOpacity(0.5)
                                              : (isSelected
                                                    ? Colors.white
                                                    : AltheaColors.navy),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payment Method Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AltheaColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AltheaColors.lightBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AltheaColors.borderLight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.credit_card,
                                  color: AltheaColors.gold,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Método de pago',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AltheaColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => setState(() => _paymentMethod = 'card'),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _paymentMethod == 'card'
                                    ? AltheaColors.gold.withOpacity(0.05)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _paymentMethod == 'card'
                                      ? AltheaColors.gold
                                      : AltheaColors.borderLight,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _paymentMethod == 'card'
                                          ? AltheaColors.gold.withOpacity(0.2)
                                          : AltheaColors.lightBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.credit_card,
                                      color: _paymentMethod == 'card'
                                          ? AltheaColors.gold
                                          : AltheaColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tarjeta',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AltheaColors.navy,
                                          ),
                                        ),
                                        Text(
                                          'Crédito o Débito',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AltheaColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _paymentMethod == 'card'
                                          ? AltheaColors.gold
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _paymentMethod == 'card'
                                            ? AltheaColors.gold
                                            : AltheaColors.borderLight,
                                        width: 2,
                                      ),
                                    ),
                                    child: _paymentMethod == 'card'
                                        ? const Center(
                                            child: Icon(
                                              Icons.check,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_paymentMethod == 'card') ...[
                            const SizedBox(height: 20),
                            const Divider(color: AltheaColors.borderLight),
                            const SizedBox(height: 20),
                            _buildTextField(
                              'Nombre en la tarjeta',
                              'Como aparece en el plástico',
                              (val) => setState(() => _cardName = val),
                              maxLength: 50,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Número de tarjeta',
                              '0000 0000 0000 0000',
                              (val) => setState(() => _cardNumber = val),
                              isNumber: true,
                              maxLength: 19,
                              inputFormatters: [
                                CardNumberInputFormatter(),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    'Vencimiento',
                                    'MM/YY',
                                    (val) => setState(() => _expiry = val),
                                    maxLength: 5,
                                    inputFormatters: [
                                      CardExpiryInputFormatter(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    'CVV',
                                    '***',
                                    (val) => setState(() => _cvv = val),
                                    isPassword: true,
                                    isNumber: true,
                                    maxLength: 4,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cost summary and book button
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AltheaColors.navy, AltheaColors.navyMid],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AltheaColors.navy.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resumen de la cita',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Costo de Consulta',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              const Text(
                                '\$800 MXN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Anticipo Requerido',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              const Text(
                                '\$400 MXN',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Total a pagar hoy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    AltheaColors.gold,
                                    AltheaColors.goldLight,
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  '\$400',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.redAccent,
                                      size: 16,
                                    ),
                                    onPressed: () =>
                                        setState(() => _error = null),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isButtonEnabled
                                  ? _handleBooking
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AltheaColors.gold,
                                disabledBackgroundColor: Colors.white.withOpacity(
                                  0.1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: AltheaColors.navy,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.shield_rounded,
                                          color: isButtonEnabled
                                              ? AltheaColors.navy
                                              : Colors.white.withOpacity(0.4),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _paymentMethod == 'card'
                                              ? 'Pagar Anticipo y Agendar'
                                              : 'Confirmar y Agendar',
                                          style: TextStyle(
                                            color: isButtonEnabled
                                                ? AltheaColors.navy
                                                : Colors.white.withOpacity(0.4),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              'Transacción 100% segura y encriptada',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    Function(String) onChanged, {
    bool isNumber = false,
    bool isPassword = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AltheaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: onChanged,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          obscureText: isPassword,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AltheaColors.navy,
          ),
          decoration: InputDecoration(
            counterText: "",
            hintText: hint,
            hintStyle: TextStyle(
              color: AltheaColors.textSecondary.withOpacity(0.5),
            ),
            filled: true,
            fillColor: AltheaColors.lightBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationScreen() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AltheaColors.lightBg, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AltheaColors.gold, AltheaColors.goldLight],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AltheaColors.gold.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              '¡Cita Agendada!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AltheaColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'La cita para el paciente ha sido registrada exitosamente en el sistema.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AltheaColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/receptionist/dashboard'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: AltheaColors.borderLight,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Ir al Inicio',
                        style: TextStyle(
                          color: AltheaColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.go('/receptionist/search-patient'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AltheaColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 10,
                        shadowColor: AltheaColors.navy.withOpacity(0.5),
                      ),
                      child: const Text(
                        'Buscar Paciente',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomDropdownCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final List<DropdownMenuItem<String>>? items;
  final String? value;
  final void Function(String?)? onChanged;

  const _CustomDropdownCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AltheaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AltheaColors.lightBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AltheaColors.borderLight),
                ),
                child: Icon(
                  icon,
                  color: AltheaColors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AltheaColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AltheaColors.lightBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AltheaColors.borderLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: Text(
                  hint,
                  style: const TextStyle(
                    color: AltheaColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: value,
                items: items,
                onChanged: onChanged,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AltheaColors.navy,
                ),
                style: const TextStyle(
                  color: AltheaColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 16) {
      text = text.substring(0, 16);
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 4) {
      text = text.substring(0, 4);
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
