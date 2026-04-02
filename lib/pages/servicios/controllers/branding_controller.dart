import 'package:flutter/material.dart';
import '../models/branding_model.dart';
import '../services/branding_api_service.dart';

/// Controlador para gestionar la configuración de marca (branding) de la aplicación.
/// Carga datos como nombre de empresa, logo y colores institucionales.
class BrandingController extends ChangeNotifier {
  BrandingModel? _branding;
  bool _isLoading = false;
  String? _error;

  BrandingModel? get branding => _branding;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Carga la configuración de marca desde la API.
  Future<void> cargarBranding() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await BrandingApiService.obtenerBranding();
      if (data != null) {
        _branding = BrandingModel.fromJson(data);
      } else {
        _branding = BrandingModel.porDefecto();
      }
    } catch (e) {
      _error = 'Error al cargar el branding: $e';
      // Cargar configuración por defecto si falla la API
      _branding = BrandingModel.porDefecto();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpia la configuración cargada.
  void clear() {
    _branding = null;
    notifyListeners();
  }

  /// Limpia los mensajes de error.
  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  /// Alterna el setting de ver tiempos
  void toggleVerTiempos(bool value) {
    if (_branding != null) {
      _branding = BrandingModel(
        colorPrimario: _branding!.colorPrimario,
        colorSecundario: _branding!.colorSecundario,
        logoUrl: _branding!.logoUrl,
        nombreEmpresa: _branding!.nombreEmpresa,
        configuracionCargada: _branding!.configuracionCargada,
        verTiempos: value,
      );
      notifyListeners();
      // Nota: En una implementacin completa, aqu se llamara a la API para guardar el setting.
    }
  }
}
