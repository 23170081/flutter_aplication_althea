import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
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
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      final data = await supabase.from('citas').select('''
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
      ''').eq('usuario_id', user.id);

      final now = DateTime.now();
      
      List<Map<String, dynamic>> upcoming = [];
      List<Map<String, dynamic>> past = [];

      for (var row in data) {
        final dateStr = row['fecha'].toString();
        final timeStr = row['hora'].toString();
        
        final dateTime = DateTime.parse('${dateStr}T$timeStr');
        
        final isPast = dateTime.isBefore(now);
        final status = isPast && row['estado'] == 'programada' ? 'completada' : row['estado'];
        
        String doctorName = 'Doctor';
        String specialty = 'Especialidad';
        String branchName = 'Sucursal';
        
        if (row['sucursales'] != null) {
          branchName = row['sucursales']['nombre'] ?? 'Sucursal';
        }
        
        if (row['doctores'] != null) {
          specialty = row['doctores']['especialidad'] ?? 'Especialidad';
          if (row['doctores']['usuarios'] != null) {
            doctorName = row['doctores']['usuarios']['nombre_completo'] ?? 'Doctor';
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

      // Sort upcoming: soonest first
      upcoming.sort((a, b) => (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));
      
      // Sort past: most recent first
      past.sort((a, b) => (b['dateTime'] as DateTime).compareTo(a['dateTime'] as DateTime));

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar citas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAppointments = [..._upcomingAppointments, ..._pastAppointments];

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AltheaColors.navy, AltheaColors.navyMid, AltheaColors.navy]),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        toolbarHeight: 80,
        title: const Text('Mis Citas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/patient/dashboard')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AltheaColors.navy))
          : allAppointments.isEmpty
              ? const Center(
                  child: Text(
                    'No tienes citas programadas',
                    style: TextStyle(fontSize: 16, color: AltheaColors.textSecondary, fontWeight: FontWeight.w600),
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
                                      color: isCancelled ? AltheaColors.textSecondary : AltheaColors.navy, 
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(a['specialty']!, style: const TextStyle(fontSize: 14, color: AltheaColors.textSecondary, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(a['branch']!, style: const TextStyle(fontSize: 13, color: AltheaColors.navy, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[400]),
                                      const SizedBox(width: 6),
                                      Text('${a['dateFormatted']} · ${a['timeFormatted']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AltheaColors.navy)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
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
}
