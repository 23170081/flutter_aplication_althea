import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://purcoywiktkmgovsaspk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1cmNveXdpa3RrbWdvdnNhc3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Mjc0MjIsImV4cCI6MjA5NDIwMzQyMn0.54r-nfnMubEszMab3r2BMASD9odv0Dpu25O_9aEDJDQ',
  );

  try {
    final citaId = 'c17ebef6-627c-4092-98b8-0a985fdca0ca';
    print('Restoring appointment...');
    await supabase.from('citas').update({'estado': 'programada'}).eq('id', citaId);
    
    print('Cancelling appointment...');
    await supabase.from('citas').update({'estado': 'cancelada'}).eq('id', citaId);
    
    print('Checking notifications...');
    final res = await supabase.from('notifications').select();
    print('Notifications: ${res.length}');
  } catch(e) {
    print('Error: $e');
  }
  
  exit(0);
}
