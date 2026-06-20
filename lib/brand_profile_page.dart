import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/product_model.dart';
import 'package:unimarket/app_colors.dart'; // ✅ IMPORT CENTRALIZADO
import 'product_detail_page.dart';
import 'brand_product_detail_page.dart';

class BrandProfilePage extends StatefulWidget {
  final String userId;

  const BrandProfilePage({super.key, required this.userId});

  @override
  State<BrandProfilePage> createState() => _BrandProfilePageState();
}

class _BrandProfilePageState extends State<BrandProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Estadísticas de la marca
  int _ventasTotales = 0;
  int _productosPublicados = 0;
  int _clientesAtendidos = 0;
  double _ratingPromedio = 4.5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosMarca();
  }

  Future<void> _cargarDatosMarca() async {
    try {
      final userDoc = await _firestore.collection('users').doc(widget.userId).get();
      final userData = userDoc.data() ?? {};
      
      final productosSnapshot = await _firestore
          .collection('productos')
          .where('vendedorId', isEqualTo: widget.userId)
          .get();

      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: widget.userId)
          .get();

      if (mounted) {
        setState(() {
          _ventasTotales = userData['ventasTotales'] ?? 0;
          _productosPublicados = productosSnapshot.docs.length;
          _clientesAtendidos = chatsSnapshot.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando datos de marca: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStatCard(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icono, size: 30, color: color),
              SizedBox(height: 8),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star : Icons.star_border,
          color: Color(0xFFFFD700),
          size: 20,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  SizedBox(height: 16),
                  Text('Error al cargar la marca'),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primario));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Marca no encontrada'),
                ],
              ),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final nombreEmpresa = userData['nombreEmpresa'] ?? 'Sin nombre';
          final descripcionEmpresa = userData['descripcionEmpresa'] ?? '';
          final horarioAtencion = userData['horarioAtencion'] ?? '';
          final telefonoContacto = userData['telefonoContacto'] ?? '';
          final logoUrl = userData['logoUrl'] ?? '';
          final bannerUrl = userData['bannerUrl'] ?? '';
          final categoriasEmpresa = List<String>.from(userData['categoriasEmpresa'] ?? []);
          final verificado = userData['verificado'] ?? false;

          return CustomScrollView(
            slivers: [
              // 🆕 BANNER DE LA MARCA
              SliverAppBar(
                expandedHeight: 200,
                flexibleSpace: bannerUrl.isNotEmpty
                    ? FlexibleSpaceBar(
                        background: Image.network(
                          bannerUrl,
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
                        ),
                      )
                    : FlexibleSpaceBar(
                        background: Container(
                          color: AppColors.primario,
                          child: Icon(
                            Icons.business_center,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                pinned: true,
                backgroundColor: AppColors.primario,
              ),

              // INFORMACIÓN DE LA MARCA
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER CON LOGO E INFORMACIÓN
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LOGO
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              color: Colors.white,
                            ),
                            child: logoUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(logoUrl, fit: BoxFit.cover),
                                  )
                                : Icon(
                                    Icons.business,
                                    size: 40,
                                    color: AppColors.primario,
                                  ),
                          ),
                          
                          SizedBox(width: 16),
                          
                          // INFORMACIÓN PRINCIPAL
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        nombreEmpresa,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primario,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    if (verificado)
                                      Icon(Icons.verified, color: AppColors.acento, size: 20),
                                  ],
                                ),
                                
                                SizedBox(height: 8),
                                
                                // RATING
                                _buildRatingStars(_ratingPromedio),
                                
                                SizedBox(height: 8),
                                
                                // CATEGORÍAS
                                if (categoriasEmpresa.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    children: categoriasEmpresa.take(3).map((categoria) {
                                      return Chip(
                                        label: Text(
                                          categoria,
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        backgroundColor: AppColors.primario.withOpacity(0.1),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: EdgeInsets.zero,
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 24),
                      
                      // DESCRIPCIÓN
                      if (descripcionEmpresa.isNotEmpty) ...[
                        Text(
                          'Sobre nosotros',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primario,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          descripcionEmpresa,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                      
                      // INFORMACIÓN DE CONTACTO
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Información de contacto',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primario,
                                ),
                              ),
                              SizedBox(height: 12),
                              
                              if (horarioAtencion.isNotEmpty)
                                _buildInfoItem('Horario de atención', horarioAtencion, Icons.schedule),
                              
                              if (telefonoContacto.isNotEmpty)
                                _buildInfoItem('Teléfono', telefonoContacto, Icons.phone),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // ESTADÍSTICAS DE LA MARCA
                      Text(
                        'Estadísticas de la marca',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primario,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      _isLoading
                          ? Center(child: CircularProgressIndicator(color: AppColors.primario))
                          : Row(
                              children: [
                                _buildStatCard('Ventas', _ventasTotales.toString(), Icons.shopping_cart, AppColors.acento),
                                SizedBox(width: 8),
                                _buildStatCard('Productos', _productosPublicados.toString(), Icons.inventory_2, AppColors.primario),
                                SizedBox(width: 8),
                                _buildStatCard('Clientes', _clientesAtendidos.toString(), Icons.people, AppColors.acento),
                              ],
                            ),
                      
                      SizedBox(height: 32),
                      
                      // PRODUCTOS DE LA MARCA
                      Text(
                        'Productos de la marca',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primario,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ✅ LISTA DE PRODUCTOS CORREGIDA
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('productos')
                    .where('vendedorId', isEqualTo: widget.userId)
                    .orderBy('fechaCreacion', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('❌ Error en productos: ${snapshot.error}');
                    return SliverToBoxAdapter(
                      child: Container(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            SizedBox(height: 12),
                            Text(
                              'Error al cargar productos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Detalles: ${snapshot.error}',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              child: Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.primario),
                              SizedBox(height: 16),
                              Text('Cargando productos...'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2, size: 60, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'No hay productos publicados',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Esta marca aún no ha publicado productos',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final productos = <Producto>[];
                  for (var doc in snapshot.data!.docs) {
                    try {
                      productos.add(Producto.fromFirestore(doc));
                    } catch (e) {
                      print('⚠️ Error parseando producto ${doc.id}: $e');
                    }
                  }

                  if (productos.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.warning_amber, size: 60, color: Colors.orange),
                            SizedBox(height: 16),
                            Text(
                              'Productos con problemas',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange[800],
                              ),
                            ),
                            Text(
                              'Los productos no pudieron cargarse correctamente',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final producto = productos[index];
                        return _buildProductCard(producto);
                      },
                      childCount: productos.length,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primario),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Producto producto) {
    final bool esEmpresa = producto.tipoVendedor == 'empresarial' || 
                           producto.tipoVendedor == 'dual';
    
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () {
            if (esEmpresa && producto.nombreEmpresa != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BrandProductDetailPage(producto: producto),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(producto: producto),
                ),
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                // IMAGEN DEL PRODUCTO
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      producto.imagenUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.photo, color: Colors.grey[400]);
                      },
                    ),
                  ),
                ),
                
                SizedBox(width: 12),
                
                // INFORMACIÓN DEL PRODUCTO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primario,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: 4),
                      
                      Text(
                        producto.descripcion,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: 8),
                      
                      Text(
                        'Bs. ${producto.precio.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.acento,
                        ),
                      ),
                    ],
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