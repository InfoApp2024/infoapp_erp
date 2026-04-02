import 'package:flutter/material.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import 'package:infoapp/pages/equipos/models/equipo_model.dart';
import 'package:infoapp/pages/servicios/models/campo_adicional_model.dart';
import 'package:infoapp/pages/servicios/services/campos_adicionales_api_service.dart';

/// Vista profesional para mostrar la información del equipo.
/// - Usa el color de branding configurado.
/// - Muestra secciones y campos adicionales solo si existen datos.
class EquipoDetailInfo extends StatefulWidget {
  final EquipoModel equipo;

  const EquipoDetailInfo({super.key, required this.equipo});

  @override
  State<EquipoDetailInfo> createState() => _EquipoDetailInfoState();
}

class _EquipoDetailInfoState extends State<EquipoDetailInfo> {
  List<CampoAdicionalModel> _camposConValores = [];
  bool _loadingCampos = false;

  @override
  void initState() {
    super.initState();
    _cargarCamposAdicionales();
  }

  Future<void> _cargarCamposAdicionales() async {
    if (widget.equipo.id == null || widget.equipo.id! <= 0) return;
    setState(() => _loadingCampos = true);
    try {
      final campos = await CamposAdicionalesApiService.obtenerCamposConValores(
        servicioId: widget.equipo.id!,
        modulo: 'Equipos',
      );

      // Filtrar solo campos con valor no vacío
      final conValor =
          campos.where((c) {
            final v = c.valor;
            if (v == null) return false;
            if (v is String) return v.trim().isNotEmpty;
            if (v is num) return true;
            if (v is bool) return true;
            // Para imagen/archivo esperamos un nombre
            return v.toString().trim().isNotEmpty;
          }).toList();

      setState(() => _camposConValores = conValor);
    } catch (e) {
      // Silencioso: si falla, no mostramos sección
    } finally {
      if (mounted) setState(() => _loadingCampos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.primaryColor;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionCard(
            context,
            titulo: 'Información del Equipo',
            icono: Icons.info_outline,
            children: [
              _buildInfoRow('Nombre', widget.equipo.nombre),
              if ((widget.equipo.marca ?? '').isNotEmpty)
                _buildInfoRow('Marca', widget.equipo.marca),
              if ((widget.equipo.modelo ?? '').isNotEmpty)
                _buildInfoRow('Modelo', widget.equipo.modelo),
              if ((widget.equipo.placa ?? '').isNotEmpty)
                _buildInfoRow('Placa', widget.equipo.placa),
              if ((widget.equipo.codigo ?? '').isNotEmpty)
                _buildInfoRow('Código', widget.equipo.codigo),
              if ((widget.equipo.nombreEmpresa ?? '').isNotEmpty)
                _buildInfoRow('Empresa', widget.equipo.nombreEmpresa),
              if ((widget.equipo.ciudad ?? '').isNotEmpty)
                _buildInfoRow('Ciudad', widget.equipo.ciudad),
              if ((widget.equipo.planta ?? '').isNotEmpty)
                _buildInfoRow('Planta', widget.equipo.planta),
              if ((widget.equipo.lineaProd ?? '').isNotEmpty)
                _buildInfoRow('Línea de Producción', widget.equipo.lineaProd),
            ],
          ),

          const SizedBox(height: 16),

          // Sección de campos adicionales (solo si hay)
          if (_loadingCampos)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: CircularProgressIndicator(color: brand),
              ),
            ),
          if (!_loadingCampos && _camposConValores.isNotEmpty)
            _buildSeccionCard(
              context,
              titulo: 'Campos Adicionales',
              icono: Icons.extension,
              children:
                  _camposConValores
                      .map((c) => _buildCampoAdicionalRow(context, c))
                      .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSeccionCard(
    BuildContext context, {
    required String titulo,
    required IconData icono,
    required List<Widget> children,
  }) {
    final brand = context.primaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brand.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    final v = (value ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '-' : v,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoAdicionalRow(BuildContext context, CampoAdicionalModel c) {
    final icono = CamposAdicionalesApiService.getIconoTipoCampo(c.tipoCampo);
    final color = CamposAdicionalesApiService.getColorTipoCampo(c.tipoCampo);
    final texto = CamposAdicionalesApiService.formatearValorParaTabla(c);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icono, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 180,
            child: Text(
              c.nombreCampo,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto.isEmpty ? '-' : texto,
              style: TextStyle(color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
