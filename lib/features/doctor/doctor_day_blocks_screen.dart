import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';

class DoctorDayBlocksScreen extends StatefulWidget {
  const DoctorDayBlocksScreen({super.key});

  @override
  State<DoctorDayBlocksScreen> createState() => _DoctorDayBlocksScreenState();
}

class _DoctorDayBlocksScreenState extends State<DoctorDayBlocksScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _dayBlocks = [];
  String? _doctorId;

  @override
  void initState() {
    super.initState();
    _loadDayBlocks();
  }

  Future<void> _loadDayBlocks() async {
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
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró el perfil de doctor.'),
            ),
          );
        }
        return;
      }

      _doctorId = doctorData['id'];

      final data = await supabase
          .from('bloqueos_doctor')
          .select('*')
          .eq('doctor_id', _doctorId as String)
          .order('fecha', ascending: true);

      if (mounted) {
        setState(() {
          _dayBlocks = (data as List<dynamic>).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar bloqueos: $e')),
        );
      }
    }
  }

  Future<void> _addDayBlock() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _DayBlockDialog(),
    );

    if (result != null && result.isNotEmpty && _doctorId != null) {
      try {
        final supabase = Supabase.instance.client;
        
        // Check for existing appointments in the blocked dates/times
        final affectedAppointments = await _checkAffectedAppointments(result);
        
        if (affectedAppointments.isNotEmpty) {
          // Show alert dialog with number of affected patients
          final confirmed = await _showAffectedPatientsAlert(affectedAppointments.length);
          
          if (!confirmed) {
            return; // Doctor decided not to proceed
          }
          
          // Cancel the affected appointments
          await _cancelAffectedAppointments(affectedAppointments);
        }
        
        // Insert all blocks
        final blocksToInsert = result.map((block) => {
          'doctor_id': _doctorId,
          'fecha': block['fecha'],
          'hora_inicio': block['hora_inicio'],
          'hora_fin': block['hora_fin'],
          'motivo': block['motivo'],
        }).toList();

        await supabase.from('bloqueos_doctor').insert(blocksToInsert);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${result.length} bloqueo(s) agregado(s) exitosamente.${affectedAppointments.isNotEmpty ? ' ${affectedAppointments.length} cita(s) cancelada(s).' : ''}')),
          );
          _loadDayBlocks();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al agregar bloqueos: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteDayBlock(String blockId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar Bloqueo',
          style: TextStyle(
            color: AltheaColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '¿Estás seguro de eliminar este bloqueo?',
          style: TextStyle(color: AltheaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
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
              'Eliminar',
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
        await supabase.from('bloqueos_doctor').delete().eq('id', blockId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bloqueo eliminado exitosamente.')),
          );
          _loadDayBlocks();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar bloqueo: $e')),
          );
        }
      }
    }
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final months = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
    return dateStr;
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'Todo el día';
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeStr;
  }

  Future<List<Map<String, dynamic>>> _checkAffectedAppointments(
    List<Map<String, dynamic>> blocks,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final affectedAppointments = <Map<String, dynamic>>[];

      if (_doctorId == null) return affectedAppointments;

      for (final block in blocks) {
        final fecha = block['fecha'] as String;
        final horaInicio = block['hora_inicio'] as String?;
        final horaFin = block['hora_fin'] as String?;

        // Build query for appointments on this date
        var query = supabase
            .from('citas')
            .select('*')
            .eq('doctor_id', _doctorId!)
            .eq('fecha', fecha)
            .neq('estado', 'cancelada');

        // If it's a time range block, filter by time
        if (horaInicio != null && horaFin != null) {
          // Get all appointments and filter in code since Supabase doesn't support time range filtering directly
          final appointments = await query;
          for (final appointment in appointments) {
            final appointmentTime = appointment['hora'] as String;
            if (_isTimeInRange(appointmentTime, horaInicio, horaFin)) {
              affectedAppointments.add(appointment);
            }
          }
        } else {
          // All day block - get all appointments
          final appointments = await query;
          affectedAppointments.addAll(appointments);
        }
      }

      return affectedAppointments;
    } catch (e) {
      print('Error checking affected appointments: $e');
      return [];
    }
  }

  bool _isTimeInRange(String appointmentTime, String blockStart, String blockEnd) {
    // Parse times to compare
    final apptParts = appointmentTime.split(':');
    final apptHour = int.parse(apptParts[0]);
    
    final startParts = blockStart.split(':');
    final endParts = blockEnd.split(':');
    final startHour = int.parse(startParts[0]);
    final endHour = int.parse(endParts[0]);

    return apptHour >= startHour && apptHour < endHour;
  }

  Future<bool> _showAffectedPatientsAlert(int affectedCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Advertencia',
                style: TextStyle(
                  color: AltheaColors.navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estás a punto de bloquear fechas que tienen citas programadas.',
              style: TextStyle(
                fontSize: 14,
                color: AltheaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$affectedCount cita(s) será(n) cancelada(s)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '¿Deseas continuar y cancelar estas citas?',
              style: TextStyle(
                fontSize: 14,
                color: AltheaColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: AltheaColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continuar y Cancelar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _cancelAffectedAppointments(
    List<Map<String, dynamic>> appointments,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final user = context.read<UserProvider>().user;

      for (final appointment in appointments) {
        await supabase
            .from('citas')
            .update({
              'estado': 'cancelada',
              'cancelada_por': user?.id,
              'fecha_cancelacion': DateTime.now().toIso8601String(),
            })
            .eq('id', appointment['id']);
      }
    } catch (e) {
      print('Error canceling appointments: $e');
      rethrow;
    }
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
          'Bloqueos de Día',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/doctor/dashboard'),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AltheaColors.navy),
            )
          : Column(
              children: [
                Expanded(
                  child: _dayBlocks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy_rounded,
                                size: 64,
                                color: AltheaColors.textSecondary.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No hay bloqueos configurados',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AltheaColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Agrega un nuevo bloqueo para bloquear días específicos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AltheaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _dayBlocks.length,
                          itemBuilder: (context, index) {
                            final block = _dayBlocks[index];
                            return _DayBlockCard(
                              block: block,
                              formatDate: _formatDate,
                              formatTime: _formatTime,
                              onDelete: () => _deleteDayBlock(block['id']),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addDayBlock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AltheaColors.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Agregar Nuevo Bloqueo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DayBlockCard extends StatelessWidget {
  final Map<String, dynamic> block;
  final String Function(String) formatDate;
  final String Function(String?) formatTime;
  final VoidCallback onDelete;

  const _DayBlockCard({
    required this.block,
    required this.formatDate,
    required this.formatTime,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AltheaColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AltheaColors.navy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: AltheaColors.navy,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(block['fecha']),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AltheaColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AltheaColors.gold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${formatTime(block['hora_inicio'])} - ${formatTime(block['hora_fin'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AltheaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (block['motivo'] != null && block['motivo'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      block['motivo'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: AltheaColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.red.shade400,
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBlockDialog extends StatefulWidget {
  @override
  State<_DayBlockDialog> createState() => _DayBlockDialogState();
}

class _DayBlockDialogState extends State<_DayBlockDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final TextEditingController _motivoController = TextEditingController();
  bool _isAllDay = true;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        // If end date is before start date or not set, set it to start date
        if (_endDate == null || _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona la fecha de inicio.')),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate!,
      firstDate: _startDate!,
      lastDate: _startDate!.add(const Duration(days: 31)),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null && mounted) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _endTime = picked);
    }
  }

  String _formatDateDisplay(DateTime? date) {
    if (date == null) return 'Seleccionar';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateRangeDisplay() {
    if (_startDate == null) return 'Seleccionar fechas';
    if (_endDate == null || _startDate == _endDate) {
      return _formatDateDisplay(_startDate);
    }
    final daysDiff = _endDate!.difference(_startDate!).inDays + 1;
    return '${_formatDateDisplay(_startDate)} - ${_formatDateDisplay(_endDate)} ($daysDiff días)';
  }

  String _formatTimeDisplay(TimeOfDay? time) {
    if (time == null) return 'Seleccionar';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isValid() {
    return _startDate != null && _endDate != null && (_isAllDay || (_startTime != null && _endTime != null));
  }

  List<Map<String, dynamic>> _generateDayBlocks() {
    if (_startDate == null || _endDate == null) return [];

    final blocks = <Map<String, dynamic>>[];
    var currentDate = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final endDate = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    while (!currentDate.isAfter(endDate)) {
      final fechaStr = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      
      final horaInicioStr = _isAllDay ? null : '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00';
      final horaFinStr = _isAllDay ? null : '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00';

      blocks.add({
        'fecha': fechaStr,
        'hora_inicio': horaInicioStr,
        'hora_fin': horaFinStr,
        'motivo': _motivoController.text.trim(),
      });

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return blocks;
  }

  void _submit() {
    if (!_isValid()) return;

    final blocks = _generateDayBlocks();
    Navigator.pop(context, blocks);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      title: const Text(
        'Nuevo Bloqueo de Día',
        style: TextStyle(
          color: AltheaColors.navy,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date range selection
            const Text(
              'Rango de Fechas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AltheaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inicio',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AltheaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _selectStartDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AltheaColors.lightBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _startDate != null
                                  ? AltheaColors.navy
                                  : AltheaColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: _startDate != null
                                    ? AltheaColors.navy
                                    : AltheaColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatDateDisplay(_startDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _startDate != null
                                        ? AltheaColors.navy
                                        : AltheaColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AltheaColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _selectEndDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AltheaColors.lightBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _endDate != null
                                  ? AltheaColors.navy
                                  : AltheaColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: _endDate != null
                                    ? AltheaColors.navy
                                    : AltheaColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatDateDisplay(_endDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _endDate != null
                                        ? AltheaColors.navy
                                        : AltheaColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_startDate != null && _endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _formatDateRangeDisplay(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AltheaColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // All day toggle
            Row(
              children: [
                Switch(
                  value: _isAllDay,
                  onChanged: (value) {
                    setState(() => _isAllDay = value);
                  },
                  activeColor: AltheaColors.navy,
                ),
                const Text(
                  'Bloquear todo el día',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AltheaColors.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Time range (if not all day)
            if (!_isAllDay) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hora Inicio',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AltheaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _selectStartTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AltheaColors.lightBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _startTime != null
                                    ? AltheaColors.navy
                                    : AltheaColors.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  color: _startTime != null
                                      ? AltheaColors.navy
                                      : AltheaColors.textSecondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatTimeDisplay(_startTime),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _startTime != null
                                          ? AltheaColors.navy
                                          : AltheaColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hora Fin',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AltheaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _selectEndTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: AltheaColors.lightBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _endTime != null
                                    ? AltheaColors.navy
                                    : AltheaColors.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  color: _endTime != null
                                      ? AltheaColors.navy
                                      : AltheaColors.textSecondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatTimeDisplay(_endTime),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _endTime != null
                                          ? AltheaColors.navy
                                          : AltheaColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Motivo (optional)
            const Text(
              'Motivo (opcional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AltheaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _motivoController,
              decoration: InputDecoration(
                hintText: 'Ej: Vacaciones, cita personal, etc.',
                filled: true,
                fillColor: AltheaColors.lightBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AltheaColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AltheaColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AltheaColors.navy),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              color: AltheaColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isValid() ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AltheaColors.navy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AltheaColors.borderLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Guardar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
