import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/shared/widgets/althea_header.dart';

class DoctorScheduleConfigScreen extends StatefulWidget {
  const DoctorScheduleConfigScreen({super.key});

  @override
  State<DoctorScheduleConfigScreen> createState() => _DoctorScheduleConfigScreenState();
}

class _DoctorScheduleConfigScreenState extends State<DoctorScheduleConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _doctorId;
  String? _selectedSucursalId;

  final Map<String, Map<int, ScheduleConfig>> _branchSchedules = {};

  List<Map<String, dynamic>> _sucursales = [];

  Map<int, ScheduleConfig> _createEmptySchedule() {
    return {
      0: ScheduleConfig(enabled: false, startTime: '09:00', endTime: '17:00'),
      1: ScheduleConfig(enabled: false, startTime: '09:00', endTime: '17:00'),
      2: ScheduleConfig(enabled: false, startTime: '09:00', endTime: '17:00'),
      3: ScheduleConfig(enabled: false, startTime: '09:00', endTime: '17:00'),
      4: ScheduleConfig(enabled: false, startTime: '09:00', endTime: '17:00'),
      5: ScheduleConfig(enabled: false, startTime: '09:00', endTime: '17:00'),
      6: ScheduleConfig(enabled: false, startTime: '09:00', endTime: '17:00'),
    };
  }

  final List<String> _dayNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) return;

      final supabase = Supabase.instance.client;

      // Obtener doctor_id
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

      // Obtener sucursales
      final sucursalesData = await supabase
          .from('sucursales')
          .select('id, nombre');
      _sucursales = List<Map<String, dynamic>>.from(sucursalesData);

      for (var sucursal in _sucursales) {
        final sucursalId = sucursal['id'] as String?;
        if (sucursalId != null) {
          _branchSchedules.putIfAbsent(sucursalId, () => _createEmptySchedule());
        }
      }

      // Obtener horarios existentes
      final horariosData = await supabase
          .from('horarios_doctor')
          .select('dia_semana, hora_inicio, hora_fin, sucursal_id')
          .eq('doctor_id', _doctorId!);

      for (var h in horariosData) {
        final dia = h['dia_semana'] as int;
        final sucursalId = h['sucursal_id'] as String?;
        if (sucursalId == null) continue;
        _branchSchedules.putIfAbsent(sucursalId, () => _createEmptySchedule());
        if (_branchSchedules[sucursalId]!.containsKey(dia)) {
          _branchSchedules[sucursalId]![dia] = ScheduleConfig(
            enabled: true,
            startTime: h['hora_inicio'].toString().substring(0, 5),
            endTime: h['hora_fin'].toString().substring(0, 5),
            sucursalId: sucursalId,
          );
        }
      }

      if (_selectedSucursalId == null && _sucursales.isNotEmpty) {
        _selectedSucursalId = _branchSchedules.keys.isNotEmpty
            ? _branchSchedules.keys.first
            : _sucursales.first['id'] as String?;
      }

      if (_selectedSucursalId != null && !_branchSchedules.containsKey(_selectedSucursalId!)) {
        _branchSchedules[_selectedSucursalId!] = _createEmptySchedule();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  Future<bool> _hasOverlapWithOtherBranches(String sucursalId) async {
    final selectedSchedule = _branchSchedules[sucursalId]!;
    for (var otherEntry in _branchSchedules.entries) {
      if (otherEntry.key == sucursalId) continue;
      final otherSchedule = otherEntry.value;
      for (var day = 0; day <= 6; day++) {
        final selected = selectedSchedule[day]!;
        final other = otherSchedule[day]!;
        if (!selected.enabled || !other.enabled) continue;
        final selectedStart = _parseTime(selected.startTime);
        final selectedEnd = _parseTime(selected.endTime);
        final otherStart = _parseTime(other.startTime);
        final otherEnd = _parseTime(other.endTime);
        if (selectedStart.isBefore(otherEnd) && otherStart.isBefore(selectedEnd)) {
          return true;
        }
      }
    }
    return false;
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':').map(int.parse).toList();
    return TimeOfDay(hour: parts[0], minute: parts[1]);
  }

  Future<void> _saveSchedules() async {
    if (_doctorId == null || _selectedSucursalId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una sucursal antes de guardar.')),
        );
      }
      return;
    }

    final selectedSchedules = _branchSchedules[_selectedSucursalId!]!;

    for (var entry in selectedSchedules.entries) {
      if (!entry.value.enabled) continue;
      if (_parseTime(entry.value.startTime).compareTo(_parseTime(entry.value.endTime)) >= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('El horario del día ${_dayNames[entry.key]} debe tener inicio antes de fin.')),
          );
        }
        return;
      }
    }

    if (await _hasOverlapWithOtherBranches(_selectedSucursalId!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El horario seleccionado se solapa con otra sucursal. Ajusta los horarios.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('horarios_doctor')
          .delete()
          .eq('doctor_id', _doctorId!)
          .eq('sucursal_id', _selectedSucursalId!);

      final horariosToInsert = <Map<String, dynamic>>[];
      for (var entry in selectedSchedules.entries) {
        if (entry.value.enabled) {
          horariosToInsert.add({
            'doctor_id': _doctorId!,
            'sucursal_id': _selectedSucursalId!,
            'dia_semana': entry.key,
            'hora_inicio': '${entry.value.startTime}:00',
            'hora_fin': '${entry.value.endTime}:00',
          });
        }
      }

      if (horariosToInsert.isNotEmpty) {
        await supabase.from('horarios_doctor').insert(horariosToInsert);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horarios guardados exitosamente.')),
        );
        context.go('/doctor/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar horarios: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectTime(int day, bool isStartTime) async {
    final branchId = _selectedSucursalId;
    if (branchId == null) return;

    final currentTime = isStartTime
        ? _branchSchedules[branchId]![day]!.startTime
        : _branchSchedules[branchId]![day]!.endTime;

    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (_selectedSucursalId != null) {
          final branchId = _selectedSucursalId!;
          final current = _branchSchedules[branchId]![day]!;
          _branchSchedules[branchId]![day] = isStartTime
              ? current.copyWith(startTime: timeStr)
              : current.copyWith(endTime: timeStr);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AltheaColors.lightBg,
        body: const Center(
          child: CircularProgressIndicator(color: AltheaColors.navy),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      body: Column(
        children: [
          AltheaHeader(
            roleLabel: 'DOCTOR',
            userName: user?.name ?? 'Doctor',
            subtitle: 'Configurar Horarios',
            bottomPadding: 30,
            onLogout: () {
              context.read<UserProvider>().logout();
              context.go('/');
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AltheaColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sucursal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AltheaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedSucursalId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: _sucursales.map((sucursal) {
                            return DropdownMenuItem<String>(
                              value: sucursal['id'] as String?,
                              child: Text(sucursal['nombre'] ?? 'Sucursal'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedSucursalId = value;
                              _branchSchedules.putIfAbsent(value, () => _createEmptySchedule());
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Schedule cards
                  ...List.generate(7, (index) {
                    final day = index;
                    final branchId = _selectedSucursalId;
                    final config = branchId != null
                        ? _branchSchedules[branchId]![day]!
                        : ScheduleConfig(enabled: false, startTime: '09:00', endTime: '17:00');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: config.enabled 
                                ? AltheaColors.navy 
                                : AltheaColors.borderLight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Switch(
                                  value: config.enabled,
                                  onChanged: (value) {
                                    setState(() {
                                      if (_selectedSucursalId != null) {
                                        _branchSchedules[_selectedSucursalId!]![day] =
                                            config.copyWith(enabled: value);
                                      }
                                    });
                                  },
                                  activeColor: AltheaColors.navy,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _dayNames[day],
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: config.enabled 
                                          ? AltheaColors.navy 
                                          : AltheaColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (config.enabled) ...[
                              const SizedBox(height: 16),
                              if (_selectedSucursalId == null) ...[
                                const Text(
                                  'Selecciona una sucursal para configurar los horarios.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AltheaColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: _TimeSelector(
                                      label: 'Inicio',
                                      time: config.startTime,
                                      onTap: () => _selectTime(day, true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TimeSelector(
                                      label: 'Fin',
                                      time: config.endTime,
                                      onTap: () => _selectTime(day, false),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSchedules,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AltheaColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Guardar Horarios',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

class ScheduleConfig {
  final bool enabled;
  final String startTime;
  final String endTime;
  final String? sucursalId;

  ScheduleConfig({
    required this.enabled,
    required this.startTime,
    required this.endTime,
    this.sucursalId,
  });

  ScheduleConfig copyWith({
    bool? enabled,
    String? startTime,
    String? endTime,
    String? sucursalId,
  }) {
    return ScheduleConfig(
      enabled: enabled ?? this.enabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      sucursalId: sucursalId ?? this.sucursalId,
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AltheaColors.lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AltheaColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AltheaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AltheaColors.navy,
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AltheaColors.navy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
