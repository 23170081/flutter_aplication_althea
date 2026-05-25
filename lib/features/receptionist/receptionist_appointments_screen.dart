import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';

class ReceptionistAppointmentsScreen extends StatefulWidget {
  const ReceptionistAppointmentsScreen({super.key});

  @override
  State<ReceptionistAppointmentsScreen> createState() => _ReceptionistAppointmentsScreenState();
}

class _ReceptionistAppointmentsScreenState extends State<ReceptionistAppointmentsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('citas')
          .select('''
            id,
            fecha,
            hora,
            estado,
            metodo_pago,
            referencia_pago,
            usuarios!citas_usuario_id_fkey (nombre_completo),
            doctores (
              especialidad,
              usuarios (nombre_completo)
            ),
            sucursales (nombre)
          ''')
          .neq('estado', 'cancelada')
          .order('fecha', ascending: true)
          .order('hora', ascending: true);

      if (data is List) {
        debugPrint('Recepcionista: citas encontradas en raw query = ${data.length}');
      }
      final formattedAppointments = <Map<String, dynamic>>[];

      for (final row in data as List<dynamic>) {
        final fecha = row['fecha']?.toString();
        final hora = row['hora']?.toString();
        if (fecha == null || hora == null) continue;

        final dateTime = DateTime.parse('${fecha}T$hora');
        final patientName = row['usuarios']?['nombre_completo'] ?? 'Paciente';
        final doctorName = row['doctores']?['usuarios']?['nombre_completo'] as String? ?? 'Doctor';
        final specialty = row['doctores']?['especialidad'] ?? 'Especialidad';
        final branchName = row['sucursales']?['nombre'] ?? 'Sucursal';

        formattedAppointments.add({
          'id': row['id'],
          'patient': patientName,
          'doctor': doctorName,
          'specialty': specialty,
          'branch': branchName,
          'dateTime': dateTime,
          'dateLabel': DateFormat('dd MMM', 'es_MX').format(dateTime),
          'timeLabel': DateFormat('h:mm a', 'es_MX').format(dateTime),
          'status': row['estado'] ?? 'programada',
          'paymentMethod': row['metodo_pago'],
          'paymentReference': row['referencia_pago'],
        });
      }

      if (mounted) {
        setState(() {
          _appointments = formattedAppointments;
          _isLoading = false;
        });

        if (formattedAppointments.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se encontraron citas activas. Verifica los registros en la tabla citas y que el estado no sea cancelada.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar citas: $e')),
        );
      }
    }
  }

  Future<void> _cancelAppointment(String appointmentId) async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar al usuario.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cancelación'),
        content: const Text('¿Deseas cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('citas').update({
        'estado': 'cancelada',
        'cancelada_por': user.id,
        'fecha_cancelacion': DateTime.now().toIso8601String(),
      }).eq('id', appointmentId);

      await supabase.from('reembolsos').insert({
        'cita_id': appointmentId,
        'usuario_id': user.id,
        'monto': 0,
        'estado': 'pendiente',
        'motivo_cancelacion': 'recepcionista',
      });

      await _fetchAppointments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita cancelada exitosamente.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cancelar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAppointments = _appointments.where((appointment) {
      final patient = appointment['patient']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return patient.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        backgroundColor: AltheaColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/receptionist/dashboard'),
        ),
        title: const Text('Gestión de citas'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AltheaColors.navy))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AltheaColors.borderLight),
                    ),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search_rounded, color: AltheaColors.navy),
                        hintText: 'Buscar cita por paciente...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: AltheaColors.textSecondary.withOpacity(0.8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredAppointments.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No hay citas activas para mostrar'
                                  : 'No se encontraron citas para "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, color: AltheaColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: filteredAppointments.length,
                            itemBuilder: (context, index) {
                              final appointment = filteredAppointments[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AltheaColors.borderLight),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                appointment['patient'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: AltheaColors.navy,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                appointment['branch'],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AltheaColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AltheaColors.gold.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              appointment['status']?.toUpperCase() ?? 'PROG.',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AltheaColors.gold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        appointment['doctor'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AltheaColors.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        appointment['specialty'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AltheaColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today_rounded, size: 16, color: AltheaColors.navy),
                                              const SizedBox(width: 6),
                                              Text(
                                                appointment['dateLabel'],
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AltheaColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 20),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_rounded, size: 16, color: AltheaColors.navy),
                                              const SizedBox(width: 6),
                                              Text(
                                                appointment['timeLabel'],
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AltheaColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      ElevatedButton(
                                        onPressed: () => _cancelAppointment(appointment['id']),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AltheaColors.navy,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Cancelar cita'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
