import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/features/auth/presentation/pages/login_page.dart';

class PoliciesPage extends StatefulWidget {
  final String policiesVersion;

  const PoliciesPage({super.key, required this.policiesVersion});

  @override
  State<PoliciesPage> createState() => _PoliciesPageState();
}

class _PoliciesPageState extends State<PoliciesPage> {
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _acceptData = false;
  bool _isSaving = false;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _acceptPolicies() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('policiesAccepted', true);
      await prefs.setString('policiesVersion', widget.policiesVersion);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAccept = _acceptTerms && _acceptPrivacy && _acceptData && !_isSaving;

    return Scaffold(
      appBar: AppBar(title: const Text('Políticas de uso')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Antes de continuar, por favor revisa y acepta las políticas de uso de la aplicación.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openUrl('https://example.com/terminos'),
                      icon: const Icon(Icons.description),
                      label: const Text('Términos y Condiciones'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openUrl('https://example.com/privacidad'),
                      icon: const Icon(Icons.privacy_tip),
                      label: const Text('Política de Privacidad'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  value: _acceptTerms,
                  onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                  title: const Text('Acepto los Términos y Condiciones'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _acceptPrivacy,
                  onChanged: (v) => setState(() => _acceptPrivacy = v ?? false),
                  title: const Text('Acepto la Política de Privacidad'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _acceptData,
                  onChanged: (v) => setState(() => _acceptData = v ?? false),
                  title: const Text('Autorizo el tratamiento de datos'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canAccept ? _acceptPolicies : null,
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aceptar y continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
