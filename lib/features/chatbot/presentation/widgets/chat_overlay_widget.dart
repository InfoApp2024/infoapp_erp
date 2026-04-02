import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:infoapp/core/branding/branding_colors.dart';
import '../../data/chatbot_service.dart';
import '../../models/chat_message.dart';

import 'package:infoapp/pages/servicios/forms/servicio_create_page.dart';
import 'package:infoapp/pages/inventory/pages/inventory_main_page.dart';

class ChatOverlayWidget extends StatefulWidget {
  final VoidCallback onClose;

  const ChatOverlayWidget({super.key, required this.onClose});

  @override
  State<ChatOverlayWidget> createState() => _ChatOverlayWidgetState();
}

class _ChatOverlayWidgetState extends State<ChatOverlayWidget>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatbotService _chatbotService = ChatbotService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // Sugerencias rápidas
  // Sugerencias rápidas
  final List<Map<String, dynamic>> _quickChips = [
    {'label': 'Hola', 'icon': Icons.waving_hand, 'text': 'Hola'}, // ✅ Fix Web
    {'label': 'Crear servicio', 'icon': Icons.add_circle, 'text': 'Crear servicio'}, // ✅ Fix Web
    {'label': 'Ver inventario', 'icon': Icons.inventory, 'text': 'Ver inventario'}, // ✅ Fix Web
    {'label': 'Ayuda', 'icon': Icons.help, 'text': 'Ayuda'}, // ✅ Fix Web
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _chatbotService.getHistory();
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(history);
          
          if (_messages.isEmpty) {
             _messages.add(ChatMessage(
               isUser: false,
               text: '¡Hola! Soy tu asistente técnico. ¿En qué puedo ayudarte?',
               timestamp: DateTime.now(),
             ));
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage({String? messageText}) async {
    final text = messageText ?? _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Manejo de Acciones Rápidas (Navegación)
    if (text == 'Crear servicio') {
      widget.onClose(); // Cerrar overlay
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ServicioCreatePage()),
      );
      return;
    }
    if (text == 'Ver inventario') {
      widget.onClose(); // Cerrar overlay
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const InventoryMainPage()),
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(
        isUser: true,
        text: text,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _chatbotService.sendMessage(text);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            isUser: false,
            text: response,
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _messages.add(ChatMessage(
            isUser: false,
            text: 'Error inesperado: $e',
            timestamp: DateTime.now(),
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar historial?'),
        content: const Text(
          'Esto eliminará los mensajes de la vista actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(ChatMessage(
                  isUser: false,
                  text: 'Historial borrado. ¿En qué puedo ayudarte?',
                  timestamp: DateTime.now(),
                ));
              });
              Navigator.pop(context);
            },
            child: const Text(
              'Borrar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Definir tamaño según dispositivo
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final viewInsets = MediaQuery.of(context).viewInsets;

    // En móvil: Ancho y alto completo. En escritorio: 400x600.
    final width = isMobile ? double.infinity : 400.0;
    final height = isMobile ? double.infinity : 600.0;

    return Material(
      color: Colors.transparent,
      elevation: 8,
      child: Padding(
        // En móvil, agregamos padding bottom según el teclado
        padding:
            isMobile
                ? EdgeInsets.only(bottom: viewInsets.bottom)
                : const EdgeInsets.only(bottom: 20, right: 20),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                isMobile ? BorderRadius.zero : BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.primaryDark,
                borderRadius: BorderRadius.only(
                  topLeft: isMobile ? Radius.zero : const Radius.circular(16),
                  topRight: isMobile ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                   const Icon(Icons.auto_awesome, color: Colors.white, size: 20), // ✅ Fix Web
                  const SizedBox(width: 8),
                  const Text(
                    'Asistente IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  // Botón de limpiar
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: _clearChat,
                    tooltip: 'Limpiar chat',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: widget.onClose,
                     padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: _TypingIndicator(),
                    );
                  }
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),
            // Chips de sugerencias (visible si no está cargando)
            if (!_isLoading)
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickChips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final chip = _quickChips[index];
                    return ActionChip(
                      avatar: Icon(
                        chip['icon'] as IconData,
                        size: 16,
                        color: context.primaryColor,
                      ),
                      label: Text(
                        chip['label'] as String,
                         style: TextStyle(
                          fontSize: 12,
                          color: context.primaryColor,
                        ),
                      ),
                      backgroundColor: context.primarySurface,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onPressed:
                          () => _sendMessage(messageText: chip['text'] as String),
                    );
                  },
                ),
              ),
            // Input
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isLoading,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                       decoration: InputDecoration(
                        hintText:
                            _isLoading ? 'Pensando...' : 'Escribe aquí...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        _isLoading ? Colors.grey : context.primaryColor,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_upward, // ✅ Fix: Icono geométrico 100% seguro
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _isLoading ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: msg.isUser ? context.primaryColor : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: msg.isUser ? const Radius.circular(12) : Radius.zero,
                bottomRight: msg.isUser ? Radius.zero : const Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.isUser)
                  Text(
                    msg.text,
                     style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                else
                  MarkdownBody(
                    data: msg.text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.black87, fontSize: 14),
                      strong: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        final uri = Uri.parse(href);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
          // Footer del mensaje: Hora y acciones
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.timestamp != null)
                  Text(
                    DateFormat('h:mm a').format(msg.timestamp!),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                if (!msg.isUser) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: msg.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                           content: Text('Copiado al portapapeles'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(Icons.copy, size: 12, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget de indicador de escritura (3 puntos animados)
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
       padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
          bottomLeft: Radius.zero,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return ScaleTransition(
            scale: CurvedAnimation(
              parent: _controller,
              curve: Interval(
                index * 0.2,
                0.6 + index * 0.2,
                 curve: Curves.easeInOut,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: CircleAvatar(radius: 4, backgroundColor: Colors.grey),
            ),
          );
        }),
      ),
    );
  }
}
