import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/product_model.dart';
import 'package:unimarket/app_colors.dart'; // ✅ IMPORT CENTRALIZADO
import 'chat_page.dart';

class ProductDetailPage extends StatefulWidget {
  final Producto producto;

  const ProductDetailPage({super.key, required this.producto});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final Map<String, String> _vendedorCache = {};
  bool _isLoadingChat = false;

  Future<String> _obtenerNombreVendedor(String vendedorId) async {
    if (_vendedorCache.containsKey(vendedorId)) {
      return _vendedorCache[vendedorId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(vendedorId)
          .get();
      
      if (userDoc.exists) {
        final nombre = userDoc.data()?['nombre'];
        if (nombre != null && nombre is String) {
          _vendedorCache[vendedorId] = nombre;
          return nombre;
        }
      }
      
      final nombreGenerico = 'Vendedor${vendedorId.substring(0, 4)}';
      await FirebaseFirestore.instance.collection('users').doc(vendedorId).set({
        'nombre': nombreGenerico,
        'email': 'vendedor@unimarket.com',
        'fechaCreacion': FieldValue.serverTimestamp(),
        'tipo': 'estudiante',
        'fotoUrl': '',
        'perfilCompletado': false,
      }, SetOptions(merge: true));
      
      _vendedorCache[vendedorId] = nombreGenerico;
      return nombreGenerico;
      
    } catch (e) {
      print('❌ Error obteniendo nombre vendedor $vendedorId: $e');
      return 'Vendedor';
    }
  }

  Future<String> _obtenerEmailVendedor(String vendedorId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(vendedorId)
          .get();
      return doc.data()?['email'] ?? 'vendedor@unimarket.com';
    } catch (e) {
      return 'vendedor@unimarket.com';
    }
  }

  Future<String> _crearObtenerChat() async {
    print('🔍 [CHAT_DEBUG] === INICIANDO CREACIÓN DE CHAT ===');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ [CHAT_DEBUG] ERROR: Usuario no autenticado');
      throw Exception('Usuario no autenticado');
    }
    print('✅ [CHAT_DEBUG] Usuario autenticado: ${user.uid}');
    print('✅ [CHAT_DEBUG] Producto ID: ${widget.producto.id}');
    print('✅ [CHAT_DEBUG] Vendedor ID: ${widget.producto.vendedorId}');

    final firestore = FirebaseFirestore.instance;
    
    print('🔍 [CHAT_DEBUG] Buscando chat existente...');
    try {
      final chatQuery = await firestore
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .where('productId', isEqualTo: widget.producto.id)
          .limit(1)
          .get();
      
      print('✅ [CHAT_DEBUG] Chats encontrados: ${chatQuery.docs.length}');
      
      if (chatQuery.docs.isNotEmpty) {
        final chatId = chatQuery.docs.first.id;
        print('✅ [CHAT_DEBUG] Chat existente encontrado: $chatId');
        return chatId;
      }
      print('✅ [CHAT_DEBUG] No hay chat existente, creando nuevo...');
    } catch (e) {
      print('❌ [CHAT_DEBUG] Error buscando chat: $e');
      throw e;
    }

    print('🔍 [CHAT_DEBUG] Iniciando creación de nuevo chat...');
    
    print('🔍 [CHAT_DEBUG] Obteniendo nombre usuario actual...');
    final currentUserDoc = await firestore.collection('users').doc(user.uid).get();
    final currentUserName = currentUserDoc.data()?['nombre'] ?? 'Comprador';
    print('✅ [CHAT_DEBUG] Nombre usuario actual: $currentUserName');
    
    print('🔍 [CHAT_DEBUG] Obteniendo nombre vendedor...');
    final vendedorName = await _obtenerNombreVendedor(widget.producto.vendedorId);
    print('✅ [CHAT_DEBUG] Nombre vendedor: $vendedorName');

    print('🔍 [CHAT_DEBUG] Creando documento chat en Firestore...');
    final chatDoc = firestore.collection('chats').doc();
    final chatId = chatDoc.id;
    print('✅ [CHAT_DEBUG] Nuevo chat ID generado: $chatId');

    final chatData = {
      'participants': [user.uid, widget.producto.vendedorId],
      'participantNames': {
        user.uid: currentUserName,
        widget.producto.vendedorId: vendedorName,
      },
      'lastMessage': 'Hola, ¿te interesa mi producto "${widget.producto.nombre}"?',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'productId': widget.producto.id,
    };
    
    print('🔍 [CHAT_DEBUG] Datos del chat: $chatData');
    
    try {
      await chatDoc.set(chatData);
      print('✅ [CHAT_DEBUG] Chat creado exitosamente en Firestore');
    } catch (e) {
      print('❌ [CHAT_DEBUG] Error creando chat: $e');
      print('❌ [CHAT_DEBUG] Detalles del error: ${e.toString()}');
      throw e;
    }

    print('🔍 [CHAT_DEBUG] Creando mensaje inicial...');
    try {
      final mensajeData = {
        'senderId': widget.producto.vendedorId,
        'text': '¡Hola! Soy $vendedorName. Veo que te interesa mi producto "${widget.producto.nombre}". ¿En qué puedo ayudarte?',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': false,
      };
      
      await chatDoc.collection('messages').add(mensajeData);
      print('✅ [CHAT_DEBUG] Mensaje inicial creado exitosamente');
    } catch (e) {
      print('❌ [CHAT_DEBUG] Error creando mensaje: $e');
      print('⚠️ [CHAT_DEBUG] Continuando sin mensaje inicial...');
    }

