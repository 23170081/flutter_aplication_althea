import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:go_router/go_router.dart';

class MedicalRecordScreen extends StatefulWidget {
  final String patientName;
  final String? patientId;
  final String from;

  const MedicalRecordScreen({super.key, required this.patientName, this.patientId, this.from = 'patients'});

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
  String? _selectedSexo;
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
        final user = context.read<UserProvider>().user;
        if (user == null) {
          throw Exception('Usuario no autenticado.');
        }

        final doctorData = await supabase
            .from('doctores')
            .select('id')
            .eq('usuario_id', user.id)
            .maybeSingle();

        if (doctorData == null || doctorData['id'] == null) {
          throw Exception('No se encontró el perfil de doctor.');
        }

        final notasData = await supabase
            .from('notas_medicas')
            .select('''
              id,
              fecha_hora,
              motivo_consulta,
              diagnostico,
              tratamiento,
              sexo,
              peso,
              altura,
              temperatura,
              presion_arterial,
              frecuencia_cardiaca,
              frecuencia_respiratoria,
              doctor_id
            ''')
            .eq('expediente_id', expedienteData['id'])
            .eq('doctor_id', doctorData['id'])
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
    final sexo = _selectedSexo;
    final peso = _pesoController.text.trim();
    final altura = _alturaController.text.trim();
    final temperatura = _temperaturaController.text.trim();
    final presion = _presionController.text.trim();
    final fc = _fcController.text.trim();
    final fr = _frController.text.trim();

