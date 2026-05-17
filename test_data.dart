import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://purcoywiktkmgovsaspk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1cmNveXdpa3RrbWdvdnNhc3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Mjc0MjIsImV4cCI6MjA5NDIwMzQyMn0.54r-nfnMubEszMab3r2BMASD9odv0Dpu25O_9aEDJDQ',
  );

  try {
    final citas = await supabase.from('citas').select('*, doctores(*, usuarios(*)), usuarios:usuarios!citas_usuario_id_fkey(*)').eq('estado', 'cancelada').order('fecha', ascending: false).limit(1);
    print(citas);
  } catch(e) {
    print('Error: $e');
  }
  
  exit(0);
}
