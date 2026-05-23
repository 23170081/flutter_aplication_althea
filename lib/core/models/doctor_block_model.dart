class DoctorBlockModel {
  final String id;
  final String doctorId;
  final DateTime fecha;
  final String? horaInicio;
  final String? horaFin;
  final String? motivo;

  DoctorBlockModel({
    required this.id,
    required this.doctorId,
    required this.fecha,
    this.horaInicio,
    this.horaFin,
    this.motivo,
  });

  factory DoctorBlockModel.fromJson(Map<String, dynamic> json) {
    return DoctorBlockModel(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      horaInicio: json['hora_inicio'] as String?,
      horaFin: json['hora_fin'] as String?,
      motivo: json['motivo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'fecha': fecha.toIso8601String().split('T')[0],
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
      'motivo': motivo,
    };
  }

  bool isAllDayBlock() {
    return horaInicio == null && horaFin == null;
  }

  bool isTimeSlotBlocked(String timeSlot) {
    if (isAllDayBlock()) return true;
    
    if (horaInicio == null || horaFin == null) return false;
    
    // Parse the time slot (e.g., "2:00 PM" to "14:00")
    final slotParts = timeSlot.split(' ');
    final hourStr = slotParts[0].split(':')[0];
    int slotHour = int.parse(hourStr);
    if (slotParts[1] == 'PM' && slotHour != 12) slotHour += 12;
    if (slotParts[1] == 'AM' && slotHour == 12) slotHour = 0;
    
    // Parse block times
    final startParts = horaInicio!.split(':');
    final endParts = horaFin!.split(':');
    final startHour = int.parse(startParts[0]);
    final endHour = int.parse(endParts[0]);
    
    return slotHour >= startHour && slotHour < endHour;
  }
}
