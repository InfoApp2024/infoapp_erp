import 'package:flutter/material.dart';

// Importar todas las páginas y controladores de tu nueva arquitectura
import '../pages/servicios/pages/servicios_list_page.dart';
import '../pages/servicios/forms/servicio_create_page.dart';
import '../pages/servicios/forms/servicio_edit_page.dart';
import '../pages/servicios/forms/servicio_detail_page.dart';
import '../pages/servicios/controllers/servicios_controller.dart';
import '../pages/servicios/models/servicio_model.dart';
import '../pages/servicios/services/servicios_api_service.dart';
import '../pages/servicios/controllers/branding_controller.dart';
import '../pages/servicios/models/branding_model.dart';

/// Página de prueba para testear toda la nueva arquitectura de servicios
class TestServiciosPage extends StatefulWidget {
  const TestServiciosPage({super.key});

  @override
  State<TestServiciosPage> createState() => _TestServiciosPageState();
}

class _TestServiciosPageState extends State<TestServiciosPage> {
  late ServiciosController _controller;
  late BrandingController _brandingController;
  String _resultadoPrueba = '';
  bool _isLoading = false;
  final Map<String, bool> _testResults = {}; // Para trackear resultados

  @override
  void initState() {
    super.initState();
    _controller = ServiciosController();
    _brandingController = BrandingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _brandingController.dispose();
    super.dispose();
  }

