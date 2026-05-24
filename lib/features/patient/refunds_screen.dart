import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_althea/core/theme/app_theme.dart';
import 'package:flutter_application_althea/core/providers/user_provider.dart';
import 'package:flutter_application_althea/core/models/refund_model.dart';

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  bool _isLoading = true;
  List<RefundModel> _refunds = [];
  String _selectedFilter = 'todos';

  @override
  void initState() {
    super.initState();
    _fetchRefunds();
  }

  Future<void> _fetchRefunds() async {
    try {
      final supabase = Supabase.instance.client;
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('No autenticado');

      final data = await supabase
          .from('reembolsos')
          .select('''
        id,
        cita_id,
        usuario_id,
        monto,
        estado,
        motivo_cancelacion,
        fecha_solicitud,
        fecha_procesamiento,
        metodo_pago,
        referencia_pago,
        referencia_reembolso,
        notas,
        citas (
          fecha,
          hora,
          doctores (
            especialidad,
            usuarios (
              nombre_completo
            )
          )
        )
      ''')
          .eq('usuario_id', user.id)
          .order('fecha_solicitud', ascending: false);

      List<RefundModel> refunds = [];
      for (var row in data) {
        refunds.add(RefundModel.fromJson(row));
      }

      if (mounted) {
        setState(() {
          _refunds = refunds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<RefundModel> get _filteredRefunds {
    switch (_selectedFilter) {
      case 'pendientes':
        return _refunds.where((r) => r.isPending).toList();
      case 'completados':
        return _refunds.where((r) => r.isCompleted).toList();
      case 'no_aplicable':
        return _refunds.where((r) => r.isNotApplicable).toList();
      default:
        return _refunds;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AltheaColors.lightBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AltheaColors.navy,
                AltheaColors.navyMid,
                AltheaColors.navy,
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        toolbarHeight: 80,
        title: const Text(
          'Mis Reembolsos',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/patient/dashboard'),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterChips(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (filter) {
                      setState(() => _selectedFilter = filter);
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AltheaColors.navy,
                      ),
                    )
                  else if (_filteredRefunds.isEmpty)
                    _EmptyState(filter: _selectedFilter)
                  else
                    ..._filteredRefunds.map(
                      (refund) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _RefundCard(refund: refund),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const _FilterChips({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Todos',
            value: 'todos',
            isSelected: selectedFilter == 'todos',
            onTap: () => onFilterChanged('todos'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Pendientes',
            value: 'pendientes',
            isSelected: selectedFilter == 'pendientes',
            onTap: () => onFilterChanged('pendientes'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Completados',
            value: 'completados',
            isSelected: selectedFilter == 'completados',
            onTap: () => onFilterChanged('completados'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'No Aplicable',
            value: 'no_aplicable',
            isSelected: selectedFilter == 'no_aplicable',
            onTap: () => onFilterChanged('no_aplicable'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AltheaColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AltheaColors.navy : AltheaColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AltheaColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    String message;
    switch (filter) {
      case 'pendientes':
        message = 'No tienes reembolsos pendientes';
        break;
      case 'completados':
        message = 'No tienes reembolsos completados';
        break;
      case 'no_aplicable':
        message = 'No tienes reembolsos no aplicables';
        break;
      default:
        message = 'No tienes reembolsos registrados';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AltheaColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundCard extends StatelessWidget {
  final RefundModel refund;

  const _RefundCard({required this.refund});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AltheaColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                refund.motivoDisplay,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AltheaColors.navy,
                ),
              ),
              _StatusBadge(estado: refund.estado),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.attach_money_outlined,
                size: 16,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 6),
              Text(
                '\$${refund.monto.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AltheaColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 6),
              Text(
                'Solicitado: ${DateFormat('dd MMM yyyy, h:mm a', 'es_MX').format(refund.fechaSolicitud)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AltheaColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (refund.fechaProcesamiento != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: Colors.green[400],
                ),
                const SizedBox(width: 6),
                Text(
                  'Procesado: ${DateFormat('dd MMM yyyy, h:mm a', 'es_MX').format(refund.fechaProcesamiento!)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (refund.notas != null && refund.notas!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AltheaColors.lightCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AltheaColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      refund.notas!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AltheaColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final RefundStatus estado;

  const _StatusBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (estado) {
      case RefundStatus.pending:
        backgroundColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange;
        label = 'Pendiente';
        break;
      case RefundStatus.completed:
        backgroundColor = Colors.green.withOpacity(0.15);
        textColor = Colors.green;
        label = 'Completado';
        break;
      case RefundStatus.notApplicable:
        backgroundColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey;
        label = 'No Aplicable';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
