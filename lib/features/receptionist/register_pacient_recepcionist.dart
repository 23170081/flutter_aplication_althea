import 'package:bcrypt/bcrypt.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';

class ReceptionistRegisterPatientScreen extends StatefulWidget {
  const ReceptionistRegisterPatientScreen({super.key});

  @override
  State<ReceptionistRegisterPatientScreen> createState() =>
      _ReceptionistRegisterPatientScreenState();
}

class _ReceptionistRegisterPatientScreenState
    extends State<ReceptionistRegisterPatientScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  String? _selectedBloodType;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _curpCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final curp = _curpCtrl.text.trim();
      final birthDate = _birthDateCtrl.text.trim().split('/').reversed.join('-');
      final password = 'PacienteAlthea';

      final supabase = Supabase.instance.client;
      final existingPhone = await supabase
          .from('usuarios')
          .select('id')
          .eq('telefono', phone)
          .maybeSingle();
      if (existingPhone != null) {
        throw Exception('Este teléfono ya está registrado.');
      }

      final existingCurp = await supabase
          .from('usuarios')
          .select('id')
          .eq('curp', curp)
          .maybeSingle();
      if (existingCurp != null) {
        throw Exception('Este CURP ya está registrado.');
      }

      if (email.isNotEmpty) {
        final existingEmail = await supabase
            .from('usuarios')
            .select('id')
            .eq('correo', email)
            .maybeSingle();
        if (existingEmail != null) {
          throw Exception('Este correo ya está registrado.');
        }
      }

      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());
      await supabase.from('usuarios').insert({
        'nombre_completo': _nameCtrl.text.trim(),
        'correo': email.isEmpty ? null : email,
        'telefono': phone,
        'fecha_nacimiento': birthDate,
        'tipo_sangre': _selectedBloodType,
        'rol': 'paciente',
        'curp': curp,
        'password': hashedPassword,
        'registrado_por': 'recepcion',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paciente registrado correctamente.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      context.go('/receptionist/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AltheaColors.darkBg,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AltheaColors.gold.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AltheaColors.navyMid.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/logoAlthea.png',
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.local_hospital_rounded,
                              color: AltheaColors.gold,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALTHEA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'CONSULTORIOS',
                              style: TextStyle(
                                color: AltheaColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SlideTransition(
                      position: _slide,
                      child: FadeTransition(
                        opacity: _opacity,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 520),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                            child: Column(
                              children: [
                                const Text(
                                  'Registrar Paciente',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Completa los datos del paciente para registrar su cuenta',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 28),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      _buildField(
                                        _nameCtrl,
                                        'Nombre completo',
                                        'Juan Pérez',
                                        Icons.person_outline_rounded,
                                        validator: (_) => null,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        _emailCtrl,
                                        'Correo electrónico',
                                        'tu@correo.com',
                                        Icons.mail_outline_rounded,
                                        keyboard:
                                            TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v != null && v.isNotEmpty) {
                                            final regex = RegExp(
                                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                            );
                                            if (!regex.hasMatch(v)) {
                                              return 'Correo inválido';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        _phoneCtrl,
                                        'Teléfono',
                                        '555 123 4567',
                                        Icons.phone_outlined,
                                        keyboard: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Campo requerido';
                                          }
                                          final digitsOnly = v.replaceAll(
                                            RegExp(r'\D'),
                                            '',
                                          );
                                          if (digitsOnly.length != 10) {
                                            return 'Debe tener exactamente 10 dígitos';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        _curpCtrl,
                                        'CURP',
                                        'LOCM880412MSLPRS01',
                                        Icons.badge_outlined,
                                        keyboard: TextInputType.visiblePassword,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[A-Za-z0-9]'),
                                          ),
                                          UpperCaseTextFormatter(),
                                        ],
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Campo requerido';
                                          }
                                          final value = v.trim().toUpperCase();
                                          if (value.length != 18) {
                                            return 'Debe tener exactamente 18 caracteres';
                                          }
                                          final curpRegex = RegExp(
                                            r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[0-9A-Z]{2}$',
                                          );
                                          if (!curpRegex.hasMatch(value)) {
                                            return 'CURP inválida';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        _birthDateCtrl,
                                        'Fecha de nacimiento',
                                        'DD/MM/AAAA',
                                        Icons.cake_outlined,
                                        keyboard: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          _BirthDateTextInputFormatter(),
                                        ],
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Campo requerido';
                                          }
                                          final regex = RegExp(
                                            r'^(\d{2})/(\d{2})/(\d{4})$',
                                          );
                                          final match = regex.firstMatch(v);
                                          if (match == null) {
                                            return 'Usa el formato DD/MM/AAAA';
                                          }
                                          final day = int.tryParse(match.group(1)!);
                                          final month = int.tryParse(match.group(2)!);
                                          final year = int.tryParse(match.group(3)!);
                                          if (month == null || month < 1 || month > 12) {
                                            return 'Mes inválido';
                                          }
                                          int maxDays = 31;
                                          if ([4, 6, 9, 11].contains(month)) {
                                            maxDays = 30;
                                          } else if (month == 2) {
                                            final isLeapYear =
                                                (year! % 4 == 0 &&
                                                    year % 100 != 0) ||
                                                (year % 400 == 0);
                                            maxDays = isLeapYear ? 29 : 28;
                                          }
                                          if (day == null || day < 1 || day > maxDays) {
                                            return 'Día inválido';
                                          }
                                          final inputDate = DateTime(
                                            year!,
                                            month,
                                            day,
                                          );
                                          final today = DateTime.now();
                                          final todayDateOnly = DateTime(
                                            today.year,
                                            today.month,
                                            today.day,
                                          );
                                          if (inputDate.isAfter(todayDateOnly)) {
                                            return 'La fecha no puede ser en el futuro';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildDropdownField(),
                                      const SizedBox(height: 24),
                                      _GoldButton(
                                        label: 'Registrar Paciente',
                                        onTap: _isLoading ? () {} : _handleRegister,
                                        isLoading: _isLoading,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      border: Border(
                                        top: BorderSide(
                                          color:
                                              Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(28),
                                        bottomRight: Radius.circular(28),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap: () => context.go(
                                              '/receptionist/dashboard'),
                                          child: const Text(
                                            'Regresar al panel de recepción',
                                            style: TextStyle(
                                              color: AltheaColors.gold,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator:
              validator ?? (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(
              icon,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AltheaColors.gold,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AltheaColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AltheaColors.error),
            ),
            errorStyle: const TextStyle(color: AltheaColors.error),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de sangre',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBloodType,
          validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
          dropdownColor: AltheaColors.darkBg,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.4),
          ),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Selecciona el tipo de sangre',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(
              Icons.bloodtype_outlined,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AltheaColors.gold,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AltheaColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AltheaColors.error),
            ),
            errorStyle: const TextStyle(color: AltheaColors.error),
          ),
          items: const [
            DropdownMenuItem(value: 'A+', child: Text('A+')),
            DropdownMenuItem(value: 'A-', child: Text('A-')),
            DropdownMenuItem(value: 'B+', child: Text('B+')),
            DropdownMenuItem(value: 'B-', child: Text('B-')),
            DropdownMenuItem(value: 'O+', child: Text('O+')),
            DropdownMenuItem(value: 'O-', child: Text('O-')),
            DropdownMenuItem(value: 'AB+', child: Text('AB+')),
            DropdownMenuItem(value: 'AB-', child: Text('AB-')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedBloodType = value;
            });
          },
        ),
      ],
    );
  }
}

class _BirthDateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i == 1 || i == 3) && i != digits.length - 1) {
        buffer.write('/');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upperText = newValue.text.toUpperCase();
    return TextEditingValue(
      text: upperText,
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

class _GoldButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _GoldButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AltheaColors.gold, AltheaColors.goldLight],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AltheaColors.gold.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AltheaColors.darkBg,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: AltheaColors.darkBg,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