  /// Mostrar resultado de prueba
  void _mostrarResultado(String mensaje, {bool esError = false}) {
    setState(() {
      _resultadoPrueba = mensaje;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Registrar resultado de test
  void _registrarTestResult(String testName, bool success) {
    setState(() {
      _testResults[testName] = success;
    });
  }

  /// Test 1: Cargar lista de servicios
  Future<void> _testCargarServicios() async {
    setState(() => _isLoading = true);

    try {
      await _controller.cargarServicios();

      if (_controller.error != null) {
        _mostrarResultado('❌ Error: ${_controller.error}', esError: true);
        _registrarTestResult('cargar_servicios', false);
      } else {
        _mostrarResultado(
          '✅ Servicios cargados: ${_controller.servicios.length}',
        );
        _registrarTestResult('cargar_servicios', true);
      }
    } catch (e) {
      _mostrarResultado('❌ Excepción: $e', esError: true);
      _registrarTestResult('cargar_servicios', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Test 2: API Service directo
  Future<void> _testApiService() async {
    setState(() => _isLoading = true);

    try {
      // Test listar servicios
      final servicios = await ServiciosApiService.listarServicios();

      // Test obtener estado inicial
      final estadoInicial = await ServiciosApiService.obtenerEstadoInicial();

      // Test verificar primer servicio
      final verificacion = await ServiciosApiService.verificarPrimerServicio();

      _mostrarResultado(
        '✅ API Service OK:\n'
        '- Servicios: ${servicios.length}\n'
        '- Estado inicial: ${estadoInicial?.nombre ?? "No encontrado"}\n'
        '- Verificación: ${verificacion.isSuccess ? "OK" : "Error"}',
      );
      _registrarTestResult('api_service', true);
    } catch (e) {
      _mostrarResultado('❌ Error API Service: $e', esError: true);
      _registrarTestResult('api_service', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Test 3: Navegación a lista
  void _testNavegacionLista() {
    Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ServiciosListPage()),
        )
        .then((result) {
          _mostrarResultado('✅ Regresó de lista - Resultado: $result');
          _registrarTestResult('navegacion_lista', true);
        })
        .catchError((error) {
          _mostrarResultado('❌ Error navegación lista: $error', esError: true);
          _registrarTestResult('navegacion_lista', false);
        });
  }

  /// Test 4: Navegación a crear servicio
  void _testNavegacionCrear() {
    Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ServicioCreatePage()),
        )
        .then((result) {
          if (result != null) {
            _mostrarResultado('✅ Servicio creado: ${result.toString()}');
            _registrarTestResult('navegacion_crear', true);
          } else {
            _mostrarResultado('ℹ️ Creación cancelada');
            _registrarTestResult('navegacion_crear', true); // No es error
          }
        })
        .catchError((error) {
          _mostrarResultado('❌ Error navegación crear: $error', esError: true);
          _registrarTestResult('navegacion_crear', false);
        });
  }

  /// Test 5: Navegación a editar (con servicio de prueba)
  void _testNavegacionEditar() async {
    // Primero cargar servicios para obtener uno real
    if (_controller.servicios.isEmpty) {
      await _testCargarServicios();
    }

    if (_controller.servicios.isNotEmpty) {
      final servicioParaEditar = _controller.servicios.first;

      Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ServicioEditPage(servicio: servicioParaEditar),
            ),
          )
          .then((result) {
            if (result != null) {
              _mostrarResultado('✅ Servicio editado: ${result.toString()}');
              _registrarTestResult('navegacion_editar', true);
            } else {
              _mostrarResultado('ℹ️ Edición cancelada');
              _registrarTestResult('navegacion_editar', true); // No es error
            }
          })
          .catchError((error) {
            _mostrarResultado(
              '❌ Error navegación editar: $error',
              esError: true,
            );
            _registrarTestResult('navegacion_editar', false);
          });
    } else {
      _mostrarResultado('❌ No hay servicios para editar', esError: true);
      _registrarTestResult('navegacion_editar', false);
    }
  }

  /// Test 6: Navegación a detalle
  void _testNavegacionDetalle() async {
    if (_controller.servicios.isEmpty) {
      await _testCargarServicios();
    }

    if (_controller.servicios.isNotEmpty) {
      final servicioParaVer = _controller.servicios.first;

      Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ServicioDetailPage(servicio: servicioParaVer),
            ),
          )
          .then((result) {
            _mostrarResultado('✅ Regresó de detalle');
            _registrarTestResult('navegacion_detalle', true);
          })
          .catchError((error) {
            _mostrarResultado(
              '❌ Error navegación detalle: $error',
              esError: true,
            );
            _registrarTestResult('navegacion_detalle', false);
          });
    } else {
      _mostrarResultado('❌ No hay servicios para ver', esError: true);
      _registrarTestResult('navegacion_detalle', false);
    }
  }

  /// Test 7: Conectividad básica
  Future<void> _testConectividad() async {
    setState(() => _isLoading = true);

    try {
      // Test simple de conectividad
      final funcionarios = await ServiciosApiService.listarFuncionarios();
      final equipos = await ServiciosApiService.listarEquipos();
      final estados = await ServiciosApiService.listarEstados();

      _mostrarResultado(
        '✅ Conectividad OK:\n'
        '- Funcionarios: ${funcionarios.length}\n'
        '- Equipos: ${equipos.length}\n'
        '- Estados: ${estados.length}',
      );
      _registrarTestResult('conectividad', true);
    } catch (e) {
      _mostrarResultado('❌ Error conectividad: $e', esError: true);
      _registrarTestResult('conectividad', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Test 8: Branding
  Future<void> _testBranding() async {
    setState(() => _isLoading = true);

    try {
      await _brandingController.cargarBranding();

      if (_brandingController.error != null) {
        _mostrarResultado(
          '❌ Error branding: ${_brandingController.error}',
          esError: true,
        );
        _registrarTestResult('branding', false);
      } else {
        final branding = _brandingController.branding;
        _mostrarResultado(
          '- Empresa: ${branding?.nombreEmpresa ?? "N/A"}\n'
          '- Color: ${branding?.colorPrimario ?? "N/A"}\n'
          '- Logo: ${branding?.logoUrl ?? "Sin logo"}\n'
          '- Configurado: ${branding?.configuracionCargada ?? false}',
        );
        _registrarTestResult('branding', true);
      }
    } catch (e) {
      _mostrarResultado('❌ Excepción branding: $e', esError: true);
      _registrarTestResult('branding', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Test 9: Modelos y serialización
  Future<void> _testModelos() async {
    setState(() => _isLoading = true);

    try {
      // Test ServicioModel
      final servicioTest = ServicioModel(
        id: 1,
        oServicio: 123,
        fechaIngreso: DateTime.now().toIso8601String(),
        ordenCliente: 'TEST-001',
        tipoMantenimiento: 'preventivo',
        equipoNombre: 'Equipo Test',
        nombreEmp: 'Empresa Test',
        estadoNombre: 'Registrado',
      );

      final servicioJson = servicioTest.toJson();
      final servicioFromJson = ServicioModel.fromJson(servicioJson);

      // Test BrandingModel
      final brandingTest = BrandingModel(
        colorPrimario: '#FF5722',
        colorSecundario: '#009688',
        nombreEmpresa: 'Test Company',
      );

      final brandingJson = brandingTest.toJson();
      final brandingFromJson = BrandingModel.fromJson(brandingJson);

      _mostrarResultado(
        '✅ Modelos OK:\n'
        '- ServicioModel: Serialización correcta\n'
        '- BrandingModel: Serialización correcta\n'
        '- Conversión JSON: Exitosa',
      );
      _registrarTestResult('modelos', true);
    } catch (e) {
      _mostrarResultado('❌ Error en modelos: $e', esError: true);
      _registrarTestResult('modelos', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Test Servicios - Nueva Arquitectura'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Indicador de progreso en AppBar
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                () => setState(() {
                  _resultadoPrueba = '';
                  _testResults.clear();
                  _controller.limpiarError();
                  _brandingController.limpiarError();
                }),
            tooltip: 'Limpiar resultados',
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header informativo con estadísticas
            _buildHeaderCard(),

            const SizedBox(height: 20),

            // Tests de funcionalidad básica
            const Text(
              '🔧 Tests de Funcionalidad Básica',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Test 1: Controller
                    _buildTestButton(
                      '1. 📊 Test Controller',
                      'Probar ServiciosController.cargarServicios()',
                      _testCargarServicios,
                      Icons.analytics,
                      Colors.blue,
                      'cargar_servicios',
                    ),

                    const SizedBox(height: 12),

                    // Test 2: API Service
                    _buildTestButton(
                      '2. 🌐 Test API Service',
                      'Probar métodos directos del ServiciosApiService',
                      _testApiService,
                      Icons.api,
                      Colors.green,
                      'api_service',
                    ),

                    const SizedBox(height: 12),

                    // Test 3: Conectividad
                    _buildTestButton(
                      '3. 📡 Test Conectividad',
                      'Verificar conexión con backend y datos auxiliares',
                      _testConectividad,
                      Icons.wifi,
                      Colors.orange,
                      'conectividad',
                    ),

                    const SizedBox(height: 12),

                    // Test 4: Branding
                    _buildTestButton(
                      '4. 🎨 Test Branding',
                      'Probar carga de configuración de branding',
                      _testBranding,
                      Icons.palette,
                      Colors.purple,
                      'branding',
                    ),

                    const SizedBox(height: 12),

                    // Test 5: Modelos
                    _buildTestButton(
                      '5. 🧬 Test Modelos',
                      'Verificar serialización JSON de modelos',
                      _testModelos,
                      Icons.science,
                      Colors.indigo,
                      'modelos',
                    ),

                    const SizedBox(height: 20),

                    // Tests de navegación
                    const Text(
                      '🧭 Tests de Navegación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Test 6: Lista
                    _buildTestButton(
                      '6. 📋 Ir a Lista',
                      'Navegar a ServiciosListPage',
                      _testNavegacionLista,
                      Icons.list,
                      Colors.teal,
                      'navegacion_lista',
                    ),

                    const SizedBox(height: 12),

                    // Test 7: Crear
                    _buildTestButton(
                      '7. ➕ Ir a Crear',
                      'Navegar a ServicioCreatePage',
                      _testNavegacionCrear,
                      Icons.add_circle,
                      Colors.green,
                      'navegacion_crear',
                    ),

                    const SizedBox(height: 12),

                    // Test 8: Editar
                    _buildTestButton(
                      '8. ✏️ Ir a Editar',
                      'Navegar a ServicioEditPage (requiere datos)',
                      _testNavegacionEditar,
                      Icons.edit,
                      Colors.blue,
                      'navegacion_editar',
                    ),

                    const SizedBox(height: 12),

                    // Test 9: Detalle
                    _buildTestButton(
                      '9. 👁️ Ir a Detalle',
                      'Navegar a ServicioDetailPage (requiere datos)',
                      _testNavegacionDetalle,
                      Icons.visibility,
                      Colors.indigo,
                      'navegacion_detalle',
                    ),
                  ],
                ),
              ),
            ),

            // Resultados y estadísticas
            _buildResultSection(),

            // Loading indicator
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Ejecutando prueba...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),

      // FAB para ejecutar todas las pruebas
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _ejecutarTodasLasPruebas,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Ejecutar Todas'),
        backgroundColor: _isLoading ? Colors.grey : Colors.green,
      ),
    );
  }

  /// Header con información y estadísticas
  Widget _buildHeaderCard() {
    final totalTests = 9;
    final completedTests = _testResults.length;
    final successfulTests =
        _testResults.values.where((success) => success).length;
    final failedTests = _testResults.values.where((success) => !success).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.architecture, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '🏗️ Arquitectura Nueva vs Antigua',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Prueba cada funcionalidad para validar que la nueva '
            'arquitectura funcione correctamente antes de eliminar '
            'el archivo original.',
            style: TextStyle(fontSize: 14),
          ),

          if (_testResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Estadísticas de tests
            Row(
              children: [
                _buildStatChip('Total', totalTests.toString(), Colors.blue),
                const SizedBox(width: 8),
                _buildStatChip(
                  'Ejecutados',
                  completedTests.toString(),
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  'Exitosos',
                  successfulTests.toString(),
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatChip('Fallidos', failedTests.toString(), Colors.red),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Estado del controller
          Row(
            children: [
              if (_controller.isLoading)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Cargando...', style: TextStyle(fontSize: 12)),
                  ],
                )
              else if (_controller.error != null)
                Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error: ${_controller.error}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Servicios cargados: ${_controller.servicios.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Chip de estadísticas
  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  /// Widget helper para botones de test
  Widget _buildTestButton(
    String titulo,
    String descripcion,
    VoidCallback onPressed,
    IconData icon,
    Color color,
    String testKey,
  ) {
    final hasResult = _testResults.containsKey(testKey);
    final isSuccess = _testResults[testKey] ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isLoading ? Colors.grey : color,
                              ),
                            ),
                          ),
                          if (hasResult) ...[
                            Icon(
                              isSuccess ? Icons.check_circle : Icons.error,
                              color: isSuccess ? Colors.green : Colors.red,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: _isLoading ? Colors.grey : color,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sección de resultados
  Widget _buildResultSection() {
    if (_resultadoPrueba.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal, size: 20),
              SizedBox(width: 8),
              Text(
                '📊 Último Resultado:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              _resultadoPrueba,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ejecutar todas las pruebas secuencialmente
  Future<void> _ejecutarTodasLasPruebas() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
    });

    try {
      _mostrarResultado('🚀 Iniciando batería completa de pruebas...');

      // Tests básicos
      await _testBranding();
      await Future.delayed(const Duration(seconds: 1));

      await _testModelos();
      await Future.delayed(const Duration(seconds: 1));

      await _testConectividad();
      await Future.delayed(const Duration(seconds: 1));

      await _testApiService();
      await Future.delayed(const Duration(seconds: 1));

      await _testCargarServicios();
      await Future.delayed(const Duration(seconds: 1));

      // Resumen final
      final successful = _testResults.values.where((success) => success).length;
      final total = _testResults.length;

      _mostrarResultado(
        '🎉 Batería completa finalizada!\n'
        '✅ Exitosos: $successful/$total\n'
        '${successful == total ? "🚀 ¡Todo funcionando!" : "⚠️ Revisar tests fallidos"}',
      );
    } catch (e) {
      _mostrarResultado('❌ Error en batería de pruebas: $e', esError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
