import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/product_model.dart';
import 'package:unimarket/app_colors.dart'; // ✅ IMPORT CENTRALIZADO
import 'chat_page.dart';
import 'brand_profile_page.dart';

class BrandProductDetailPage extends StatefulWidget {
  final Producto producto;

  const BrandProductDetailPage({super.key, required this.producto});

  @override
  State<BrandProductDetailPage> createState() => _BrandProductDetailPageState();
}

class _BrandProductDetailPageState extends State<BrandProductDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoadingChat = false;
  Map<String, dynamic>? _brandData;
  bool _isLoadingBrand = true;
  int _productosCount = 0;
  
  final Map<String, String> _vendedorCache = {};

  @override
  void initState() {
    super.initState();
    _cargarDatosMarca();
  }

  Future<void> _cargarDatosMarca() async {
    try {
      final brandDoc = await _firestore
          .collection('users')
          .doc(widget.producto.vendedorId)
          .get();
      
      if (brandDoc.exists) {
        setState(() {
          _brandData = brandDoc.data();
        });
      }

      final productosSnapshot = await _firestore
          .collection('productos')
          .where('vendedorId', isEqualTo: widget.producto.vendedorId)
          .get();

      if (mounted) {
        setState(() {
          _productosCount = productosSnapshot.docs.length;
          _isLoadingBrand = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando datos de marca: $e');
      if (mounted) {
        setState(() {
          _isLoadingBrand = false;
        });
      }
    }
  }

  Future<String> _obtenerNombreVendedor(String vendedorId) async {
    if (_vendedorCache.containsKey(vendedorId)) {
      return _vendedorCache[vendedorId]!;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(vendedorId).get();
      
      if (userDoc.exists) {
        final nombre = userDoc.data()?['nombre'];
        if (nombre != null && nombre is String) {
          _vendedorCache[vendedorId] = nombre;
          return nombre;
        }
      }
      
      final nombreGenerico = 'Vendedor${vendedorId.substring(0, 4)}';
      _vendedorCache[vendedorId] = nombreGenerico;
      return nombreGenerico;
      
    } catch (e) {
      print('❌ Error obteniendo nombre vendedor: $e');
      return 'Vendedor';
    }
  }

  Future<String> _crearObtenerChat() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final chatQuery = await _firestore
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .where('productId', isEqualTo: widget.producto.id)
        .limit(1)
        .get();
    
    if (chatQuery.docs.isNotEmpty) {
      return chatQuery.docs.first.id;
    }

    final currentUserDoc = await _firestore.collection('users').doc(user.uid).get();
    final currentUserName = currentUserDoc.data()?['nombre'] ?? 'Comprador';
    
    final vendedorName = await _obtenerNombreVendedor(widget.producto.vendedorId);

    final chatDoc = _firestore.collection('chats').doc();
    final chatId = chatDoc.id;

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
    
    await chatDoc.set(chatData);

    try {
      final mensajeData = {
        'senderId': widget.producto.vendedorId,
        'text': '¡Hola! Soy $vendedorName. Veo que te interesa nuestro producto "${widget.producto.nombre}". ¿En qué puedo ayudarte?',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': false,
      };
      
      await chatDoc.collection('messages').add(mensajeData);
    } catch (e) {
      print('⚠️ Error creando mensaje inicial: $e');
    }

    return chatId;
  }

  Future<void> _contactarVendedor() async {
    if (_isLoadingChat) return;

    if (!mounted) return;
    
    setState(() => _isLoadingChat = true);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primario),
              ),
              SizedBox(height: 16),
              Text(
                'Creando chat con la marca...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

      final chatId = await _crearObtenerChat();
      final vendedorName = _vendedorCache[widget.producto.vendedorId] ?? 
          await _obtenerNombreVendedor(widget.producto.vendedorId);
      
      if (mounted) {
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
      }
    } catch (e) {
      print('❌ Error contactando vendedor: $e');
      
      if (mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(_getMensajeErrorChat(e)),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingChat = false);
      }
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
          // 🎨 BANNER DE LA MARCA
          SliverAppBar(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: _isLoadingBrand
                  ? Container(
                      color: AppColors.primario,
                      child: Center(child: CircularProgressIndicator(color: Colors.white)),
                    )
                  : (_brandData?['bannerUrl']?.isNotEmpty == true
                      ? Image.network(
                          _brandData!['bannerUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.primario,
                              child: Icon(
                                Icons.business_center,
                                size: 60,
                                color: Colors.white,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppColors.primario,
                          child: Icon(
                            Icons.business_center,
                            size: 60,
                            color: Colors.white,
                          ),
                        )),
            ),
            pinned: true,
            backgroundColor: AppColors.primario,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER DE LA MARCA
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoadingBrand
                      ? Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                    color: Colors.white,
                                  ),
                                  child: _brandData?['logoUrl']?.isNotEmpty == true
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            _brandData!['logoUrl'],
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Icon(
                                          Icons.business,
                                          size: 35,
                                          color: AppColors.primario,
                                        ),
                                ),
                                
                                SizedBox(width: 16),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              widget.producto.nombreEmpresa ?? 'Marca',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primario,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          if (_brandData?['verificado'] == true)
                                            Icon(Icons.verified, color: AppColors.acento, size: 20),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '$_productosCount productos publicados',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 16),
                            
                            if (_brandData?['categoriasEmpresa'] is List && 
                                (_brandData!['categoriasEmpresa'] as List).isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (_brandData!['categoriasEmpresa'] as List).map((categoria) {
                                  return Chip(
                                    label: Text(
                                      categoria,
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: AppColors.primario.withOpacity(0.1),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                  );
                                }).toList(),
                              ),
                            
                            SizedBox(height: 16),
                            
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BrandProfilePage(
                                        userId: widget.producto.vendedorId,
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.storefront, size: 18),
                                label: Text('Ver todos los productos de esta marca'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primario,
                                  side: BorderSide(color: AppColors.primario),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                
                Container(
                  height: 8,
                  color: AppColors.fondoGris,
                ),
                
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.acento.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PRODUCTO DESTACADO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.acento,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 250,
                          width: double.infinity,
                          color: Colors.grey[100],
                          child: Image.network(
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
                      ),
                      
                      SizedBox(height: 20),
                      
                      Text(
                        widget.producto.nombre,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.acento.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.acento.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_money, color: AppColors.acento, size: 22),
                            SizedBox(width: 4),
                            Text(
                              '${widget.producto.precio.toStringAsFixed(2)} Bs',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.acento,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      Text(
                        'Descripción del producto',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.producto.descripcion,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.payment, color: AppColors.primario, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Método de pago',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppColors.primario,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getMetodoCobroColor(widget.producto.metodoCobro),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getMetodoCobroText(widget.producto.metodoCobro),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      if (_brandData != null) ...[
                        Container(
                          padding: EdgeInsets.all(16),
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
                                    'Información de contacto',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primario,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              
                              if (_brandData!['horarioAtencion']?.isNotEmpty == true)
                                _buildInfoRow(
                                  Icons.schedule,
                                  'Horario',
                                  _brandData!['horarioAtencion'],
                                ),
                              
                              if (_brandData!['telefonoContacto']?.isNotEmpty == true)
                                _buildInfoRow(
                                  Icons.phone,
                                  'Teléfono',
                                  _brandData!['telefonoContacto'],
                                ),
                              
                              if (_brandData!['descripcionEmpresa']?.isNotEmpty == true) ...[
                                SizedBox(height: 8),
                                Text(
                                  _brandData!['descripcionEmpresa'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                      
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Recomendaciones de compra',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            _buildRecomendacion('Contacta directamente con la marca'),
                            _buildRecomendacion('Acuerda el método de pago y entrega'),
                            _buildRecomendacion('Verifica el producto antes de pagar'),
                            _buildRecomendacion('Pide factura si es necesario'),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: _isLoadingChat ? null : _contactarVendedor,
          icon: _isLoadingChat 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.chat_bubble),
          label: _isLoadingChat 
              ? Text('Creando chat...')
              : Text('Contactar Marca'),
          backgroundColor: _isLoadingChat ? Colors.grey : AppColors.primario,
          foregroundColor: Colors.white,
          elevation: 6,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primario),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecomendacion(String texto) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16, color: Colors.orange[800])),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMetodoCobroText(String metodo) {
    switch (metodo) {
      case 'efectivo':
        return '💵 Efectivo';
      case 'qr':
        return '📱 QR de pago';
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