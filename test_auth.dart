import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://purcoywiktkmgovsaspk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1cmNveXdpa3RrbWdvdnNhc3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Mjc0MjIsImV4cCI6MjA5NDIwMzQyMn0.54r-nfnMubEszMab3r2BMASD9odv0Dpu25O_9aEDJDQ',
  );

  try {
    // Intentar login
    final authRes = await supabase.auth.signInWithPassword(
      email: 'paciente2@gmail.com',
      password: 'password123', // Common test password
    );
    print('Login success: ${authRes.user?.id}');
    
    final res = await supabase.from('notifications').select();
    print('Notifications for user: ${res.length}');
    for (var n in res) {
      print(n);
    }
  } catch(e) {
    print('Login failed with password123, trying 123456...');
    try {
      final authRes = await supabase.auth.signInWithPassword(
        email: 'paciente2@gmail.com',
        password: '123456',
      );
      print('Login success: ${authRes.user?.id}');
      final res = await supabase.from('notifications').select();
      print('Notifications for user: ${res.length}');
      for (var n in res) {
        print(n);
      }
    } catch(e2) {
      print('Error 2: $e2');
    }
  }
  
  exit(0);
}
