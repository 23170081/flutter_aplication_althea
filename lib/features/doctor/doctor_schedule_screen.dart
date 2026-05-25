import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});
  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = true;
  Set<int> _workingDays = {};
  Map<String, List<Map<String, dynamic>>> _appointmentsMap = {};
  List<Map<String, dynamic>> _appointments = [];
  String? _doctorId;
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  final ScrollController _scrollController = ScrollController();
  late DateTime _carruselStartDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _carruselStartDate = _selectedDay.subtract(const Duration(days: 15));
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      _selectedDay = date;

      final diff = date.difference(_carruselStartDate).inDays;
      if (diff < 0 || diff >= 60) {
        _carruselStartDate = DateTime(
          date.year,
          date.month,
          date.day,
        ).subtract(const Duration(days: 15));
      }

      _loadAppointmentsForSelectedDay();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDay(date);
    });
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

  Future<void> _loadInitialData() async {
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) return;

      final supabase = Supabase.instance.client;

      final doctorData = await supabase
          .from('doctores')
          .select('id')
          .eq('usuario_id', user.id)
          .maybeSingle();

      if (doctorData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _doctorId = doctorData['id'];

      final horariosData = await supabase
          .from('horarios_doctor')
          .select('dia_semana')
          .eq('doctor_id', _doctorId as String);

      final List<dynamic> horarios = horariosData as List<dynamic>;
      for (var h in horarios) {
        if (h['dia_semana'] != null) {
          _workingDays.add(h['dia_semana'] as int);
        }
      }

      // Evitar crash si initialDate no está en workingDays
      if (_workingDays.isNotEmpty &&
          !_workingDays.contains(_selectedDay.weekday - 1)) {
        for (int i = 1; i <= 7; i++) {
          final nextDay = _selectedDay.add(Duration(days: i));
          if (_workingDays.contains(nextDay.weekday - 1)) {
            _selectedDay = nextDay;
            break;
          }
        }
      }

      await _fetchAppointmentsForMonth(_currentMonth);
      final nextMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
        1,
      );
      await _fetchAppointmentsForMonth(nextMonth);

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSelectedDay(_selectedDay);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar agenda: $e')));
      }
    }
  }

  Future<void> _fetchAppointmentsForMonth(DateTime monthDate) async {
    if (_doctorId == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final firstDay = DateTime(monthDate.year, monthDate.month, 1);
      final lastDay = DateTime(monthDate.year, monthDate.month + 1, 0);

      final startDateStr =
          '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-01';
      final endDateStr =
          '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      final data = await Supabase.instance.client
          .from('citas')
          .select('''
            id,
            fecha,
            hora,
            estado,
            usuarios:usuarios!citas_usuario_id_fkey (
              id,
              nombre_completo
            ),
            sucursales (
              nombre
            )
          ''')
          .eq('doctor_id', _doctorId as String)
          .gte('fecha', startDateStr)
          .lte('fecha', endDateStr);

      final List<dynamic> citas = data as List<dynamic>;
      Map<String, List<Map<String, dynamic>>> tempMap = Map.from(
        _appointmentsMap,
      );

      for (int d = 1; d <= lastDay.day; d++) {
        final dateStr =
            '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        tempMap.remove(dateStr);
      }

      for (var c in citas) {
        final status = (c['estado'] as String?)?.toLowerCase().trim() ?? '';
        if (status == 'cancelada') continue;

        final dateStr = c['fecha'] as String;
        tempMap.putIfAbsent(dateStr, () => []);

        tempMap[dateStr]!.add({
          'id': c['id'],
          'date': dateStr,
          'time': c['hora'] as String,
          'patient': c['usuarios']?['nombre_completo'] ?? 'Paciente',
          'patientId': c['usuarios']?['id']?.toString(),
          'type': c['sucursales']?['nombre'] ?? 'Consulta',
          'isCompleted': status == 'terminada',
        });
      }

      for (var key in tempMap.keys) {
        tempMap[key]!.sort(
          (a, b) => (a['time'] as String).compareTo(b['time'] as String),
        );
      }

      if (mounted) {
        setState(() {
          _appointmentsMap = tempMap;
          _isLoading = false;
        });
        _loadAppointmentsForSelectedDay();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar citas: $e')));
      }
    }
  }

  void _loadAppointmentsForSelectedDay() {
    final dateStr =
        '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';
    setState(() {
      _appointments = _appointmentsMap[dateStr] ?? [];
    });
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancelar Cita',
          style: TextStyle(
            color: AltheaColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '¿Estás seguro de cancelar esta cita? Se le hará el reembolso completo del anticipo al paciente y se le notificará sobre cancelación.',
          style: TextStyle(color: AltheaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'No, Mantener',
              style: TextStyle(
                color: AltheaColors.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Sí, Cancelar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('citas')
            .update({'estado': 'cancelada'})
            .eq('id', appointment['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita cancelada exitosamente.')),
          );
          _fetchAppointmentsForMonth(_currentMonth);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
        }
      }
    }
  }

  Future<void> _completeAppointment(Map<String, dynamic> appointment) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Completar Cita',
          style: TextStyle(
            color: AltheaColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '¿Estás seguro de marcar esta cita como completada? Esto indicará que la consulta ha finalizado.',
          style: TextStyle(color: AltheaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'No, Mantener',
              style: TextStyle(
                color: AltheaColors.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AltheaColors.navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Sí, Completar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        final user = context.read<UserProvider>().user;
        if (user == null) throw Exception('No autenticado');

        // Obtener detalles de la cita para notificaciones
        final citaData = await supabase
            .from('citas')
            .select('''
              usuario_id,
              fecha,
              hora,
              usuarios!citas_usuario_id_fkey (
                nombre_completo
              )
            ''')
            .eq('id', appointment['id'])
            .single();

        final usuarioId = citaData['usuario_id'];
        final pacienteNombre = citaData['usuarios']?['nombre_completo'] ?? 'Paciente';
        final fecha = citaData['fecha'];
        final hora = citaData['hora'];

        // Actualizar la cita
        await supabase
            .from('citas')
            .update({'estado': 'terminada'})
            .eq('id', appointment['id']);

        // Enviar notificación al paciente
        await supabase.from('notifications').insert({
          'user_id': usuarioId,
          'title': 'Cita Completada',
          'message': 'Tu cita con el doctor ha sido marcada como completada. Fecha: $fecha, Hora: $hora',
          'type': 'cita_completada',
        });

        // Enviar notificación al doctor
        await supabase.from('notifications').insert({
          'user_id': user.id,
          'title': 'Cita Completada',
          'message': 'Has marcado la cita con $pacienteNombre como completada. Fecha: $fecha, Hora: $hora',
          'type': 'cita_completada',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita completada exitosamente.')),
          );
          _fetchAppointmentsForMonth(_currentMonth);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al completar: $e')));
        }
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final isCompleted = appointment['isCompleted'] == true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Detalles de la Cita',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AltheaColors.navy,
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AltheaColors.lightBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.person_outline,
                      'Paciente',
                      appointment['patient']!,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.medical_services_outlined,
                      'Tipo de Consulta',
                      appointment['type']!,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.access_time_rounded,
                      'Hora',
                      appointment['time']!,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  final patientName = Uri.encodeComponent(appointment['patient']!);
                  final patientId = appointment['patientId']?.toString();
                  final queryString = patientId != null ? '&patientId=${Uri.encodeComponent(patientId)}' : '';
                  context.go('/doctor/medical-record?patient=$patientName$queryString');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AltheaColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Ver Expediente Médico',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),

              if (!isCompleted) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _completeAppointment(appointment);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AltheaColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Marcar como Completada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _cancelAppointment(appointment);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Cancelar Cita',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(
                    color: AltheaColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AltheaColors.gold, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AltheaColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AltheaColors.navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalCalendar() {
    return SizedBox(
      height: 105,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: 60,
        itemBuilder: (context, index) {
          final date = _carruselStartDate.add(Duration(days: index));
          final dateStr =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

          final isSelected =
              date.year == _selectedDay.year &&
              date.month == _selectedDay.month &&
              date.day == _selectedDay.day;

          final isWorkingDay =
              _workingDays.isEmpty || _workingDays.contains(date.weekday - 1);
          final hasAppointments =
              (_appointmentsMap[dateStr]?.isNotEmpty ?? false) && isWorkingDay;

          final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
          final dayName = dayNames[date.weekday - 1];

          return GestureDetector(
            onTap: () {
              if (isWorkingDay) {
                _onDaySelected(date);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Día no laborable'),
                    duration: Duration(milliseconds: 1500),
                  ),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
              decoration: BoxDecoration(
                color: isSelected ? AltheaColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? AltheaColors.navy
                      : AltheaColors.borderLight,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AltheaColors.navy.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : (isWorkingDay
                                ? AltheaColors.textSecondary
                                : Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isWorkingDay
                                ? AltheaColors.navy
                                : Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasAppointments
                          ? (isSelected ? AltheaColors.gold : AltheaColors.navy)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridCalendar() {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );

    // weekday is 1 for Mon, 7 for Sun.
    final leadingSpaces = firstDayOfMonth.weekday - 1;
    final totalCells = leadingSpaces + lastDayOfMonth.day;

    final monthNames = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final monthName = monthNames[_currentMonth.month - 1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AltheaColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$monthName ${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AltheaColors.navy,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: AltheaColors.navy,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month - 1,
                          1,
                        );
                        _fetchAppointmentsForMonth(_currentMonth);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: AltheaColors.navy,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month + 1,
                          1,
                        );
                        _fetchAppointmentsForMonth(_currentMonth);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((day) {
              return SizedBox(
                width: 32,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AltheaColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < leadingSpaces) {
                return const SizedBox();
              }

              final dayNum = index - leadingSpaces + 1;
              final date = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNum,
              );
              final dateStr =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';

              final isSelected =
                  date.year == _selectedDay.year &&
                  date.month == _selectedDay.month &&
                  date.day == _selectedDay.day;

              final isWorkingDay =
                  _workingDays.isEmpty ||
                  _workingDays.contains(date.weekday - 1);
              final appCount = _appointmentsMap[dateStr]?.length ?? 0;

              Color cellColor;
              Color textColor = AltheaColors.navy;

              if (!isWorkingDay) {
                cellColor = Colors.grey.shade100;
                textColor = Colors.grey.shade400;
              } else if (appCount == 0) {
                cellColor = Colors.blue.shade50.withValues(alpha: 0.5);
              } else if (appCount <= 2) {
                cellColor = AltheaColors.navy.withValues(alpha: 0.3);
              } else {
                cellColor = AltheaColors.navy;
                textColor = Colors.white;
              }

              return GestureDetector(
                onTap: () {
                  if (isWorkingDay) {
                    _onDaySelected(date);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Día no laborable'),
                        duration: Duration(milliseconds: 1500),
                      ),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AltheaColors.gold
                          : (isWorkingDay
                                ? Colors.transparent
                                : Colors.grey.shade200),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: (isSelected && appCount <= 2)
                            ? AltheaColors.navy
                            : textColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.grey.shade100, 'Bloqueado'),
              const SizedBox(width: 8),
              _buildLegendItem(
                Colors.blue.shade50.withValues(alpha: 0.5),
                'Vacío',
              ),
              const SizedBox(width: 8),
              _buildLegendItem(
                AltheaColors.navy.withValues(alpha: 0.3),
                '1-2 Citas',
              ),
              const SizedBox(width: 8),
              _buildLegendItem(AltheaColors.navy, '3+ Citas'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AltheaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        backgroundColor: AltheaColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mi Agenda',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/doctor/dashboard'),
        ),
      ),
      body: _isLoading && _workingDays.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AltheaColors.navy),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vista Semanal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AltheaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildHorizontalCalendar(),
                        const SizedBox(height: 24),
                        const Text(
                          'Mapa de Calor Mensual',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AltheaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildGridCalendar(),
                        const SizedBox(height: 24),
                        const Text(
                          'Horario del Día',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AltheaColors.navy,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: AltheaColors.navy,
                              ),
                            ),
                          )
                        else if (_appointments.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No hay citas programadas para este día.',
                                style: TextStyle(
                                  color: AltheaColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _appointments.length,
                              itemBuilder: (context, index) {
                                final a = _appointments[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _AppointmentItem(
                                    appointment: a,
                                    onTap: () => _showAppointmentDetails(a),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AppointmentItem extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;

  String _formatTimeStr(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return time;
  }

  const _AppointmentItem({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCompleted = appointment['isCompleted'] == true;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AltheaColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['patient']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isCompleted
                            ? AltheaColors.textSecondary
                            : AltheaColors.navy,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      appointment['type']!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AltheaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AltheaColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeStr(appointment['time'] as String),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AltheaColors.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
