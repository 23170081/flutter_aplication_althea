import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchPatientScreen extends StatefulWidget {
  const SearchPatientScreen({super.key});
  @override
  State<SearchPatientScreen> createState() => _SearchPatientScreenState();
}

class _SearchPatientScreenState extends State<SearchPatientScreen> {
  String _query = '';
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('usuarios')
          .select('id, nombre_completo, telefono, tipo_sangre')
          .eq('rol', 'paciente');

      final List<dynamic> usersData = data as List<dynamic>;

      final loadedPatients = usersData.map((u) {
        return {
          'id': u['id']?.toString() ?? '',
          'name': u['nombre_completo'] ?? 'Paciente sin nombre',
          'phone': u['telefono'] ?? 'Sin teléfono',
          'blood': u['tipo_sangre'] ?? 'N/D',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _patients = loadedPatients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar pacientes')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _patients.where((p) {
      final nameMatches = p['name']!.toLowerCase().contains(
        _query.toLowerCase(),
      );
      final phoneMatches = p['phone']!.toLowerCase().contains(
        _query.toLowerCase(),
      );
      return nameMatches || phoneMatches;
    }).toList();

    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        backgroundColor: AltheaColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Buscar Paciente',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/receptionist/dashboard'),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AltheaColors.navy,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o teléfono...',
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
                : filtered.isEmpty
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
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AltheaColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AltheaColors.gold,
                                      AltheaColors.goldLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AltheaColors.navy,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['name']!,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AltheaColors.navy,
                                      ),
                                    ),
                                    Text(
                                      'Tipo de sangre: ${p['blood']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AltheaColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      p['phone']!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AltheaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    context.go('/receptionist/book-patient?patientId=${p['id']}'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AltheaColors.gold,
                                        AltheaColors.goldLight,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Agendar',
                                    style: TextStyle(
                                      color: AltheaColors.navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
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
    );
  }
}
