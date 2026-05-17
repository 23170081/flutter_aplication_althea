import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://purcoywiktkmgovsaspk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1cmNveXdpa3RrbWdvdnNhc3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Mjc0MjIsImV4cCI6MjA5NDIwMzQyMn0.54r-nfnMubEszMab3r2BMASD9odv0Dpu25O_9aEDJDQ',
  );

  try {
    print('Inserting test appointment...');
    final newApt = await supabase.from('citas').insert({
      'usuario_id': '546dbe63-6e9e-4d66-9e47-106969decf7e', // paciente2
      'doctor_id': '5ec50055-50f0-48a9-81a8-df405f7582a4', // Dr. Karla
      'sucursal_id': 'a1d5d7f1-d34a-46a0-9725-150ef32721a9',
      'fecha': '2026-12-31',
      'hora': '10:00:00',
      'estado': 'programada'
    }).select().single();
    
    print('Inserted: ${newApt['id']}');
    
    print('Checking notifications...');
    final notifs = await supabase.from('notifications').select();
    print('Notifications total: ${notifs.length}');
    
    print('Cancelling appointment...');
    await supabase.from('citas').update({'estado': 'cancelada'}).eq('id', newApt['id']);
    
    print('Checking notifications again...');
    final notifs2 = await supabase.from('notifications').select();
    print('Notifications total: ${notifs2.length}');
  } catch(e) {
    print('Error: $e');
  }
  
  exit(0);
}
