import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/accounting_models.dart';
import 'package:infoapp/core/branding/branding_service.dart';

class AccountingPreviewWidget extends StatelessWidget {
  final AccountingEntryPreviewModel preview;
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final BrandingService _brandingService = BrandingService();

  AccountingPreviewWidget({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    double totalDebito = 0;
    double totalCredito = 0;

    for (var det in preview.detalles) {
      if (det.tipo == 'DEBITO') totalDebito += det.valor;
      if (det.tipo == 'CREDITO') totalCredito += det.valor;
    }

    final isBalanced = (totalDebito - totalCredito).abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildTable(),
        const SizedBox(height: 16),
        _buildFooter(totalDebito, totalCredito, isBalanced),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ref: ${preview.referencia}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                preview.periodoAbierto
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: preview.periodoAbierto ? Colors.green : Colors.red,
            ),
          ),
          child: Row(
            children: [
              Icon(
                preview.periodoAbierto ? Icons.check_circle : Icons.lock,
                size: 16,
                color: preview.periodoAbierto ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                preview.periodoAbierto ? 'Periodo Abierto' : 'Periodo Cerrado',
                style: TextStyle(
                  color: preview.periodoAbierto ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: Text(
                    'Cuenta / Concepto',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Débito',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Crédito',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          ...preview.detalles.map((det) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              det.codigo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              det.nombre,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          det.tipo == 'DEBITO'
                              ? currencyFormat.format(det.valor)
                              : '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          det.tipo == 'CREDITO'
                              ? currencyFormat.format(det.valor)
                              : '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFooter(double totalD, double totalC, bool isBalanced) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _brandingService.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'TOTALES:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 40),
              Text(
                currencyFormat.format(totalD),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 40),
              Text(
                currencyFormat.format(totalC),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (!isBalanced)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                '⚠ Error: Partida doble descuadrada',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
