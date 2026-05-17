import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BookForPatientScreen extends StatefulWidget {
  final String? patientId;
  const BookForPatientScreen({super.key, this.patientId});
  @override State<BookForPatientScreen> createState() => _BookForPatientScreenState();
}

class _BookForPatientScreenState extends State<BookForPatientScreen> {
  String? _selectedPatientId;
  String? _selectedDoctorId;
  String? _selectedBranchId;
  DateTime? _selectedDate;
  String? _selectedTime;

  bool _isLoadingInitial = true;
  bool _isLoadingBranches = false;
  bool _isLoadingTimes = false;
  bool _isProcessing = false;

  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _horariosDoctor = [];
  List<String> _times = [];
  List<String> _bookedTimes = [];

  @override
  void initState() {
    super.initState();
    _selectedPatientId = widget.patientId;
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final supabase = Supabase.instance.client;
      final patientsData = await supabase.from('usuarios').select('id, nombre_completo, telefono').eq('rol', 'paciente');
      final doctorsData = await supabase.from('usuarios').select('id, nombre_completo, doctores(especialidad)').eq('rol', 'doctor');

      final parsedPatients = List<Map<String, dynamic>>.from(patientsData).map((p) => {
        'id': p['id'],
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
          'id': d['id'],
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar datos iniciales: $e')));
      }
    }
  }

  Future<void> _onDoctorSelected(String? doctorId) async {
    setState(() {
      _selectedDoctorId = doctorId;
      _selectedBranchId = null;
      _selectedDate = null;
      _selectedTime = null;
      _branches = [];
      _horariosDoctor = [];
      _times = [];
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

      final List<Map<String, dynamic>> fetchedHorarios = List<Map<String, dynamic>>.from(data);
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
            _selectedBranchId = _branches[0]['id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBranches = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar sucursales: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _currentBranchHorarios {
    if (_selectedBranchId == null) return [];
    return _horariosDoctor.where((h) => h['sucursales']['id'] == _selectedBranchId).toList();
  }

  List<int> get _validSqlDays {
    return _currentBranchHorarios.map((h) => h['dia_semana'] as int).toSet().toList();
  }

  DateTime _getInitialDate(List<int> validDays) {
    if (_selectedDate != null && validDays.contains(_selectedDate!.weekday - 1)) {
      return _selectedDate!;
    }
    DateTime current = DateTime.now();
    for (int i = 0; i < 30; i++) {
      if (validDays.contains(current.weekday - 1)) {
        return current;
      }
      current = current.add(const Duration(days: 1));
    }
    return DateTime.now();
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
      _times = [];
      _isLoadingTimes = true;
    });

    final sqlDay = date.weekday - 1;
    final horario = _currentBranchHorarios.firstWhere(
      (h) => h['dia_semana'] == sqlDay,
      orElse: () => <String, dynamic>{},
    );

    if (horario.isEmpty) {
      if (mounted) setState(() => _isLoadingTimes = false);
      return;
    }

    final inicioParts = horario['hora_inicio'].toString().split(':');
    final finParts = horario['hora_fin'].toString().split(':');

    int startHour = int.parse(inicioParts[0]);
    int endHour = int.parse(finParts[0]);

    List<String> slots = [];
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    for (int h = startHour; h < endHour; h++) {
      if (isToday && h <= now.hour) continue;
      int displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      String amPm = h >= 12 ? 'PM' : 'AM';
      slots.add('$displayHour:00 $amPm');
    }

    try {
      final supabase = Supabase.instance.client;
      final dateFormatted = DateFormat('yyyy-MM-dd').format(date);
      final data = await supabase
          .from('citas')
          .select('hora')
          .eq('doctor_id', _selectedDoctorId!)
          .eq('sucursal_id', _selectedBranchId!)
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
          _times = slots;
          _bookedTimes = booked;
          _isLoadingTimes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTimes = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar horarios: $e')));
      }
    }
  }

