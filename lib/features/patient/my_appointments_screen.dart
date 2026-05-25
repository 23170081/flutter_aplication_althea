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
  List<Map<String, dynamic>> _allAppointments = [];
  String _selectedFilter = 'todas'; // 'todas', 'proximas', 'completadas', 'canceladas'

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

      List<Map<String, dynamic>> allAppointments = [];

      for (var row in data) {
        final dateStr = row['fecha'].toString();
        final timeStr = row['hora'].toString();

        final dateTime = DateTime.parse('${dateStr}T$timeStr');
        final estado = row['estado']?.toString() ?? 'programada';

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

        allAppointments.add({
          'id': row['id'],
          'doctor': doctorName,
          'specialty': specialty,
          'branch': branchName,
          'dateTime': dateTime,
          'dateFormatted': DateFormat('dd MMM', 'es_MX').format(dateTime),
          'timeFormatted': DateFormat('h:mm a').format(dateTime),
          'estado': estado,
        });
      }

      allAppointments.sort(
        (a, b) =>
            (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _allAppointments = allAppointments;
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

  List<Map<String, dynamic>> get _filteredAppointments {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'todas':
        return _allAppointments;
      case 'proximas':
        return _allAppointments
            .where((a) => a['estado'] == 'programada' && (a['dateTime'] as DateTime).isAfter(now))
            .toList();
      case 'completadas':
        return _allAppointments.where((a) => a['estado'] == 'terminada').toList();
      case 'canceladas':
        return _allAppointments.where((a) => a['estado'] == 'cancelada').toList();
      default:
        return _allAppointments;
    }
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'programada':
        return AltheaColors.gold;
      case 'terminada':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String estado) {
    switch (estado) {
      case 'programada':
        return 'PROGRAMADA';
      case 'terminada':
        return 'COMPLETADA';
      case 'cancelada':
        return 'CANCELADA';
      default:
        return estado.toUpperCase();
    }
  }

  Widget _buildFilterTab(String label, String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AltheaColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AltheaColors.navy : AltheaColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AltheaColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_selectedFilter) {
      case 'todas':
        return 'No tienes citas';
      case 'proximas':
        return 'No tienes citas próximas';
      case 'completadas':
        return 'No tienes citas completadas';
      case 'canceladas':
        return 'No tienes citas canceladas';
      default:
        return 'No tienes citas';
    }
  }

  @override
  Widget build(BuildContext context) {
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
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pestañas de filtrado
                    Container(
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildFilterTab('Todas', 'todas'),
                          _buildFilterTab('Próximas', 'proximas'),
                          _buildFilterTab('Completadas', 'completadas'),
                          _buildFilterTab('Canceladas', 'canceladas'),
                        ],
                      ),
                    ),
                    if (_filteredAppointments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            _getEmptyMessage(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AltheaColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredAppointments.length,
                        itemBuilder: (context, index) {
                          final a = _filteredAppointments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _AppointmentCard(
                              appointment: a,
                              onTap: () => _showAppointmentDetails(a),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    final estado = appointment['estado'] as String;
    final isCancelada = estado == 'cancelada';
    final isCompletada = estado == 'terminada';

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
              
              // Estado badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(estado).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(estado).withOpacity(0.3)),
                ),
                child: Text(
                  _getStatusLabel(estado),
                  style: TextStyle(
                    color: _getStatusColor(estado),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
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

              // Botón de cancelar cita (solo para citas programadas)
              if (!isCancelada && !isCompletada)
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

  Widget _AppointmentCard({required Map<String, dynamic> appointment, required VoidCallback onTap}) {
    final estado = appointment['estado'] as String;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                      appointment['doctor']!,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: estado == 'cancelada'
                            ? AltheaColors.textSecondary
                            : AltheaColors.navy,
                        decoration: estado == 'cancelada'
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment['specialty']!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AltheaColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment['branch']!,
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
                          '${appointment['dateFormatted']} · ${appointment['timeFormatted']}',
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
                      color: _getStatusColor(estado).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(estado),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(estado),
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
    );
  }
}
