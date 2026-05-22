import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _selectedBloodType;
  bool _showPassword = false;
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
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (!mounted) return;
    final provider = context.read<UserProvider>();

    try {
      await provider.register(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        birthDate: _birthDateCtrl.text.trim().split('/').reversed.join('-'),
        bloodType: _selectedBloodType!,
        curp: _curpCtrl.text.trim(),
      );

      if (!mounted) return;
      context.go(provider.user!.initialRoute);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e
                .toString()
                .replaceAll('Exception: ', '')
                .replaceAll('AuthException(message: ', '')
                .replaceAll(')', ''),
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
          // Bg blobs
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
                    // Logo
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
                            errorBuilder: (_, _, _) => const Icon(
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

                    // Card
                    SlideTransition(
                      position: _slide,
                      child: FadeTransition(
                        opacity: _opacity,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 420),
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
                                  'Crear Cuenta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Completa tus datos para registrarte',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
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
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        _emailCtrl,
                                        'Correo electrónico',
                                        'tu@correo.com',
                                        Icons.mail_outline_rounded,
                                        keyboard: TextInputType.emailAddress,
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
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _buildField(
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
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        _curpCtrl,
                                        'CURP',
                                        'LOCM880412MSLPRS01',
                                        Icons.badge_outlined,
                                        keyboard: TextInputType.visiblePassword,
                                        textCapitalization: TextCapitalization.characters,
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
                                          final expectedNamePart =
                                              _buildCurpNamePart(
                                            _nameCtrl.text.trim(),
                                          );
                                          if (expectedNamePart.isNotEmpty &&
                                              value.substring(0, 4) !=
                                                  expectedNamePart) {
                                            return 'Los primeros 4 caracteres de la CURP no coinciden con el nombre';
                                          }
                                          final birthDate = _birthDateCtrl.text.trim();
                                          final birthPart =
                                              _buildCurpDatePart(birthDate);
                                          if (birthPart.isNotEmpty &&
                                              value.substring(4, 10) != birthPart) {
                                            return 'La fecha en la CURP no coincide con la fecha de nacimiento';
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
                                          final day = int.tryParse(
                                            match.group(1)!,
                                          );
                                          final month = int.tryParse(
                                            match.group(2)!,
                                          );
                                          final year = int.tryParse(
                                            match.group(3)!,
                                          );

                                          if (month == null ||
                                              month < 1 ||
                                              month > 12) {
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

                                          if (day == null ||
                                              day < 1 ||
                                              day > maxDays) {
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
                                          if (inputDate.isAfter(
                                            todayDateOnly,
                                          )) {
                                            return 'La fecha no puede ser en el futuro';
                                          }

                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _buildPasswordField(),
                                      const SizedBox(height: 14),
                                      _buildDropdownField(),
                                      const SizedBox(height: 24),

                                      // Register Button
                                      _GoldButton(
                                        label: 'Crear Cuenta',
                                        onTap: _isLoading
                                            ? () {}
                                            : _handleRegister,
                                        isLoading: _isLoading,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Footer
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.white.withOpacity(0.1),
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
                                        Text(
                                          '¿Ya tienes cuenta? ',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 14,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => context.go('/'),
                                          child: const Text(
                                            'Inicia sesión aquí',
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
                    Text(
                      '© 2026 ALTHEA Consultorios.\nTodos los derechos reservados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        letterSpacing: 1.5,
                        height: 1.8,
                      ),
                    ),
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
              validator ??
              (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
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
            hintText: 'Selecciona tu tipo de sangre',
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

  String _normalizeName(String name) {
    return name
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÂÄ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÔÖ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
        .replaceAll(RegExp(r'Ñ'), 'N')
        .replaceAll(RegExp(r'[^A-Z ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _buildCurpNamePart(String fullName) {
    final normalized = _normalizeName(fullName);
    if (normalized.isEmpty) return '';
    final parts = normalized.split(' ');
    if (parts.length < 2) return '';

    final firstName = parts.first;
    final maternalSurname = parts.length > 1 ? parts.last : '';
    final paternalSurname = parts.length > 2 ? parts[parts.length - 2] : parts.last;

    final givenName = (firstName == 'JOSE' || firstName == 'MARIA') && parts.length > 2
        ? parts[1]
        : firstName;

    String firstVowel(String s) {
      for (var i = 1; i < s.length; i++) {
        if ('AEIOU'.contains(s[i])) return s[i];
      }
      return 'X';
    }

    final p1 = paternalSurname.isNotEmpty ? paternalSurname[0] : 'X';
    final p2 = paternalSurname.length > 1 ? firstVowel(paternalSurname) : 'X';
    final p3 = maternalSurname.isNotEmpty ? maternalSurname[0] : 'X';
    final p4 = givenName.isNotEmpty ? givenName[0] : 'X';

    return '$p1$p2$p3$p4';
  }

  String _buildCurpDatePart(String birthDate) {
    final regex = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
    final match = regex.firstMatch(birthDate);
    if (match == null) return '';
    final year = match.group(3)!;
    final month = match.group(2)!;
    final day = match.group(1)!;
    return '${year.substring(2)}$month$day';
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contraseña',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: !_showPassword,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Campo requerido';
            if (v.length < 8) return 'Debe tener al menos 8 caracteres';
            return null;
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withOpacity(0.4),
                size: 20,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
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