    if (motivo.isEmpty || diagnostico.isEmpty) {
      setState(() => _message = 'El motivo y el diagnóstico son obligatorios.');
      return;
    }
    if (sexo == null || sexo.isEmpty) {
      setState(() => _message = 'Debe seleccionar el sexo del paciente.');
      return;
    }
    if (peso.isNotEmpty && !_isValidPeso(peso)) {
      setState(() => _message = 'Peso inválido. Ingresa un número menor a 500 kg.');
      return;
    }
    if (altura.isNotEmpty && !_isValidAltura(altura)) {
      setState(() => _message = 'Altura inválida. Ingresa un número menor a 250 cm.');
      return;
    }
    if (temperatura.isNotEmpty && !_isValidTemperatura(temperatura)) {
      setState(() => _message = 'Temperatura inválida. Ingresa un número menor a 47 °C.');
      return;
    }
    if (presion.isNotEmpty && !_isValidPresionArterial(presion)) {
      setState(() => _message = 'Presión arterial inválida. Usa el formato 120/80 con valores razonables.');
      return;
    }
    if (fc.isNotEmpty && !_isValidPpm(fc)) {
      setState(() => _message = 'Frecuencia cardiaca inválida. Ingresa un número entre 30 y 220 ppm.');
      return;
    }
    if (fr.isNotEmpty && !_isValidRpm(fr)) {
      setState(() => _message = 'Frecuencia respiratoria inválida. Ingresa un número entre 10 y 80 rpm.');
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

      final fechaHora = DateTime.now().toIso8601String();

      await supabase.from('notas_medicas').insert({
        'expediente_id': expedienteId,
        'doctor_id': doctorData['id'],
        'fecha_hora': fechaHora,
        'motivo_consulta': motivo,
        'diagnostico': diagnostico,
        'tratamiento': _tratamientoController.text.trim(),
        'sexo': sexo,
        'peso': peso.isEmpty ? null : double.tryParse(peso),
        'altura': altura.isEmpty ? null : double.tryParse(altura),
        'temperatura': temperatura.isEmpty ? null : double.tryParse(temperatura),
        'presion_arterial': presion.isEmpty ? null : presion,
        'frecuencia_cardiaca': fc.isEmpty ? null : int.tryParse(fc),
        'frecuencia_respiratoria': fr.isEmpty ? null : int.tryParse(fr),
      });

      if (mounted) {
        _motivoController.clear();
        _diagnosticoController.clear();
        _tratamientoController.clear();
        _selectedSexo = null;
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

  bool _isNumeric(String value) {
    return RegExp(r'^\d+(\.\d+)?$').hasMatch(value);
  }

  bool _isWholeNumber(String value) {
    return RegExp(r'^\d+$').hasMatch(value);
  }

  bool _isValidPeso(String value) {
    if (!_isNumeric(value)) return false;
    final parsed = double.tryParse(value);
    return parsed != null && parsed > 0 && parsed < 500;
  }

  bool _isValidAltura(String value) {
    if (!_isNumeric(value)) return false;
    final parsed = double.tryParse(value);
    return parsed != null && parsed > 0 && parsed < 250;
  }

  bool _isValidTemperatura(String value) {
    if (!_isNumeric(value)) return false;
    final parsed = double.tryParse(value);
    return parsed != null && parsed > 0 && parsed < 47;
  }

  bool _isValidPresionArterial(String value) {
    final match = RegExp(r'^(\d{2,3})\/(\d{2,3})$').firstMatch(value);
    if (match == null) return false;
    final systolic = int.tryParse(match.group(1)!);
    final diastolic = int.tryParse(match.group(2)!);
    if (systolic == null || diastolic == null) return false;
    return systolic >= 80 && systolic <= 220 && diastolic >= 40 && diastolic <= 140 && systolic > diastolic;
  }

  bool _isValidPpm(String value) {
    if (!_isWholeNumber(value)) return false;
    final parsed = int.tryParse(value);
    return parsed != null && parsed >= 30 && parsed <= 220;
  }

  bool _isValidRpm(String value) {
    if (!_isWholeNumber(value)) return false;
    final parsed = int.tryParse(value);
    return parsed != null && parsed >= 10 && parsed <= 80;
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String hint = '',
    List<TextInputFormatter>? inputFormatters,
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
          inputFormatters: inputFormatters,
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
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
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
    if (widget.from == 'dashboard') {
      context.go('/doctor/dashboard');
    } else if (widget.from == 'schedule') {
      context.go('/doctor/schedule');
    } else {
      context.go('/doctor/patients');
    }
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sexo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AltheaColors.navy)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AltheaColors.borderLight),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            hint: const Text('Selecciona el sexo', style: TextStyle(color: AltheaColors.textSecondary)),
                            value: _selectedSexo,
                            items: const [
                              DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                              DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedSexo = value);
                            },
                          ),
                        ),
                      ],
                    ),
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
                        Expanded(
                          child: _buildField(
                            'Presión arterial',
                            _presionController,
                            keyboardType: TextInputType.text,
                            hint: '120/80',
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\/]'))],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            'Frecuencia cardiaca',
                            _fcController,
                            keyboardType: TextInputType.number,
                            hint: 'ppm',
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            'Frecuencia respiratoria',
                            _frController,
                            keyboardType: TextInputType.number,
                            hint: 'rpm',
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
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

class _NoteCard extends StatefulWidget {
  final Map<String, dynamic> note;

  const _NoteCard({required this.note});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _isExpanded = false;

  String _formatDateTime(String? value) {
    if (value == null) return '-';
    try {
      final date = DateTime.parse(value);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AltheaColors.navy)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, color: AltheaColors.navy, height: 1.5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final motivo = note['motivo_consulta']?.toString() ?? '-';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
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
                Expanded(
                  child: Text(
                    _formatDateTime(note['fecha_hora']?.toString()),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AltheaColors.gold),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AltheaColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Motivo', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AltheaColors.navy)),
            const SizedBox(height: 4),
            Text(motivo, style: const TextStyle(fontSize: 14, color: AltheaColors.navy, height: 1.5)),
            if (_isExpanded) ...[
              _infoRow('Diagnóstico', note['diagnostico']?.toString() ?? '-'),
              if ((note['tratamiento']?.toString() ?? '').isNotEmpty)
                _infoRow('Tratamiento', note['tratamiento']?.toString() ?? '-'),
              if ((note['sexo']?.toString() ?? '').isNotEmpty)
                _infoRow('Sexo', note['sexo']?.toString()),
              if ((note['peso']?.toString() ?? '').isNotEmpty)
                _infoRow('Peso', note['peso']?.toString()),
              if ((note['altura']?.toString() ?? '').isNotEmpty)
                _infoRow('Altura', note['altura']?.toString()),
              if ((note['temperatura']?.toString() ?? '').isNotEmpty)
                _infoRow('Temperatura', note['temperatura']?.toString()),
              if ((note['presion_arterial']?.toString() ?? '').isNotEmpty)
                _infoRow('Presión arterial', note['presion_arterial']?.toString()),
              if ((note['frecuencia_cardiaca']?.toString() ?? '').isNotEmpty)
                _infoRow('Frecuencia cardiaca', note['frecuencia_cardiaca']?.toString()),
              if ((note['frecuencia_respiratoria']?.toString() ?? '').isNotEmpty)
                _infoRow('Frecuencia respiratoria', note['frecuencia_respiratoria']?.toString()),
            ],
          ],
        ),
      ),
    );
  }
}
