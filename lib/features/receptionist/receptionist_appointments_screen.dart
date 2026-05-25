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
  bool _hasFetchedAppointments = false;
  List<Map<String, dynamic>> _appointments = [];
  String _searchQuery = '';
  String? _errorMessage;
  String? _branchName;
  dynamic _rawReceptionistData;
  int? _rawCitasCount;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryFetchAppointments();
    });
  }

  Future<void> _tryFetchAppointments() async {
    if (_hasFetchedAppointments) return;
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    _hasFetchedAppointments = true;
    await _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) {
        throw Exception('No se pudo identificar al usuario.');
      }

      final supabase = Supabase.instance.client;
      _currentUserId = user.id;
      
      debugPrint('--- INICIO FETCH CITAS ---');
      debugPrint('Usuario actual ID: $_currentUserId');

      // 1. Obtener la sucursal asignada a la recepcionista usando el usuario_id
      final receptionistData = await supabase
          .from('recepcionistas')
          .select('sucursal_id')
          .eq('usuario_id', user.id)
          .maybeSingle();

      debugPrint('Respuesta cruda de recepcionistas: $receptionistData');
      _rawReceptionistData = receptionistData;

      String? branchId;
      if (receptionistData != null && receptionistData is Map<String, dynamic>) {
        branchId = receptionistData['sucursal_id']?.toString().trim();
      }

      debugPrint('ID de Sucursal resuelto y limpio: $branchId');

      // Si no tiene una sucursal asignada, detenemos el flujo y mostramos el error
      if (branchId == null || branchId.isEmpty) {
        debugPrint('Error: El usuario no tiene una sucursal asignada en la tabla recepcionistas.');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No se encontró la sucursal asignada a la recepcionista. Por favor configura la sucursal en la tabla recepcionistas.';
            _appointments = [];
            _rawCitasCount = 0;
          });
        }
        return;
      }

      // 2. Obtener el nombre de la sucursal para mostrarlo en la UI
      String branchName = 'Sucursal asignada';
      final branchRow = await supabase
          .from('sucursales')
          .select('nombre')
          .eq('id', branchId)
          .maybeSingle();
          
      if (branchRow != null && branchRow is Map && branchRow['nombre'] != null) {
        branchName = branchRow['nombre'].toString();
      }
      _branchName = branchName;

      // 3. Consultar las citas FILTRANDO estrictamente por el sucursal_id de la recepcionista
      debugPrint('Consultando citas filtradas por sucursal_id: $branchId');
      
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
          .eq('sucursal_id', branchId) // <-- Filtro clave corregido
          .neq('estado', 'cancelada')
          .order('fecha', ascending: true)
          .order('hora', ascending: true);

      if (data is List) {
        debugPrint('Citas encontradas para la sucursal ($branchName): ${data.length}');
        _rawCitasCount = data.length;
      }

      // 4. Mapear y formatear la lista de citas para la interfaz de Flutter
      final formattedAppointments = <Map<String, dynamic>>[];

      for (final row in data as List<dynamic>) {
        final fecha = row['fecha']?.toString();
        final hora = row['hora']?.toString();
        if (fecha == null || hora == null) continue;

        final dateTime = DateTime.parse('${fecha}T$hora');
        final patientName = row['usuarios']?['nombre_completo'] ?? 'Paciente';
        final doctorName = row['doctores']?['usuarios']?['nombre_completo'] as String? ?? 'Doctor';
        final specialty = row['doctores']?['especialidad'] ?? 'Especialidad';
        
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
          _errorMessage = formattedAppointments.isEmpty
              ? 'No se encontraron citas activas para la sucursal $branchName.'
              : null;
        });
      }
    } catch (e) {
      debugPrint('Error crítico en _fetchAppointments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar citas: $e';
        });
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
    final user = context.watch<UserProvider>().user;
    if (!_hasFetchedAppointments && user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryFetchAppointments();
      });
    }

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_branchName != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AltheaColors.borderLight),
                      ),
                      child: Text(
                        'Sucursal: $_branchName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AltheaColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage != null) ...[
                    Center(
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: AltheaColors.textSecondary),
                      ),
                    ),
                  ] else ...[
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
                ],
              ),
            ),
    );
  }
}