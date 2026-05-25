import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_althea/core/theme/app_theme.dart';

// ─── Branch Management ────────────────────────────────────────
class BranchManagementScreen extends StatelessWidget {
  const BranchManagementScreen({super.key});
  static const _branches = [
    {'name': 'Torre Médica Norte', 'address': 'Av. Insurgentes 1234', 'doctors': '5', 'rooms': '8'},
    {'name': 'Clínica Centro', 'address': 'Blvd. Rosales 567', 'doctors': '3', 'rooms': '4'},
    {'name': 'Sucursal Sur', 'address': 'Calle Constitución 89', 'doctors': '4', 'rooms': '6'},
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(backgroundColor: AltheaColors.navy, foregroundColor: Colors.white, elevation: 0, title: const Text('Gestión de Sucursales', style: TextStyle(fontWeight: FontWeight.w700)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/admin/dashboard'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.go('/admin/add-branch'), backgroundColor: AltheaColors.gold, foregroundColor: AltheaColors.navy, icon: const Icon(Icons.add_rounded), label: const Text('Nueva Sucursal', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _branches.length,
        itemBuilder: (_, i) {
          final b = _branches[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AltheaColors.borderLight)),
              child: Row(children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AltheaColors.navy, AltheaColors.navyMid]), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.business_rounded, color: Colors.white, size: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b['name']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AltheaColors.navy)),
                  const SizedBox(height: 2),
                  Text(b['address']!, style: const TextStyle(fontSize: 12, color: AltheaColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.person_rounded, size: 13, color: Colors.grey[400]),
                    Text(' ${b['doctors']} doctores', style: const TextStyle(fontSize: 12, color: AltheaColors.textSecondary)),
                    const SizedBox(width: 12),
                    Icon(Icons.door_front_door_rounded, size: 13, color: Colors.grey[400]),
                    Text(' ${b['rooms']} consultorios', style: const TextStyle(fontSize: 12, color: AltheaColors.textSecondary)),
                  ]),
                ])),
                IconButton(icon: const Icon(Icons.edit_outlined, color: AltheaColors.gold), onPressed: () {}),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Add Doctor ──────────────────────────────────────────────
class AddDoctorScreen extends StatefulWidget {
  const AddDoctorScreen({super.key});
  @override State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}
class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(backgroundColor: AltheaColors.navy, foregroundColor: Colors.white, elevation: 0, title: const Text('Agregar Doctor', style: TextStyle(fontWeight: FontWeight.w700)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/admin/dashboard'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 90, height: 90, decoration: BoxDecoration(color: AltheaColors.gold.withOpacity(0.12), shape: BoxShape.circle), child: const Icon(Icons.person_add_rounded, color: AltheaColors.gold, size: 44))),
              const SizedBox(height: 28),
              ...[
                ['Nombre completo', 'Dr. Juan García', Icons.person_outline_rounded],
                ['Especialidad', 'Cardiología', Icons.medical_services_outlined],
                ['Consultorio', 'Consultorio 301', Icons.door_front_door_rounded],
                ['Correo electrónico', 'dr.garcia@althea.mx', Icons.mail_outline_rounded],
                ['Teléfono', '+52 667 123 4567', Icons.phone_outlined],
              ].map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AdminField(label: f[0] as String, hint: f[1] as String, icon: f[2] as IconData),
              )),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(icon: const Icon(Icons.check_rounded), label: const Text('Registrar Doctor'), style: ElevatedButton.styleFrom(backgroundColor: AltheaColors.gold, foregroundColor: AltheaColors.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: () { if (_formKey.currentState!.validate()) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor registrado'), backgroundColor: AltheaColors.navy)); context.go('/admin/dashboard'); } })),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add Branch ──────────────────────────────────────────────
class AddBranchScreen extends StatefulWidget {
  const AddBranchScreen({super.key});
  @override State<AddBranchScreen> createState() => _AddBranchScreenState();
}
class _AddBranchScreenState extends State<AddBranchScreen> {
  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(backgroundColor: AltheaColors.navy, foregroundColor: Colors.white, elevation: 0, title: const Text('Agregar Sucursal', style: TextStyle(fontWeight: FontWeight.w700)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/admin/dashboard'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 90, height: 90, decoration: BoxDecoration(color: AltheaColors.navy.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.add_business_rounded, color: AltheaColors.navy, size: 44))),
              const SizedBox(height: 28),
              ...[
                ['Nombre de la sucursal', 'Torre Médica Norte', Icons.business_rounded],
                ['Dirección', 'Av. Insurgentes 1234', Icons.location_on_outlined],
                ['Ciudad', 'Culiacán, Sinaloa', Icons.location_city_rounded],
                ['Teléfono', '+52 667 000 0000', Icons.phone_outlined],
              ].map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AdminField(label: f[0] as String, hint: f[1] as String, icon: f[2] as IconData),
              )),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(icon: const Icon(Icons.check_rounded), label: const Text('Registrar Sucursal'), style: ElevatedButton.styleFrom(backgroundColor: AltheaColors.navy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: () { if (_formKey.currentState!.validate()) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sucursal registrada'), backgroundColor: AltheaColors.navy)); context.go('/admin/dashboard'); } })),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminField extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  const _AdminField({required this.label, required this.hint, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AltheaColors.navy)),
        const SizedBox(height: 8),
        TextFormField(
          validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AltheaColors.textSecondary, fontSize: 14),
            prefixIcon: Icon(icon, color: AltheaColors.gold, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AltheaColors.borderLight)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AltheaColors.borderLight)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AltheaColors.gold, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
