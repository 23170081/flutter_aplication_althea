import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _pastAppointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final supabase = Supabase.instance.client;
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('No autenticado');

      final data = await supabase
          .from('citas')
          .select('''
        id,
        fecha,
        hora,
        estado,
        doctores (
          especialidad,
          usuarios (
            nombre_completo
          )
        ),
        sucursales (
          nombre
        )
      ''')
          .eq('usuario_id', user.id);

      final now = DateTime.now();

      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      for (var row in data) {
        final dateStr = row['fecha'].toString();
        final timeStr = row['hora'].toString();

        final dateTime = DateTime.parse('${dateStr}T$timeStr');

        final isPast = dateTime.isBefore(now);
        final status = isPast && row['estado'] == 'programada'
            ? 'completada'
            : row['estado'];

        String doctorName = 'Doctor';
        String specialty = 'Especialidad';
        String branchName = 'Sucursal';

        if (row['sucursales'] != null) {
          branchName = row['sucursales']['nombre'] ?? 'Sucursal';
        }

        if (row['doctores'] != null) {
          specialty = row['doctores']['especialidad'] ?? 'Especialidad';
          if (row['doctores']['usuarios'] != null) {
            doctorName =
                row['doctores']['usuarios']['nombre_completo'] ?? 'Doctor';
          }
        }

        final Map<String, dynamic> appointment = {
          'id': row['id'],
          'doctor': doctorName,
          'specialty': specialty,
          'branch': branchName,
          'dateTime': dateTime,
          'dateFormatted': DateFormat('dd MMM', 'es_MX').format(dateTime),
          'timeFormatted': DateFormat('h:mm a').format(dateTime),
          'status': status,
        };

        if (isPast) {
          past.add(appointment);
        } else {
          upcoming.add(appointment);
        }
      }

      // Sort upcoming: soonest first, but cancelled at the bottom
      upcoming.sort((a, b) {
        final aIsCancelled = a['status'] == 'cancelada';
        final bIsCancelled = b['status'] == 'cancelada';
        if (aIsCancelled && !bIsCancelled) return 1;
        if (!aIsCancelled && bIsCancelled) return -1;
        return (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime);
      });

      // Sort past: most recent first, but cancelled at the bottom
      past.sort((a, b) {
        final aIsCancelled = a['status'] == 'cancelada';
        final bIsCancelled = b['status'] == 'cancelada';
        if (aIsCancelled && !bIsCancelled) return 1;
        if (!aIsCancelled && bIsCancelled) return -1;
        return (b['dateTime'] as DateTime).compareTo(a['dateTime'] as DateTime);
      });

      if (mounted) {
        setState(() {
          _upcomingAppointments = upcoming;
          _pastAppointments = past;
          _isLoading = false;
        });
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

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final dateTime = appointment['dateTime'] as DateTime;
    final timeDiff = dateTime.difference(DateTime.now());
    final isMoreThanOneDay = timeDiff.inHours > 24;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cancelar Cita',
          style: TextStyle(
            color: AltheaColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          isMoreThanOneDay
              ? '¿Estás seguro de cancelar esta cita? Al faltar más de un día, se te hará el reembolso del anticipo dado.'
              : '¿Estás seguro de cancelar esta cita? Al faltar menos de un día, no habrá reembolso del anticipo.',
          style: const TextStyle(color: AltheaColors.textSecondary),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Volver',
              style: TextStyle(
                color: AltheaColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
      setState(() => _isLoading = true);
      try {
        final supabase = Supabase.instance.client;
        final user = context.read<UserProvider>().user;
        if (user == null) throw Exception('No autenticado');

        // Obtener detalles de la cita
        final citaData = await supabase
            .from('citas')
            .select('metodo_pago, referencia_pago')
            .eq('id', appointment['id'])
            .single();

        final metodoPago = citaData['metodo_pago'] as String?;
        final referenciaPago = citaData['referencia_pago'] as String?;

        // Monto fijo del anticipo según casos de uso
        const montoAnticipo = 400.0;

        // Determinar estado del reembolso según las reglas de negocio
        final estadoReembolso = isMoreThanOneDay ? 'pendiente' : 'no_aplicable';
        final notas = isMoreThanOneDay
            ? 'Reembolso pendiente de procesamiento'
            : 'No aplica reembolso por cancelación con menos de 24 horas de anticipación';

        // Actualizar la cita
        await supabase
            .from('citas')
            .update({
              'estado': 'cancelada',
              'cancelada_por': user.id,
              'fecha_cancelacion': DateTime.now().toIso8601String(),
            })
            .eq('id', appointment['id']);

        // Crear registro de reembolso
        await supabase.from('reembolsos').insert({
          'cita_id': appointment['id'],
          'usuario_id': user.id,
          'monto': montoAnticipo,
          'estado': estadoReembolso,
          'motivo_cancelacion': 'paciente',
          'metodo_pago': metodoPago,
          'referencia_pago': referenciaPago,
          'notas': notas,
        });

        _fetchAppointments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMoreThanOneDay
                    ? 'Cita cancelada. Reembolso en proceso.'
                    : 'Cita cancelada. No aplica reembolso.',
              ),
              backgroundColor: isMoreThanOneDay ? Colors.green : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al cancelar: $e')));
        }
      }
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment, bool isUpcoming, bool isCancelled) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              // Header
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
              
              // Detalles
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AltheaColors.lightBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.person_outline, 'Doctor', appointment['doctor']!),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.medical_services_outlined, 'Especialidad', appointment['specialty']!),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.business_outlined, 'Sucursal', appointment['branch']!),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.calendar_today_outlined, 'Fecha', appointment['dateFormatted']!),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.access_time_rounded, 'Hora', appointment['timeFormatted']!),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botones de acción
              if (isUpcoming && !isCancelled)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Cerrar bottom sheet
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Cita Cancelada',
                    style: TextStyle(
                      color: AltheaColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(
                    color: AltheaColors.navy,
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

  @override
  Widget build(BuildContext context) {
    final allAppointments = [..._upcomingAppointments, ..._pastAppointments];

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AltheaColors.navy,
                AltheaColors.navyMid,
                AltheaColors.navy,
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        toolbarHeight: 80,
        title: const Text(
          'Mis Citas',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/patient/dashboard'),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AltheaColors.navy),
            )
          : allAppointments.isEmpty
          ? const Center(
              child: Text(
                'No tienes citas programadas',
                style: TextStyle(
                  fontSize: 16,
                  color: AltheaColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: allAppointments.length,
              itemBuilder: (_, i) {
                final a = allAppointments[i];
                final isUpcoming = _upcomingAppointments.contains(a);
                final isCancelled = a['status'] == 'cancelada';

                String badgeText = 'Próxima';
                Color badgeColor = AltheaColors.gold;

                if (isCancelled) {
                  badgeText = 'Cancelada';
                  badgeColor = Colors.red;
                } else if (!isUpcoming) {
                  badgeText = 'Completada';
                  badgeColor = Colors.green;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showAppointmentDetails(a, isUpcoming, isCancelled),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AltheaColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['doctor']!,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: isCancelled
                                          ? AltheaColors.textSecondary
                                          : AltheaColors.navy,
                                      decoration: isCancelled
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    a['specialty']!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AltheaColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    a['branch']!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AltheaColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 14,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${a['dateFormatted']} · ${a['timeFormatted']}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AltheaColors.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
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
                  ),
                );
              },
            ),
    );
  }
}
