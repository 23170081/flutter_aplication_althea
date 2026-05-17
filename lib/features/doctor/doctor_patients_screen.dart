import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';

class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
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
      final doctorId = doctorData['id'];

      final data = await supabase
          .from('citas')
          .select('''
            fecha,
            estado,
            usuarios:usuarios!citas_usuario_id_fkey (
              id,
              nombre_completo,
              fecha_nacimiento,
              tipo_sangre
            )
          ''')
          .eq('doctor_id', doctorId);

      final List<dynamic> citas = data as List<dynamic>;

      Map<String, Map<String, dynamic>> patientsMap = {};
      final now = DateTime.now();
      final todayAtMidnight = DateTime(now.year, now.month, now.day);

      for (var c in citas) {
        final status = c['estado'] as String;
        if (status == 'cancelada') continue;

        final u = c['usuarios'];
        if (u == null || u['id'] == null) continue;

        final userId = u['id'].toString();
        final dateStr = c['fecha'] as String;
        final aptDate = DateTime.parse(dateStr);
        final aptDateAtMidnight = DateTime(
          aptDate.year,
          aptDate.month,
          aptDate.day,
        );

        if (!patientsMap.containsKey(userId)) {
          String ageStr = '-';
          if (u['fecha_nacimiento'] != null) {
            final birthDate = DateTime.parse(u['fecha_nacimiento']);
            int age = now.year - birthDate.year;
            if (now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day)) {
              age--;
            }
            ageStr = age.toString();
          }

          patientsMap[userId] = {
            'id': userId,
            'name': u['nombre_completo'] ?? 'Paciente',
            'age': ageStr,
            'blood': u['tipo_sangre'] ?? 'N/A',
            'pastApts': <DateTime>[],
            'futureApts': <DateTime>[],
          };
        }

        if (!aptDateAtMidnight.isAfter(todayAtMidnight)) {
          (patientsMap[userId]!['pastApts'] as List<DateTime>).add(aptDate);
        } else {
          (patientsMap[userId]!['futureApts'] as List<DateTime>).add(aptDate);
        }
      }

      final patientsList = patientsMap.values.toList();

      for (var p in patientsList) {
        final pastApts = p['pastApts'] as List<DateTime>;
        final futureApts = p['futureApts'] as List<DateTime>;

        if (pastApts.isNotEmpty) {
          pastApts.sort((a, b) => b.compareTo(a)); // Más reciente primero
          p['lastVisit'] = _formatDate(pastApts.first);
          p['sortDate'] = pastApts.first;
        } else if (futureApts.isNotEmpty) {
          futureApts.sort(
            (a, b) => a.compareTo(b),
          ); // Más cercana en el futuro primero
          p['lastVisit'] = 'Próxima';
          p['sortDate'] = futureApts.first;
        }
      }

      // Ordenar por fecha (las visitas pasadas más recientes primero, luego las futuras más cercanas)
      patientsList.sort(
        (a, b) =>
            (b['sortDate'] as DateTime).compareTo(a['sortDate'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _patients = patientsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hoy';
    }
    final monthNames = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filteredPatients = _patients.where((p) {
      final name = p['name']?.toString() ?? '';
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        backgroundColor: AltheaColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mis Pacientes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/doctor/dashboard'),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AltheaColors.navy,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar paciente...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withOpacity(0.5),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AltheaColors.navy),
                  )
                : filteredPatients.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron pacientes',
                      style: TextStyle(
                        fontSize: 16,
                        color: AltheaColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredPatients.length,
                    itemBuilder: (_, i) {
                      final p = filteredPatients[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => context.go(
                            '/doctor/medical-record?patient=${Uri.encodeComponent(p['name']?.toString() ?? 'Paciente')}',
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AltheaColors.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name']?.toString() ?? 'Paciente',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AltheaColors.navy,
                                        ),
                                      ),
                                      Text(
                                        '${p['age']} años · Tipo ${p['blood']}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AltheaColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Última visita: ${p['lastVisit']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AltheaColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AltheaColors.gold,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
