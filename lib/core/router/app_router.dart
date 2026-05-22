import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_althea/features/auth/login_screen.dart';
import 'package:flutter_application_althea/features/auth/register_screen.dart';
import 'package:flutter_application_althea/features/patient/patient_dashboard_screen.dart';
import 'package:flutter_application_althea/features/patient/doctor_list_screen.dart';
import 'package:flutter_application_althea/features/patient/appointment_booking_screen.dart';
import 'package:flutter_application_althea/features/patient/my_appointments_screen.dart';
import 'package:flutter_application_althea/features/patient/patient_profile_screen.dart';
import 'package:flutter_application_althea/features/doctor/doctor_dashboard_screen.dart';
import 'package:flutter_application_althea/features/doctor/doctor_schedule_screen.dart';
import 'package:flutter_application_althea/features/doctor/doctor_patients_screen.dart';
import 'package:flutter_application_althea/features/doctor/doctor_day_blocks_screen.dart';
import 'package:flutter_application_althea/features/doctor/doctor_schedule_config_screen.dart';
import 'package:flutter_application_althea/features/doctor/medical_record_screen.dart';
import 'package:flutter_application_althea/features/receptionist/receptionist_dashboard_screen.dart';
import 'package:flutter_application_althea/features/receptionist/search_patient_screen.dart';
import 'package:flutter_application_althea/features/receptionist/book_for_patient_screen.dart';
import 'package:flutter_application_althea/features/admin/admin_dashboard_screen.dart';
import 'package:flutter_application_althea/features/admin/branch_management_screen.dart';
import 'package:flutter_application_althea/features/notifications/notifications_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(BuildContext context) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),

      // Patient
      GoRoute(
        path: '/patient/dashboard',
        builder: (_, _) => const PatientDashboardScreen(),
      ),
      GoRoute(
        path: '/patient/doctors',
        builder: (_, _) => const DoctorListScreen(),
      ),
      GoRoute(
        path: '/patient/book-appointment/:doctorId',
        builder: (_, state) {
          final extra = state.extra;
          Map<String, dynamic>? doctorData;
          if (extra is Map) {
            doctorData = Map<String, dynamic>.from(extra);
          }
          return AppointmentBookingScreen(
            doctorId: state.pathParameters['doctorId'] ?? '',
            doctorData: doctorData,
          );
        },
      ),
      GoRoute(
        path: '/patient/appointments',
        builder: (_, _) => const MyAppointmentsScreen(),
      ),
      GoRoute(
        path: '/patient/profile',
        builder: (_, _) => const PatientProfileScreen(),
      ),

      // Doctor
      GoRoute(
        path: '/doctor/dashboard',
        builder: (_, _) => const DoctorDashboardScreen(),
      ),
      GoRoute(
        path: '/doctor/schedule',
        builder: (_, _) => const DoctorScheduleScreen(),
      ),
      GoRoute(
        path: '/doctor/schedule-config',
        builder: (_, _) => const DoctorScheduleConfigScreen(),
      ),
      GoRoute(
        path: '/doctor/day-blocks',
        builder: (_, _) => const DoctorDayBlocksScreen(),
      ),
      GoRoute(
        path: '/doctor/patients',
        builder: (_, _) => const DoctorPatientsScreen(),
      ),
      GoRoute(
        path: '/doctor/medical-record',
        builder: (_, state) => MedicalRecordScreen(
          patientName: state.uri.queryParameters['patient'] ?? '',
        ),
      ),

      // Receptionist
      GoRoute(
        path: '/receptionist/dashboard',
        builder: (_, _) => const ReceptionistDashboardScreen(),
      ),
      GoRoute(
        path: '/receptionist/search-patient',
        builder: (_, _) => const SearchPatientScreen(),
      ),
      GoRoute(
        path: '/receptionist/book-patient',
        builder: (_, state) => BookForPatientScreen(
          patientId: state.uri.queryParameters['patientId'],
        ),
      ),

      // Admin
      GoRoute(
        path: '/admin/dashboard',
        builder: (_, _) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/branch-management',
        builder: (_, _) => const BranchManagementScreen(),
      ),
      GoRoute(
        path: '/admin/add-doctor',
        builder: (_, _) => const AddDoctorScreen(),
      ),
      GoRoute(
        path: '/admin/add-branch',
        builder: (_, _) => const AddBranchScreen(),
      ),

      // Notifications
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
    ],
  );
}
