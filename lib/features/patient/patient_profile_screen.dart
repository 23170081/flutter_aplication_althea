import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/core/models/user_model.dart';
import 'package:flutter_application_althea/core/utils/confirm_dialog.dart';

class PatientProfileScreen extends StatelessWidget {
  const PatientProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AltheaColors.navy, AltheaColors.navyMid, AltheaColors.navy]),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => context.go('/patient/dashboard'),
                      ),
                      const Expanded(
                        child: Text(
                          'Mi Perfil',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 60),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AltheaColors.navy, AltheaColors.navyMid, AltheaColors.navy]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 112, height: 112,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AltheaColors.gold, AltheaColors.goldLight])),
                      child: const Icon(Icons.person_rounded, color: AltheaColors.navy, size: 56),
                    ),
                    const SizedBox(height: 16),
                    Text(user?.name ?? 'Paciente', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(user?.email ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Información Personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AltheaColors.navy)),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.person_outline_rounded, label: 'Nombre', value: user?.name ?? ''),
                  _InfoRow(icon: Icons.mail_outline_rounded, label: 'Correo', value: user?.email ?? ''),
                  _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: user?.phone ?? 'No especificado'),
                  _InfoRow(icon: Icons.cake_outlined, label: 'Nacimiento', value: user?.birthDate ?? 'No especificada'),
                  _InfoRow(icon: Icons.bloodtype_outlined, label: 'Tipo de Sangre', value: user?.bloodType ?? 'No especificado'),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Editar Información'),
                      style: ElevatedButton.styleFrom(backgroundColor: AltheaColors.navy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () { 
                        if (user != null) {
                          showDialog(context: context, builder: (_) => _EditProfileDialog(user: user));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: const Text('Modificar Contraseña'),
                      style: ElevatedButton.styleFrom(backgroundColor: AltheaColors.gold, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () {
                        if (user != null) {
                          showDialog(context: context, builder: (_) => _ChangePasswordDialog(user: user));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Cerrar Sesión'),
                      style: ElevatedButton.styleFrom(backgroundColor: AltheaColors.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () {
                        showConfirmDialog(
                          context,
                          title: 'Cerrar Sesión',
                          message: '¿Estás seguro de cerrar sesión?',
                          confirmLabel: 'Sí, salir',
                        ).then((confirmed) {
                          if (confirmed == true) {
                            context.read<UserProvider>().logout();
                            context.go('/');
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AltheaColors.borderLight)),
      child: Row(
        children: [
          Icon(icon, color: AltheaColors.gold, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AltheaColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, color: AltheaColors.navy, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final UserModel user;
  const _EditProfileDialog({required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController birthCtrl;
  String? _selectedBloodType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.user.name);
    emailCtrl = TextEditingController(text: widget.user.email);
    phoneCtrl = TextEditingController(text: widget.user.phone);
    
    final bd = widget.user.birthDate ?? '';
    final displayBd = bd.contains('-') ? bd.split('-').reversed.join('/') : bd;
    birthCtrl = TextEditingController(text: displayBd);
    
    final validTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
    if (widget.user.bloodType != null && validTypes.contains(widget.user.bloodType)) {
      _selectedBloodType = widget.user.bloodType;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    birthCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final birthText = birthCtrl.text.trim();
      final dbBirthDate = birthText.contains('/') ? birthText.split('/').reversed.join('-') : birthText;

      await context.read<UserProvider>().updateProfile(
        name: nameCtrl.text,
        phone: phoneCtrl.text,
        email: emailCtrl.text,
        birthDate: dbBirthDate,
        bloodType: _selectedBloodType,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Información', style: TextStyle(color: AltheaColors.navy, fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl, 
                decoration: const InputDecoration(labelText: 'Nombre Completo'),
                validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              TextFormField(
                controller: emailCtrl, 
                decoration: const InputDecoration(labelText: 'Correo'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!regex.hasMatch(v)) return 'Correo inválido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: phoneCtrl, 
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo requerido';
                  final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
                  if (digitsOnly.length != 10) return 'Debe tener exactamente 10 dígitos';
                  return null;
                },
              ),
              TextFormField(
                controller: birthCtrl, 
                decoration: const InputDecoration(labelText: 'Nacimiento (DD/MM/YYYY)'),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final regex = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
                  final match = regex.firstMatch(v);
                  if (match == null) return 'Usa formato DD/MM/YYYY';
                  return null;
                },
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedBloodType,
              decoration: const InputDecoration(labelText: 'Tipo de Sangre'),
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
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: AltheaColors.textSecondary, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AltheaColors.navy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Aceptar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final UserModel user;
  const _ChangePasswordDialog({required this.user});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userData = await supabase.from('usuarios').select('password').eq('id', widget.user.id).maybeSingle();
      final storedPassword = userData?['password'] as String?;
      if (storedPassword == null) {
        throw Exception('No se encontró la cuenta o la contraseña no está disponible.');
      }

      final currentPassword = _currentPasswordCtrl.text.trim();
      if (!BCrypt.checkpw(currentPassword, storedPassword)) {
        throw Exception('La contraseña actual es incorrecta.');
      }

      final newPassword = _newPasswordCtrl.text.trim();
      final hashedPassword = BCrypt.hashpw(newPassword, BCrypt.gensalt());
      await supabase.from('usuarios').update({'password': hashedPassword}).eq('id', widget.user.id);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada correctamente.')));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modificar Contraseña', style: TextStyle(color: AltheaColors.navy, fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentPasswordCtrl,
                obscureText: !_showCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  suffixIcon: IconButton(
                    icon: Icon(_showCurrentPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa tu contraseña actual';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordCtrl,
                obscureText: !_showNewPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña nueva',
                  suffixIcon: IconButton(
                    icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa una contraseña nueva';
                  if (value.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: AltheaColors.textSecondary, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AltheaColors.navy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
