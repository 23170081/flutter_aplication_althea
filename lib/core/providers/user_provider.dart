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
      role: userRole,
    );

    notifyListeners();
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    _user = null;
    notifyListeners();
  }
}
