import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_application_althea/core/models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  static const String _userIdKey = 'user_id';

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;

  UserProvider() {
    _loadSession();
  }

  /// Carga la sesión desde SharedPreferences
  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);

      if (userId != null) {
        final supabase = Supabase.instance.client;
        final userData = await supabase
            .from('usuarios')
            .select(
              'id, nombre_completo, correo, telefono, fecha_nacimiento, tipo_sangre, rol, password',
            )
            .eq('id', userId)
            .maybeSingle();

        if (userData != null) {
          _setUserFromData(userData);
        }
      }
    } catch (e) {
      debugPrint('Error loading session: $e');
    }
  }

  /// Inicia sesión buscando el teléfono y verificando contraseña con bcrypt
  Future<void> login(String telefono, String password) async {
    final supabase = Supabase.instance.client;

    // 1. Buscar el usuario por teléfono en la tabla 'usuarios'
    final userData = await supabase
        .from('usuarios')
        .select(
          'id, nombre_completo, correo, telefono, fecha_nacimiento, tipo_sangre, rol, password',
        )
        .eq('telefono', telefono.trim())
        .maybeSingle();

    if (userData == null) {
      throw Exception('No se encontró ninguna cuenta con este teléfono.');
    }

    // 2. Verificar la contraseña usando bcrypt
    final storedPassword = userData['password'] as String?;
    if (storedPassword == null) {
      throw Exception('Error: Usuario sin contraseña.');
    }

    try {
      final bool passwordValid = BCrypt.checkpw(
        password,
        storedPassword,
      );

      if (!passwordValid) {
        throw Exception('Contraseña incorrecta');
      }
    } catch (_) {
      throw Exception('Error verificando contraseña');
    }

    // 3. Guardar el ID del usuario en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userData['id'].toString());

    // 4. Poblar el estado con los datos
    _setUserFromData(userData);
  }

  /// Registra un nuevo usuario directamente en la tabla usuarios
  Future<void> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    String? birthDate,
    required String bloodType,
    required String curp,
  }) async {
    final supabase = Supabase.instance.client;

    // 1. Generar correo si no existe
    final finalEmail = (email == null || email.trim().isEmpty)
        ? '${phone.trim()}@althea.com'
        : email.trim();

    // 2. Verificar si el teléfono ya existe
    final existingPhone = await supabase
        .from('usuarios')
        .select('id')
        .eq('telefono', phone.trim())
        .maybeSingle();

    if (existingPhone != null) {
      throw Exception('Este número de teléfono ya está registrado.');
    }

    // 3. Verificar si el CURP ya existe
    final existingCurp = await supabase
        .from('usuarios')
        .select('id')
        .eq('curp', curp.trim())
        .maybeSingle();

    if (existingCurp != null) {
      throw Exception('Este CURP ya está registrado.');
    }

    // 4. Generar hash de la contraseña con bcrypt
    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    // 5. Insertar usuario en la tabla usuarios
    final response = await supabase
        .from('usuarios')
        .insert({
          'nombre_completo': name.trim(),
          'correo': finalEmail,
          'telefono': phone.trim(),
          'fecha_nacimiento': birthDate?.trim(),
          'tipo_sangre': bloodType,
          'rol': 'paciente',
          'curp': curp.trim(),
          'password': hashedPassword,
          'registrado_por': 'self',
        })
        .select('id')
        .single();

    // 6. Guardar el ID en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, response['id'].toString());

    // 7. Iniciar sesión automáticamente
    await login(phone.trim(), password);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    _user = null;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? birthDate,
    String? bloodType,
  }) async {
    if (_user == null) return;

    final supabase = Supabase.instance.client;
    final newEmail = email?.trim() ?? _user!.email;
    final newPhone = phone.trim();

    // Validar teléfono duplicado si cambió
    if (newPhone != _user!.phone) {
      final existingPhone = await supabase
          .from('usuarios')
          .select('id')
          .eq('telefono', newPhone)
          .neq('id', _user!.id)
          .maybeSingle();
      if (existingPhone != null) {
        throw Exception('Este número de teléfono ya está registrado.');
      }
    }

    // Validar correo duplicado si cambió
    if (newEmail != _user!.email) {
      final existingEmail = await supabase
          .from('usuarios')
          .select('id')
          .eq('correo', newEmail)
          .neq('id', _user!.id)
          .maybeSingle();
      if (existingEmail != null) {
        throw Exception('Este correo ya está registrado.');
      }
    }

    await supabase
        .from('usuarios')
        .update({
          'nombre_completo': name.trim(),
          'correo': newEmail,
          'telefono': newPhone,
          'fecha_nacimiento': birthDate?.trim(),
          'tipo_sangre': bloodType?.trim(),
        })
        .eq('id', _user!.id);

    _user = UserModel(
      id: _user!.id,
      name: name.trim(),
      email: newEmail,
      phone: newPhone,
      birthDate: birthDate?.trim(),
      bloodType: bloodType?.trim(),
      role: _user!.role,
    );

    notifyListeners();
  }

  void _setUserFromData(Map<String, dynamic> userData) {
    UserRole userRole;
    final String rolDb = userData['rol'];
    switch (rolDb) {
      case 'admin':
        userRole = UserRole.admin;
        break;
      case 'doctor':
        userRole = UserRole.doctor;
        break;
      case 'recepcionista':
        userRole = UserRole.receptionist;
        break;
      case 'paciente':
      default:
        userRole = UserRole.patient;
        break;
    }

    _user = UserModel(
      id: userData['id'].toString(),
      name: userData['nombre_completo'],
      email: userData['correo'],
      phone: userData['telefono'],
      birthDate: userData['fecha_nacimiento'],
      bloodType: userData['tipo_sangre'],
      role: userRole,
    );

    notifyListeners();
  }
}