  Future<void> _handleBooking() async {
    if (_selectedPatientId == null || _selectedDoctorId == null || _selectedBranchId == null || _selectedDate == null || _selectedTime == null) return;

    setState(() => _isProcessing = true);

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
        'sucursal_id': _selectedBranchId,
        'fecha': dateFormatted,
        'hora': timeFormatted,
        'estado': 'programada',
      });

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita agendada exitosamente'), backgroundColor: AltheaColors.navy));
        context.go('/receptionist/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al agendar cita: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Scaffold(
        backgroundColor: AltheaColors.lightBg,
        body: Center(child: CircularProgressIndicator(color: AltheaColors.navy)),
      );
    }

    final validDays = _validSqlDays;

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(backgroundColor: AltheaColors.navy, foregroundColor: Colors.white, elevation: 0, title: const Text('Agendar para Paciente', style: TextStyle(fontWeight: FontWeight.w700)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/receptionist/dashboard'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Seleccionar Paciente'),
            _CustomDropdown(
              hint: 'Seleccionar paciente',
              items: _patients.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text('${p['name']} (${p['phone']})', style: const TextStyle(fontSize: 14, color: AltheaColors.navy)))).toList(),
              value: _selectedPatientId,
              onChanged: (v) => setState(() => _selectedPatientId = v),
            ),
            const SizedBox(height: 20),
            
            _SectionTitle('Seleccionar Doctor'),
            _CustomDropdown(
              hint: 'Seleccionar doctor',
              items: _doctors.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['display'], style: const TextStyle(fontSize: 14, color: AltheaColors.navy)))).toList(),
              value: _selectedDoctorId,
              onChanged: _onDoctorSelected,
            ),
            const SizedBox(height: 20),

            _SectionTitle('Seleccionar Sucursal'),
            if (_isLoadingBranches)
               const Center(child: CircularProgressIndicator(color: AltheaColors.navy))
            else
              _CustomDropdown(
                hint: _selectedDoctorId == null ? 'Primero selecciona un doctor' : (_branches.isEmpty ? 'Sin sucursales' : 'Seleccionar sucursal'),
                items: _branches.isEmpty ? null : _branches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['nombre'], style: const TextStyle(fontSize: 14, color: AltheaColors.navy)))).toList(),
                value: _selectedBranchId,
                onChanged: _branches.isEmpty ? null : (v) {
                  setState(() {
                    _selectedBranchId = v;
                    _selectedDate = null;
                    _selectedTime = null;
                  });
                },
              ),
            const SizedBox(height: 20),

            _SectionTitle('Fecha'),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AltheaColors.borderLight)),
              child: (_selectedBranchId == null || validDays.isEmpty)
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text('Selecciona una sucursal para ver fechas', style: TextStyle(color: AltheaColors.textSecondary))),
                    )
                  : CalendarDatePicker(
                      initialDate: _getInitialDate(validDays),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                      selectableDayPredicate: (DateTime val) {
                        return validDays.contains(val.weekday - 1);
                      },
                      onDateChanged: _onDateSelected,
                    ),
            ),
            const SizedBox(height: 20),

            _SectionTitle('Horario'),
            if (_isLoadingTimes)
              const Center(child: CircularProgressIndicator(color: AltheaColors.navy))
            else if (_selectedDate == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Selecciona una fecha para ver los horarios.', style: TextStyle(color: AltheaColors.textSecondary)),
              )
            else if (_times.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No hay horarios disponibles para esta fecha.', style: TextStyle(color: AltheaColors.textSecondary)),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: _times.map((t) {
                final isBooked = _bookedTimes.contains(t);
                final selected = _selectedTime == t;
                return GestureDetector(
                  onTap: isBooked ? null : () => setState(() => _selectedTime = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected ? const LinearGradient(colors: [AltheaColors.gold, AltheaColors.goldLight]) : null,
                      color: isBooked ? Colors.grey[200] : (selected ? null : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AltheaColors.gold : (isBooked ? Colors.grey[300]! : AltheaColors.borderLight)),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isBooked ? Colors.grey[500] : (selected ? AltheaColors.navy : AltheaColors.textSecondary),
                        decoration: isBooked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                );
              }).toList()),
            const SizedBox(height: 28),

            if (_selectedPatientId != null && _selectedDoctorId != null && _selectedBranchId != null && _selectedDate != null && _selectedTime != null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AltheaColors.navy)) : const Icon(Icons.check_rounded),
                  label: Text(_isProcessing ? 'Procesando...' : 'Confirmar Cita'),
                  style: ElevatedButton.styleFrom(backgroundColor: AltheaColors.gold, foregroundColor: AltheaColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _isProcessing ? null : _handleBooking,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AltheaColors.navy)),
    );
  }
}

class _CustomDropdown extends StatelessWidget {
  final String hint;
  final List<DropdownMenuItem<String>>? items;
  final String? value;
  final void Function(String?)? onChanged;
  const _CustomDropdown({required this.hint, required this.items, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AltheaColors.borderLight)),
      child: DropdownButton<String>(
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(hint, style: const TextStyle(color: AltheaColors.textSecondary, fontSize: 14)),
        value: value,
        items: items,
        onChanged: onChanged,
        disabledHint: Text(hint, style: const TextStyle(color: AltheaColors.textSecondary, fontSize: 14)),
      ),
    );
  }
}