    print('🎉 [CHAT_DEBUG] === CHAT CREADO EXITOSAMENTE ===');
    print('🎉 [CHAT_DEBUG] Chat ID: $chatId');
    return chatId;
  }

  Future<void> _manejarPedido() async {
    print('🔍 [BOTON_DEBUG] === BOTÓN PRESIONADO ===');
    print('🔍 [BOTON_DEBUG] _isLoadingChat: $_isLoadingChat');
    
    if (_isLoadingChat) {
      print('❌ [BOTON_DEBUG] Botón bloqueado - ya está cargando');
      return;
    }

    if (!mounted) {
      print('❌ [BOTON_DEBUG] Widget no montado');
      return;
    }
    
    print('✅ [BOTON_DEBUG] Iniciando proceso de chat...');
    setState(() => _isLoadingChat = true);

    try {
      print('🔍 [BOTON_DEBUG] Mostrando diálogo de loading...');
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secundario), // ✅ VERDE LIMA
              ),
              SizedBox(height: 16),
              Text(
                'Creando chat con el vendedor...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
      
      print('✅ [BOTON_DEBUG] Diálogo de loading mostrado (continuando sin await)');

      print('🔍 [BOTON_DEBUG] Llamando a _crearObtenerChat()...');
      final chatId = await _crearObtenerChat();
      print('✅ [BOTON_DEBUG] Chat creado/obtenido: $chatId');
      
      final vendedorName = _vendedorCache[widget.producto.vendedorId] ?? 
          await _obtenerNombreVendedor(widget.producto.vendedorId);
      
      if (mounted) {
        print('🔍 [BOTON_DEBUG] Cerrando diálogo y navegando...');
        Navigator.pop(context);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              chatId: chatId,
              otherUserId: widget.producto.vendedorId,
              otherUserName: vendedorName,
              productName: widget.producto.nombre,
            ),
          ),
        );
        print('✅ [BOTON_DEBUG] Navegación completada');
      }
    } catch (e) {
      print('❌ [BOTON_DEBUG] Error en _manejarPedido: $e');
      
      if (mounted) {
        print('🔍 [BOTON_DEBUG] Cerrando diálogo por error...');
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getMensajeErrorChat(e),
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print('✅ [BOTON_DEBUG] Snackbar de error mostrado');
      }
    } finally {
      if (mounted) {
        print('🔍 [BOTON_DEBUG] Finalizando - reset _isLoadingChat');
        setState(() => _isLoadingChat = false);
      }
      print('✅ [BOTON_DEBUG] === PROCESO FINALIZADO ===');
    }
  }

  String _getMensajeErrorChat(dynamic e) {
    if (e.toString().contains('no autenticado')) {
      return 'Debes iniciar sesión para contactar al vendedor';
    } else if (e.toString().contains('network') || e.toString().contains('timeout')) {
      return 'Error de conexión. Verifica tu internet';
    } else {
      return 'Error al crear el chat. Intenta nuevamente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 🖼️ IMAGEN PRINCIPAL CON SLIVERAPPBAR
          SliverAppBar(
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.producto.imagenUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.photo,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            pinned: true,
            backgroundColor: AppColors.primario,
          ),

          // 🔍 INFORMACIÓN DEL PRODUCTO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NOMBRE DEL PRODUCTO
                  Text(
                    widget.producto.nombre,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // PRECIO DESTACADO
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.secundario.withOpacity(0.1), // ✅ VERDE LIMA claro
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.secundario.withOpacity(0.3), // ✅ VERDE LIMA
                      ),
                    ),
                    child: Text(
                      '${widget.producto.precio.toStringAsFixed(2)} Bs',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secundario, // ✅ VERDE LIMA
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // DESCRIPCIÓN
                  Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.producto.descripcion,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // INFORMACIÓN DEL VENDEDOR
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vendedor:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              FutureBuilder<String>(
                                future: _obtenerNombreVendedor(widget.producto.vendedorId),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.secundario, // ✅ VERDE LIMA
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Cargando...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return Text(
                                    snapshot.data ?? 'Vendedor',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primario,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Método de pago:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getMetodoCobroColor(widget.producto.metodoCobro),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getMetodoCobroText(widget.producto.metodoCobro),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // INFORMACIÓN ADICIONAL DEL PRODUCTO
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primario.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.primario, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '¿Qué significa crear una marca?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primario,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem('• Acuerda el método de pago directamente con el vendedor'),
                        _buildInfoItem('• Coordina lugar y horario de entrega'),
                        _buildInfoItem('• Verifica el producto antes de pagar'),
                        _buildInfoItem('• Reporta cualquier problema a soporte'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // 🟢 BOTÓN "CONTACTAR VENDEDOR" - VERDE LIMA
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: _isLoadingChat ? null : () {
            print('🎯 [BOTON_TEST] Botón presionado directamente - onPressed ejecutado');
            _manejarPedido();
          },
          icon: _isLoadingChat 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.chat, color: Colors.white),
          label: _isLoadingChat 
              ? Text('Creando chat...', style: TextStyle(color: Colors.white))
              : Text('Contactar Vendedor', style: TextStyle(color: Colors.white)),
          backgroundColor: _isLoadingChat ? Colors.grey : AppColors.secundario, // ✅ VERDE LIMA
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[700],
          height: 1.4,
        ),
      ),
    );
  }

  String _getMetodoCobroText(String metodo) {
    switch (metodo) {
      case 'efectivo':
        return '💵 Efectivo';
      case 'qr':
        return '📱 QR';
      case 'ambos':
        return '💳 Efectivo o QR';
      default:
        return 'Pago';
    }
  }

  Color _getMetodoCobroColor(String metodo) {
    switch (metodo) {
      case 'efectivo':
        return AppColors.exito;
      case 'qr':
        return AppColors.primario;
      case 'ambos':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}