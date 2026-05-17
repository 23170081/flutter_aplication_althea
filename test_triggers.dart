import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  try {
    final response = await http.post(
      Uri.parse('https://purcoywiktkmgovsaspk.supabase.co/rest/v1/rpc/exec_sql'),
      headers: {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1cmNveXdpa3RrbWdvdnNhc3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Mjc0MjIsImV4cCI6MjA5NDIwMzQyMn0.54r-nfnMubEszMab3r2BMASD9odv0Dpu25O_9aEDJDQ',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1cmNveXdpa3RrbWdvdnNhc3BrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2Mjc0MjIsImV4cCI6MjA5NDIwMzQyMn0.54r-nfnMubEszMab3r2BMASD9odv0Dpu25O_9aEDJDQ',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': 'SELECT event_object_table, trigger_name FROM information_schema.triggers WHERE event_object_table = \'citas\';'
      })
    );
    
    if (response.statusCode != 200) {
      print('RPC failed: ${response.statusCode} ${response.body}');
      
      // Let's try to just select from a view if we can't do arbitrary SQL
    } else {
      print(response.body);
    }
  } catch(e) {
    print('Error: $e');
  }
  
  exit(0);
}
