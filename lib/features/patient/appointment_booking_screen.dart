import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:ui';

class AppointmentBookingScreen extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic>? doctorData;

  const AppointmentBookingScreen({
    super.key,
    required this.doctorId,
    this.doctorData,
  });

  @override
  State<AppointmentBookingScreen> createState() =>
      _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
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

  List<Map<String, dynamic>> _sucursales = [];
  Map<String, dynamic>? _selectedBranch;
  List<Map<String, dynamic>> _horarios = [];
  bool _isLoadingData = true;
  List<String> _bookedTimes = [];
  bool _isLoadingTimes = false;
  List<Map<String, dynamic>> _blockedDates = [];
  final ScrollController _scrollController = ScrollController();
  late DateTime _carruselStartDate;

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _carruselStartDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 15));
    _fetchDoctorSchedules();
    _fetchBlockedDates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchBlockedDates() async {
    try {
      final supabase = Supabase.instance.client;
      
      final data = await supabase
          .from('bloqueos_doctor')
          .select('*')
          .eq('doctor_id', widget.doctorId)
          .gte('fecha', DateTime.now().toIso8601String().split('T')[0]);

      if (mounted) {
        setState(() {
          _blockedDates = (data as List<dynamic>).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error al cargar bloqueos: $e');
    }
  }

  Future<void> _fetchDoctorSchedules() async {
    try {
      final supabase = Supabase.instance.client;
      print('Buscando horarios para doctor_id: ${widget.doctorId}');
      
      // Cargar horarios sin relación
      final horariosData = await supabase
          .from('horarios_doctor')
          .select('id, dia_semana, hora_inicio, hora_fin, sucursal_id')
          .eq('doctor_id', widget.doctorId);

      print('Horarios encontrados: ${horariosData.length}');
      print('Datos: $horariosData');

      // Cargar sucursales aparte
      final sucursalesData = await supabase
          .from('sucursales')
          .select('id, nombre');

      print('Sucursales encontradas: ${sucursalesData.length}');

      // Mapear sucursales por ID
      final sucursalMap = {
        for (var s in sucursalesData)
        s['id']: s
      };

      // Construir horarios enriquecidos con datos de sucursal
      final fetchedHorarios =
          List<Map<String, dynamic>>.from(horariosData);

      for (var h in fetchedHorarios) {
        h['sucursal_data'] = sucursalMap[h['sucursal_id']];
      }

      // Extraer sucursales únicas
      final Map<String, Map<String, dynamic>> uniqueBranches = {};
      for (var h in fetchedHorarios) {
        final sucursalId = h['sucursal_id'];
        final sucursalData = h['sucursal_data'];
        if (sucursalId != null) {
          uniqueBranches[sucursalId] = {
            'id': sucursalId,
            'nombre': sucursalData?['nombre'] ?? 'Sucursal',
          };
        }
      }

      print('Sucursales únicas: ${uniqueBranches.length}');

      if (mounted) {
        setState(() {
          _horarios = fetchedHorarios;
          _sucursales = uniqueBranches.values.toList();
          _isLoadingData = false;
        });
      }
    } catch (e) {
      print('Error al cargar horarios: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar horarios: $e')));
      }
    }
  }

  Future<void> _fetchBookedTimesForDate() async {
    if (_selectedDate == null || _selectedBranch == null) return;

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
          .eq('doctor_id', widget.doctorId)
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar citas: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _currentBranchHorarios {
    if (_selectedBranch == null) return [];
    return _horarios
        .where((h) => h['sucursal_id'] == _selectedBranch!['id'])
        .toList();
  }

  List<int> get _validSqlDays {
    return _currentBranchHorarios
        .map((h) => h['dia_semana'] as int)
        .toSet()
        .toList();
  }

  void _scrollToSelectedDay(DateTime selectedDay) {
    if (!_scrollController.hasClients) return;

    final targetDate = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final difference = targetDate.difference(_carruselStartDate).inDays;

    if (difference >= 0 && difference < 60) {
      final viewportWidth = MediaQuery.of(context).size.width - 40;
      final dayWidth = 82.0; // 70 width + 12 margin
      final maxScroll = (60 * dayWidth) - viewportWidth;

      final targetOffset =
          ((difference * dayWidth) - (viewportWidth / 2) + 41.0).clamp(
            0.0,
            maxScroll > 0 ? maxScroll : 0.0,
          );

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<DateTime> _generateNext8Dates() {
    final validDays = _validSqlDays;
    if (validDays.isEmpty) return [];

    List<DateTime> dates = [];
    DateTime current = _carruselStartDate;

    // Get blocked date strings for easy comparison
    final blockedDateStrings = _blockedDates
        .map((block) => block['fecha'] as String)
        .toSet();

    // Generate 60 days like doctor schedule screen
    for (int i = 0; i < 60; i++) {
      final sqlDay = current.weekday - 1;
      final dateString = '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      
      if (validDays.contains(sqlDay) && !blockedDateStrings.contains(dateString)) {
        dates.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  List<String> get _times {
    if (_selectedDate == null) return [];
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

    // Get blocked time slots for the selected date
    final dateString = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
    final blockedTimeRanges = _blockedDates
        .where((block) => block['fecha'] == dateString && block['hora_inicio'] != null)
        .toList();

    List<String> slots = [];
    final now = DateTime.now();
    final isToday =
        _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;

    for (int h = startHour; h < endHour; h++) {
      if (isToday && h <= now.hour) {
        continue; // Omitir horas que ya pasaron
      }

      // Check if this hour is blocked by doctor
      bool isBlocked = false;
      for (final block in blockedTimeRanges) {
        final blockStart = int.parse(block['hora_inicio'].toString().split(':')[0]);
        final blockEnd = int.parse(block['hora_fin'].toString().split(':')[0]);
        if (h >= blockStart && h < blockEnd) {
          isBlocked = true;
          break;
        }
      }

      if (isBlocked) continue;

      // Check if this hour is already booked by another patient
      int displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      String amPm = h >= 12 ? 'PM' : 'AM';
      final timeSlot = '$displayHour:00 $amPm';
      
      if (_bookedTimes.contains(timeSlot)) {
        continue; // Skip already booked time slots
      }

      slots.add(timeSlot);
    }
    return slots;
  }

  // DEBUG FLAGS
  final bool _forceTimeTakenError = false;
  final bool _forcePaymentRejectedError = false;

  void _handleBookAppointment() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('No estás autenticado.');

      // 1. Formatear la hora (de "2:00 PM" a "14:00:00")
      final timeParts = _selectedTime!.split(' ');
      final hourStr = timeParts[0].split(':')[0];
      int hour = int.parse(hourStr);
      if (timeParts[1] == 'PM' && hour != 12) hour += 12;
      if (timeParts[1] == 'AM' && hour == 12) hour = 0;
      final timeFormatted = '${hour.toString().padLeft(2, '0')}:00:00';

      // 2. Formatear la fecha
      final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // 3. Verificación extra: Verificar si el horario fue bloqueado por el doctor
      final blocks = await supabase
          .from('bloqueos_doctor')
          .select('*')
          .eq('doctor_id', widget.doctorId)
          .eq('fecha', dateFormatted);

      for (final block in blocks) {
        final horaInicio = block['hora_inicio'] as String?;
        final horaFin = block['hora_fin'] as String?;

        if (horaInicio == null && horaFin == null) {
          // Bloqueo de todo el día
          throw Exception('El doctor ha bloqueado esta fecha. Por favor selecciona otra fecha.');
        }

        if (horaInicio != null && horaFin != null) {
          // Verificar si la hora está dentro del rango bloqueado
          final blockStartHour = int.parse(horaInicio.split(':')[0]);
          final blockEndHour = int.parse(horaFin.split(':')[0]);
          
          if (hour >= blockStartHour && hour < blockEndHour) {
            throw Exception('El doctor ha bloqueado este horario. Por favor selecciona otro horario.');
          }
        }
      }

      // 4. Verificación extra: Verificar si el horario ya fue reservado por otro paciente
      final existingAppointments = await supabase
          .from('citas')
          .select('id')
          .eq('doctor_id', widget.doctorId)
          .eq('sucursal_id', _selectedBranch!['id'])
          .eq('fecha', dateFormatted)
          .eq('hora', timeFormatted)
          .neq('estado', 'cancelada');

      if (existingAppointments.isNotEmpty) {
        throw Exception('Este horario ya fue reservado por otro paciente. Por favor selecciona otro horario.');
      }

      // 5. Insertar cita en Supabase
      await supabase.from('citas').insert({
        'usuario_id': user.id,
        'doctor_id': widget.doctorId,
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

    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: AltheaColors.lightBg,
        body: Center(
          child: CircularProgressIndicator(color: AltheaColors.navy),
        ),
      );
    }

    final doctor =
        widget.doctorData ??
        {
          'name': 'Dra. María González',
          'specialty': 'Cardiología',
          'consultorio': 'Consultorio 301 - Seccion 1',
          'image': 'assets/images/doctora1.png',
        };

    final isButtonEnabled =
        _selectedDate != null && _selectedTime != null && !_isProcessing && _isCardValid;

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
                        onPressed: () => context.go('/patient/doctors'),
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
                        'Agendar Cita',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Doctor Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AltheaColors.gold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AltheaColors.gold.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  doctor['specialty']!,
                                  style: const TextStyle(
                                    color: AltheaColors.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                doctor['name']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  // Branch Selection
                  if (_sucursales.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AltheaColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: AltheaColors.textSecondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay horarios disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AltheaColors.navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Este doctor aún no ha configurado sus horarios de atención. Por favor contacta a la recepción para más información.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AltheaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Branch Selection
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
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selecciona una sucursal',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AltheaColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _sucursales.map((sucursal) {
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
                    const SizedBox(height: 24),
                  ],

                  if (_selectedBranch != null) ...[
                    // Select Date
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
                              controller: _scrollController,
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

                                          // Update carousel if selected date is out of range
                                          final diff = date.difference(_carruselStartDate).inDays;
                                          if (diff < 0 || diff >= 60) {
                                            _carruselStartDate = DateTime(
                                              date.year,
                                              date.month,
                                              date.day,
                                            ).subtract(const Duration(days: 15));
                                          }
                                        });
                                        _fetchBookedTimesForDate();
                                        _scrollToSelectedDay(date);
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

                              // Encontrar una fecha inicial válida que cumpla con el predicado para evitar crash
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
                                locale: const Locale('es', 'ES'),
                                selectableDayPredicate: (DateTime val) {
                                  final sqlDay = val.weekday - 1;
                                  if (!validDays.contains(sqlDay)) return false;
                                  
                                  // Check if date is blocked by doctor
                                  final dateString = '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
                                  final isBlocked = _blockedDates.any((block) => block['fecha'] == dateString);
                                  return !isBlocked;
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
                    // Select Time
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
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _times.map((time) {
                                  final isSelected = _selectedTime == time;
                                  return GestureDetector(
                                    onTap: (_selectedDate != null)
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
                                        color: isSelected
                                            ? AltheaColors.navy
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AltheaColors.navy
                                              : AltheaColors.borderLight,
                                        ),
                                      ),
                                      child: Text(
                                        time,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : AltheaColors.navy,
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
                  ], // End if _selectedBranch != null

                  const SizedBox(height: 24),
                  // Payment Method
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
                  // Summary & Checkout
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
                          'Resumen de tu cita',
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
                                ? _handleBookAppointment
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
              '¡Cita Confirmada!',
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
                'Tu cita ha sido agendada exitosamente. Hemos enviado los detalles a tu correo electrónico.',
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
                      onPressed: () => context.go('/patient/dashboard'),
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
                      onPressed: () => context.go('/patient/appointments'),
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
                        'Ver Mis Citas',
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
