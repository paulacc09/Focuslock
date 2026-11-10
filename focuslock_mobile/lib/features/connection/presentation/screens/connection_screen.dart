import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/focus_lock_provider.dart';
import '../../../../core/services/http_focus_lock_service.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<FocusLockProvider>();
    _hostController = TextEditingController(text: provider.host);
    _portController = TextEditingController(text: provider.port.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _testAndConnect(bool save) async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8000;

    final testService = HttpFocusLockService();
    final ok = await testService.testConnection(host: host, port: port);
    testService.dispose();

    if (!mounted) return;

    if (save) {
      final provider = context.read<FocusLockProvider>();
      await provider.updateNetworkEndpoint(host, port);
      if (provider.isMockMode) {
        provider.toggleMockMode(false);
      }
    }

    setState(() {
      _isTesting = false;
      _testSuccess = ok;
      _testResult = ok
          ? '¡Conectado exitosamente con Raspberry Pi en $host:$port!'
          : (save
              ? 'Configuración guardada en $host:$port. Esperando respuesta del servidor...'
              : 'No se pudo conectar a $host:$port. Verifica que python3 main.py esté activo.');
    });

    if (save && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Endpoint configurado en $host:$port'),
          backgroundColor: AppColors.primarySageDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusLockProvider>();
    final isConnected = provider.status.isConnected && !provider.isMockMode;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Conexión con Raspberry Pi 4'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Estado Actual
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isConnected
                    ? AppColors.primarySage.withValues(alpha: 0.15)
                    : (provider.isMockMode
                        ? AppColors.graceOrange.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isConnected
                      ? AppColors.primarySage
                      : (provider.isMockMode ? AppColors.graceOrange : Colors.red),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected
                        ? Icons.check_circle_rounded
                        : (provider.isMockMode ? Icons.science_rounded : Icons.wifi_off_rounded),
                    color: isConnected
                        ? AppColors.primarySageDark
                        : (provider.isMockMode ? AppColors.graceOrange : Colors.red),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected
                              ? 'Conectado a Raspberry Pi'
                              : (provider.isMockMode ? 'Modo Simulación (Mock)' : 'Sin Conexión Física'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isConnected
                              ? 'IP: ${provider.host}:${provider.port}'
                              : (provider.isMockMode
                                  ? 'Actualmente simulando hardware en la app'
                                  : 'Intentando conectar a ${provider.host}:${provider.port}'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Formulario de Conexión
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Parámetros de Red LAN / Wi-Fi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: 'Dirección IP o Host mDNS',
                      hintText: 'Ej. 192.168.1.50 ó focuslock.local',
                      prefixIcon: const Icon(Icons.router_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.scaffoldBackground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Puerto TCP',
                      hintText: '8000',
                      prefixIcon: const Icon(Icons.settings_ethernet_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.scaffoldBackground,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : () => _testAndConnect(false),
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check_rounded),
                          label: const Text('Probar Ping'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTesting ? null : () => _testAndConnect(true),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Guardar y Usar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primarySage,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_testResult != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testSuccess
                            ? AppColors.primarySage.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _testSuccess ? AppColors.primarySageDark : Colors.red,
                        ),
                      ),
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _testSuccess ? AppColors.primarySageDark : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tarjeta de Guía Paso a Paso para la Raspberry Pi 4
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline_rounded, color: AppColors.primarySageDark),
                      SizedBox(width: 8),
                      Text(
                        '¿Cómo conectar tu celular con la Pi 4?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Método más fácil para presentaciones (Zona Wi-Fi):\n'
                    '   • Activa la "Zona Wi-Fi" o "Hotspot" de tu teléfono.\n'
                    '   • Conecta la Raspberry Pi 4 a esa red Wi-Fi de tu celular.\n'
                    '   • En la consola de la Pi 4 escribe: hostname -I\n'
                    '   • Copia la IP que aparece (ej: 192.168.43.50) en el campo superior.\n\n'
                    '2. En la Raspberry Pi 4 ejecuta:\n'
                    '   python main.py\n\n'
                    '3. Pulsa "Probar Ping" y luego "Guardar y Usar".',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
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
