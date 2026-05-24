enum RefundStatus { pending, completed, notApplicable }

enum CancellationReason { patient, doctor, receptionist }

class RefundModel {
  final String id;
  final String citaId;
  final String usuarioId;
  final double monto;
  final RefundStatus estado;
  final CancellationReason motivoCancelacion;
  final DateTime fechaSolicitud;
  final DateTime? fechaProcesamiento;
  final String? metodoPago;
  final String? referenciaPago;
  final String? referenciaReembolso;
  final String? notas;

  const RefundModel({
    required this.id,
    required this.citaId,
    required this.usuarioId,
    required this.monto,
    required this.estado,
    required this.motivoCancelacion,
    required this.fechaSolicitud,
    this.fechaProcesamiento,
    this.metodoPago,
    this.referenciaPago,
    this.referenciaReembolso,
    this.notas,
  });

  factory RefundModel.fromJson(Map<String, dynamic> json) {
    return RefundModel(
      id: json['id'] as String,
      citaId: json['cita_id'] as String,
      usuarioId: json['usuario_id'] as String,
      monto: (json['monto'] as num).toDouble(),
      estado: _parseEstado(json['estado'] as String),
      motivoCancelacion: _parseMotivo(json['motivo_cancelacion'] as String),
      fechaSolicitud: DateTime.parse(json['fecha_solicitud'] as String),
      fechaProcesamiento: json['fecha_procesamiento'] != null
          ? DateTime.parse(json['fecha_procesamiento'] as String)
          : null,
      metodoPago: json['metodo_pago'] as String?,
      referenciaPago: json['referencia_pago'] as String?,
      referenciaReembolso: json['referencia_reembolso'] as String?,
      notas: json['notas'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cita_id': citaId,
      'usuario_id': usuarioId,
      'monto': monto,
      'estado': estado.name,
      'motivo_cancelacion': motivoCancelacion.name,
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      'fecha_procesamiento': fechaProcesamiento?.toIso8601String(),
      'metodo_pago': metodoPago,
      'referencia_pago': referenciaPago,
      'referencia_reembolso': referenciaReembolso,
      'notas': notas,
    };
  }

  static RefundStatus _parseEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return RefundStatus.pending;
      case 'completado':
        return RefundStatus.completed;
      case 'no_aplicable':
        return RefundStatus.notApplicable;
      default:
        return RefundStatus.pending;
    }
  }

  static CancellationReason _parseMotivo(String motivo) {
    switch (motivo.toLowerCase()) {
      case 'paciente':
        return CancellationReason.patient;
      case 'doctor':
        return CancellationReason.doctor;
      case 'recepcionista':
        return CancellationReason.receptionist;
      default:
        return CancellationReason.patient;
    }
  }

  String get estadoDisplay {
    switch (estado) {
      case RefundStatus.pending:
        return 'Pendiente';
      case RefundStatus.completed:
        return 'Completado';
      case RefundStatus.notApplicable:
        return 'No Aplicable';
    }
  }

  String get motivoDisplay {
    switch (motivoCancelacion) {
      case CancellationReason.patient:
        return 'Cancelación por paciente';
      case CancellationReason.doctor:
        return 'Cancelación por doctor';
      case CancellationReason.receptionist:
        return 'Cancelación por recepcionista';
    }
  }

  bool get isPending => estado == RefundStatus.pending;
  bool get isCompleted => estado == RefundStatus.completed;
  bool get isNotApplicable => estado == RefundStatus.notApplicable;
}
