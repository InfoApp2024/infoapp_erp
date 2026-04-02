import 'package:flutter_test/flutter_test.dart';
import 'package:infoapp/pages/servicios/models/servicio_model.dart';
import 'package:infoapp/pages/servicios/models/estado_model.dart';

void main() {
  group('ServicioModel.esFinal Tests', () {
    test('esFinal devuelve true si el estado esta configurado como final', () {
      final estadoFinal = EstadoModel(
        id: 5,
        nombre: 'Completado',
        color: '#FFFFFF',
        orden: 1,
        esFinal: true,
      );

      final servicio = ServicioModel(
        id: 1,
        estadoId: 5,
        estadoNombre: 'Completado',
      );

      expect(servicio.esFinal([estadoFinal]), isTrue);
    });

    test('esFinal devuelve false si el estado no es final', () {
      final estadoPendiente = EstadoModel(
        id: 2,
        nombre: 'Pendiente',
        color: '#FFFFFF',
        orden: 1,
        esFinal: false,
      );

      final servicio = ServicioModel(
        id: 1,
        estadoId: 2,
        estadoNombre: 'Pendiente',
      );

      expect(servicio.esFinal([estadoPendiente]), isFalse);
    });

    test('esFinal usa fallback heuristico si no hay estados y el nombre es Legalizado', () {
      final servicio = ServicioModel(
        id: 1,
        estadoNombre: 'Legalizado',
      );

      // Usar fallback heuristico con array vacio
      expect(servicio.esFinal([]), isTrue);
    });

    test('esFinal usa fallback heuristico para Finalizado', () {
      final servicio = ServicioModel(
        id: 1,
        estadoNombre: 'Finalizado Aprobado',
      );

      expect(servicio.esFinal([]), isTrue);
    });
    
    test('esFinal devuelve false si el servicio vuelve de gestion contable (ej. En Proceso)', () {
      // Cuando un servicio es devuelto, entra de nuevo a En Proceso
      final servicio = ServicioModel(
        id: 1,
        estadoNombre: 'En Proceso',
      );

      expect(servicio.esFinal([]), isFalse);
    });
  });
}
