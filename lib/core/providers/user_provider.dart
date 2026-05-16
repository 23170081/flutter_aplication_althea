import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_althea/core/models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Inicia sesión buscando el teléfono y comparando contraseña en Supabase
  Future<void> login(String telefono, String password) async {
    final supabase = Supabase.instance.client;

    // 1. Buscar el usuario por teléfono en la tabla 'usuarios'
    final queryData = await supabase
        .from('usuarios')
        .select('correo')
        .eq('telefono', telefono)
        .maybeSingle();

    if (queryData == null) {
      throw Exception('No se encontró ninguna cuenta con este teléfono.');
    }

    final String correo = queryData['correo'];

    // 2. Iniciar sesión en auth.users con ese correo y contraseña
    final authResponse = await supabase.auth.signInWithPassword(
      email: correo,
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception('Error al iniciar sesión.');
    }

    // 3. Obtener el perfil completo del usuario
    final userData = await supabase
        .from('usuarios')
        .select()
        .eq('id', authResponse.user!.id)
        .single();

    // 4. Mapear el rol de la base de datos a nuestro enum
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

    // 5. Poblar el estado con los datos de la base
    _user = UserModel(
      id: userData['id'],
      name: userData['nombre_completo'],
      email: userData['correo'],
      phone: userData['telefono'],
      birthDate: userData['fecha_nacimiento'], // Puede ser null
      bloodType: userData['tipo_sangre'],      // Puede ser null
      role: userRole,
    );

    notifyListeners();
  }

  /// Registra un nuevo usuario en Supabase (auth y tabla usuarios)
  Future<void> register({
    required String name,
    required String phone,
    String? email,
    required String password,
    String? birthDate,
    required String bloodType,
  }) async {
    final supabase = Supabase.instance.client;

    // 1. Generar correo si no existe
    final finalEmail = (email == null || email.trim().isEmpty)
        ? '${phone.trim()}@althea.com'
        : email.trim();

    // 2. Verificar si el teléfono ya existe en la base de datos
    final existingPhone = await supabase
        .from('usuarios')
        .select('id')
        .eq('telefono', phone.trim())
        .maybeSingle();

    if (existingPhone != null) {
      throw Exception('Este número de teléfono ya está registrado.');
    }

    // 3. Registrar en auth.users
    final authResponse = await supabase.auth.signUp(
      email: finalEmail,
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception('Error al crear la cuenta en el sistema.');
    }

    // 4. Insertar perfil en la tabla usuarios
    await supabase.from('usuarios').insert({
      'id': authResponse.user!.id,
      'nombre_completo': name.trim(),
      'correo': finalEmail,
      'telefono': phone.trim(),
      'fecha_nacimiento': birthDate?.trim(),
      'tipo_sangre': bloodType,
      'rol': 'paciente',
    });

    // 5. Iniciar sesión automáticamente
    await login(phone.trim(), password);
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _user = null;
    notifyListeners();
  }
}
