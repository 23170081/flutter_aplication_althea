import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:go_router/go_router.dart';

class MedicalRecordScreen extends StatefulWidget {
  final String patientName;
  final String? patientId;

  const MedicalRecordScreen({super.key, required this.patientName, this.patientId});

  @override
  State<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _message = '';

  Map<String, dynamic>? _patient;
  Map<String, dynamic>? _expediente;
  List<Map<String, dynamic>> _notes = [];

  final TextEditingController _motivoController = TextEditingController();
  final TextEditingController _diagnosticoController = TextEditingController();
  final TextEditingController _tratamientoController = TextEditingController();
  final TextEditingController _cedulaController = TextEditingController();
  final TextEditingController _generoController = TextEditingController();
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _alturaController = TextEditingController();
  final TextEditingController _temperaturaController = TextEditingController();
  final TextEditingController _presionController = TextEditingController();
  final TextEditingController _fcController = TextEditingController();
  final TextEditingController _frController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _diagnosticoController.dispose();
    _tratamientoController.dispose();
    _cedulaController.dispose();
    _generoController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    _temperaturaController.dispose();
    _presionController.dispose();
    _fcController.dispose();
    _frController.dispose();
    super.dispose();
  }

  Future<void> _loadRecord() async {
    if (widget.patientId == null || widget.patientId!.isEmpty) {
      setState(() {
        _message = 'Seleccione un paciente para ver o agregar un expediente.';
        _isLoading = false;
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final usuarioId = widget.patientId!;

      final patientData = await supabase
          .from('usuarios')
          .select('id, nombre_completo, fecha_nacimiento, tipo_sangre, correo, telefono')
          .eq('id', usuarioId)
          .maybeSingle();

      if (patientData == null) {
        setState(() {
          _message = 'No se encontró información del paciente.';
          _isLoading = false;
        });
        return;
      }

      final expedienteData = await supabase
          .from('expedientes_medicos')
          .select('id, numero_expediente, fecha_apertura')
          .eq('usuario_id', usuarioId)
          .maybeSingle();

      List<Map<String, dynamic>> notes = [];
      if (expedienteData != null) {
        final notasData = await supabase
            .from('notas_medicas')
            .select('''
              id,
              fecha_hora,
              motivo_consulta,
              diagnostico,
              tratamiento,
              genero,
              peso,
              altura,
              temperatura,
              presion_arterial,
              frecuencia_cardiaca,
              frecuencia_respiratoria,
              cedula_profesional,
              doctor_id
            ''')
            .eq('expediente_id', expedienteData['id'])
            .order('fecha_hora', ascending: false);

        notes = (notasData as List<dynamic>).cast<Map<String, dynamic>>();
      }

      if (mounted) {
        setState(() {
          _patient = patientData as Map<String, dynamic>;
          _expediente = expedienteData as Map<String, dynamic>?;
          _notes = notes;
          _message = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Error al cargar el expediente: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _ensureExpediente() async {
    if (_expediente != null && _expediente!['id'] != null) {
      return _expediente!['id'] as String;
    }

    final supabase = Supabase.instance.client;
    final numeroExpediente = _generateExpedienteNumber();

    final result = await supabase.from('expedientes_medicos').insert({
      'usuario_id': widget.patientId,
      'numero_expediente': numeroExpediente,
    }).select('id, numero_expediente, fecha_apertura').maybeSingle();

    if (result == null) {
      throw Exception('No se pudo crear el expediente médico.');
    }

    if (mounted) {
      setState(() {
        _expediente = Map<String, dynamic>.from(result as Map<String, dynamic>);
      });
    }

    return _expediente!['id'] as String;
  }

  String _generateExpedienteNumber() {
    final prefix = widget.patientName.isNotEmpty
        ? widget.patientName.replaceAll(RegExp(r'\s+'), '').toUpperCase().substring(
  0,
  widget.patientName.length > 6
      ? 6
      : widget.patientName.length,
)
        : 'EXP';
    return 'EXP-${prefix}-${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _saveNote() async {
    if (widget.patientId == null || widget.patientId!.isEmpty) {
      setState(() => _message = 'Debe seleccionar un paciente para guardar el expediente.');
      return;
    }

    final motivo = _motivoController.text.trim();
    final diagnostico = _diagnosticoController.text.trim();
    if (motivo.isEmpty || diagnostico.isEmpty) {
      setState(() => _message = 'El motivo y el diagnóstico son obligatorios.');
      return;
    }

    try {
      setState(() {
        _isSaving = true;
        _message = '';
      });

      final supabase = Supabase.instance.client;
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('Usuario no autenticado.');

      final doctorData = await supabase
          .from('doctores')
          .select('id')
          .eq('usuario_id', user.id)
          .maybeSingle();

      if (doctorData == null || doctorData['id'] == null) {
        throw Exception('No se encontró el perfil de doctor.');
      }

      final expedienteId = await _ensureExpediente();

      await supabase.from('notas_medicas').insert({
        'expediente_id': expedienteId,
        'doctor_id': doctorData['id'],
        'motivo_consulta': motivo,
        'diagnostico': diagnostico,
        'tratamiento': _tratamientoController.text.trim(),
        'genero': _generoController.text.trim().isEmpty ? null : _generoController.text.trim(),
        'peso': _pesoController.text.trim().isEmpty ? null : double.tryParse(_pesoController.text.trim()),
        'altura': _alturaController.text.trim().isEmpty ? null : double.tryParse(_alturaController.text.trim()),
        'temperatura': _temperaturaController.text.trim().isEmpty ? null : double.tryParse(_temperaturaController.text.trim()),
        'presion_arterial': _presionController.text.trim().isEmpty ? null : _presionController.text.trim(),
        'frecuencia_cardiaca': _fcController.text.trim().isEmpty ? null : int.tryParse(_fcController.text.trim()),
        'frecuencia_respiratoria': _frController.text.trim().isEmpty ? null : int.tryParse(_frController.text.trim()),
        'cedula_profesional': _cedulaController.text.trim().isEmpty ? null : _cedulaController.text.trim(),
      });

      if (mounted) {
        _motivoController.clear();
        _diagnosticoController.clear();
        _tratamientoController.clear();
        _cedulaController.clear();
        _generoController.clear();
        _pesoController.clear();
        _alturaController.clear();
        _temperaturaController.clear();
        _presionController.clear();
        _fcController.clear();
        _frController.clear();
        _message = 'Nota médica guardada correctamente.';
      }

      await _loadRecord();
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Error al guardar la nota médica: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String hint = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AltheaColors.navy)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AltheaColors.textSecondary),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AltheaColors.borderLight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricField(String label, TextEditingController controller, String suffix) {
    return Expanded(
      child: _buildField(
        label,
        controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        hint: suffix,
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.patientName.isEmpty ? 'Paciente' : widget.patientName;
    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        backgroundColor: AltheaColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Expediente Clínico', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
  icon: const Icon(Icons.arrow_back_rounded),
  onPressed: () {
    context.go('/doctor/patients');
  },
),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AltheaColors.navy))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.patientId == null || widget.patientId!.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AltheaColors.borderLight),
                      ),
                      child: const Text(
                        'Selecciona un paciente desde la lista de pacientes o desde una cita para ver el expediente médico.',
                        style: TextStyle(fontSize: 16, color: AltheaColors.textSecondary),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AltheaColors.navy, AltheaColors.navyMid]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text(
                                  'Expediente: ${_expediente?['numero_expediente'] ?? 'No creado'}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Apertura: ${_formatDate(_expediente?['fecha_apertura']?.toString())}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_message.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AltheaColors.gold),
                        ),
                        child: Text(
                          _message,
                          style: const TextStyle(color: AltheaColors.navy, fontSize: 14),
                        ),
                      ),
                    const Text('Historial de notas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AltheaColors.navy)),
                    const SizedBox(height: 12),
                    if (_notes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No hay notas médicas registradas para este paciente.', style: TextStyle(color: AltheaColors.textSecondary, fontSize: 14)),
                      )
                    else
                      ..._notes.map((note) => _NoteCard(note: note)).toList(),
                    const SizedBox(height: 24),
                    const Text('Agregar nueva nota', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AltheaColors.navy)),
                    const SizedBox(height: 12),
                    _buildField('Motivo de Consulta', _motivoController, maxLines: 3, hint: 'Describe el motivo principal de la visita'),
                    const SizedBox(height: 16),
                    _buildField('Diagnóstico', _diagnosticoController, maxLines: 3, hint: 'Describe el diagnóstico clínico'),
                    const SizedBox(height: 16),
                    _buildField('Tratamiento', _tratamientoController, maxLines: 3, hint: 'Describe el tratamiento prescrito'),
                    const SizedBox(height: 16),
                    _buildField('Cédula Profesional', _cedulaController, hint: 'Ej. 12345678'),
                    const SizedBox(height: 16),
                    _buildField('Género', _generoController, hint: 'Masculino / Femenino / Otro'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildMetricField('Peso (kg)', _pesoController, 'kg'),
                        const SizedBox(width: 12),
                        _buildMetricField('Altura (cm)', _alturaController, 'cm'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildMetricField('Temperatura (°C)', _temperaturaController, '°C'),
                        const SizedBox(width: 12),
                        _buildMetricField('Presión arterial', _presionController, '120/80'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildMetricField('Frecuencia cardiaca', _fcController, 'ppm'),
                        const SizedBox(width: 12),
                        _buildMetricField('Frecuencia respiratoria', _frController, 'rpm'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveNote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AltheaColors.navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Guardar Nota Médica', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;

  const _NoteCard({required this.note});

  String _formatDateTime(String? value) {
    if (value == null) return '-';
    try {
      final date = DateTime.parse(value);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AltheaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateTime(note['fecha_hora']?.toString()),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AltheaColors.gold),
              ),
              Text(
                note['cedula_profesional']?.toString() ?? 'Sin cédula',
                style: const TextStyle(fontSize: 12, color: AltheaColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Motivo', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AltheaColors.navy)),
          const SizedBox(height: 4),
          Text(note['motivo_consulta']?.toString() ?? '-', style: const TextStyle(fontSize: 14, color: AltheaColors.navy, height: 1.5)),
          const SizedBox(height: 12),
          Text('Diagnóstico', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AltheaColors.navy)),
          const SizedBox(height: 4),
          Text(note['diagnostico']?.toString() ?? '-', style: const TextStyle(fontSize: 14, color: AltheaColors.navy, height: 1.5)),
          if ((note['tratamiento']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Tratamiento', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AltheaColors.navy)),
            const SizedBox(height: 4),
            Text(note['tratamiento']?.toString() ?? '-', style: const TextStyle(fontSize: 14, color: AltheaColors.navy, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
