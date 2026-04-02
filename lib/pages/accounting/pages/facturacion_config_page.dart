import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/financial_management_service.dart';

class FacturacionConfigPage extends StatefulWidget {
  const FacturacionConfigPage({super.key});

  @override
  State<FacturacionConfigPage> createState() => _FacturacionConfigPageState();
}

class _FacturacionConfigPageState extends State<FacturacionConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = FinancialManagementService.instance;

  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rangeIdController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureSecret = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _service.getFactusSettings();
      setState(() {
        _clientIdController.text = settings['factus_client_id'] ?? '';
        _clientSecretController.text = settings['factus_client_secret'] ?? '';
        _usernameController.text = settings['factus_username'] ?? '';
        _passwordController.text = settings['factus_password'] ?? '';
        _rangeIdController.text = settings['factus_numbering_range_id'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar configuración: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final settings = {
        'factus_client_id': _clientIdController.text,
        'factus_client_secret': _clientSecretController.text,
        'factus_username': _usernameController.text,
        'factus_password': _passwordController.text,
        'factus_numbering_range_id': _rangeIdController.text,
      };

      final success = await _service.saveFactusSettings(settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Configuración guardada correctamente'
                  : 'Error al guardar la configuración',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Configuración de Facturación'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (!_isSaving)
            IconButton(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save_outlined, color: Colors.green),
              tooltip: 'Guardar cambios',
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 32),
              _buildCredentialsCard(),
              const SizedBox(height: 24),
              _buildRangeCard(),
              const SizedBox(height: 40),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.info(), color: Colors.blue[700]),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Establezca las credenciales OAuth2 de Factus para habilitar la facturación electrónica legal. Use los valores de producción para que las facturas tengan validez ante la DIAN.',
              style: TextStyle(fontSize: 13, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.vpn_key_outlined, size: 20, color: Colors.indigo),
                SizedBox(width: 12),
                Text(
                  'Credenciales API (OAuth2)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _clientIdController,
              label: 'Client ID',
              icon: PhosphorIcons.identificationCard(),
              hint: 'UUID del cliente Factus',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _clientSecretController,
              label: 'Client Secret',
              icon: PhosphorIcons.lockKey(),
              isSecret: true,
              obscure: _obscureSecret,
              onToggleObscure:
                  () => setState(() => _obscureSecret = !_obscureSecret),
              hint: 'Secreto de la aplicación',
            ),
            const Divider(height: 32),
            _buildTextField(
              controller: _usernameController,
              label: 'Username (Email)',
              icon: PhosphorIcons.user(),
              hint: 'Correo electrónico de Factus',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: PhosphorIcons.password(),
              isSecret: true,
              obscure: _obscurePassword,
              onToggleObscure:
                  () => setState(() => _obscurePassword = !_obscurePassword),
              hint: 'Contraseña de la cuenta',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.format_list_numbered_outlined,
                  size: 20,
                  color: Colors.orange,
                ),
                SizedBox(width: 12),
                Text(
                  'Operación y Numeración',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _rangeIdController,
              label: 'ID Rango de Numeración',
              icon: PhosphorIcons.hash(),
              hint: 'ID del rango habilitado en Factus',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isSecret = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey[500]),
            suffixIcon:
                isSecret
                    ? IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                      ),
                      onPressed: onToggleObscure,
                    )
                    : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.indigo, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveSettings,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(
          _isSaving ? 'GUARDANDO...' : 'GUARDAR CONFIGURACIÓN',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
