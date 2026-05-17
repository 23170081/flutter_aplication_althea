import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://purcoywiktkmgovsaspk.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1cmNveXdpa3RrbWdvdnNhc3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Mjc0MjIsImV4cCI6MjA5NDIwMzQyMn0.54r-nfnMubEszMab3r2BMASD9odv0Dpu25O_9aEDJDQ',
  );

  try {
    final res = await supabase.from('notificaciones').select().limit(5);
    print('notificaciones (original table): ${res.length}');
    for (var n in res) {
      print(n);
    }
  } catch (e) {
    print('Error: $e');
  }
  
  try {
    final res = await supabase.from('notifications').select().limit(5);
    print('notifications (new table): ${res.length}');
  } catch(e) {
    print('Error notifications: $e');
  }
  
  exit(0);
}
