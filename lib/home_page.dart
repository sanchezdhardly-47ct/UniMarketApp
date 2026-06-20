import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unimarket/product_model.dart';
import 'publish_page.dart';
import 'product_detail_page.dart';
import 'brand_product_detail_page.dart';
import 'chats_list_page.dart';
import 'profile_page.dart';
import 'package:unimarket/app_colors.dart';

// ENUM PARA FILTROS
enum FilterType {
  todos,
  soloEspontaneos,
  soloEmpresas
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  FilterType _filtroActual = FilterType.todos;
  bool _mostrarFiltros = false;

  Future<void> _cerrarSesion(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('❌ Error cerrando sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  List<Producto> _filtrarProductos(List<Producto> productos) {
    var filtered = productos.where((producto) {
      switch (_filtroActual) {
        case FilterType.soloEspontaneos:
          return producto.tipoVendedor == 'espontaneo';
        case FilterType.soloEmpresas:
          return producto.tipoVendedor == 'empresarial' ||
              producto.tipoVendedor == 'dual';
        case FilterType.todos:
        default:
          return true;
      }
    }).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((producto) {
        final nombre = producto.nombre.toLowerCase();
        final descripcion = producto.descripcion.toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        bool coincideProducto = nombre.contains(query) || descripcion.contains(query);
        
        if ((producto.tipoVendedor == 'empresarial' || producto.tipoVendedor == 'dual') && 
            producto.nombreEmpresa != null) {
          final nombreEmpresa = producto.nombreEmpresa!.toLowerCase();
          coincideProducto = coincideProducto || nombreEmpresa.contains(query);
        }
        
        return coincideProducto;
      }).toList();
    }

    return filtered;
  }

  Widget _buildHomePage() {
    return Container(
      color: AppColors.fondoGris,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('productos')
            .orderBy('fechaCreacion', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState('Error al cargar productos');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          List<Producto> productos = snapshot.data!.docs
              .map((doc) => Producto.fromFirestore(doc))
              .toList();

          productos = _filtrarProductos(productos);

          if (productos.isEmpty) {
            return _buildNoResultsState();
          }

          return Column(
            children: [
              if (_mostrarFiltros) _buildFiltrosBar(),
              Expanded(
                child: _buildProductList(productos),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltrosBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.fondo,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtrar por:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primario,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _mostrarFiltros = false;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFiltroChip('Todos', FilterType.todos),
              _buildFiltroChip('Solo Espontáneos', FilterType.soloEspontaneos),
              _buildFiltroChip('Solo Empresas', FilterType.soloEmpresas),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, FilterType tipo) {
    final bool seleccionado = _filtroActual == tipo;
    
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: seleccionado ? Colors.white : AppColors.primario,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: seleccionado,
      onSelected: (selected) {
        setState(() {
          _filtroActual = tipo;
        });
      },
      selectedColor: AppColors.primario,
      backgroundColor: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: seleccionado ? AppColors.primario : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.textoSecundario.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.acento),
          const SizedBox(height: 16),
          Text(
            'Cargando productos...',
            style: TextStyle(
              color: AppColors.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppColors.textoSecundario.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay productos publicados',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textoSecundario,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sé el primero en publicar algo',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textoSecundario.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _selectedIndex = 1;
                });
              }
            },
            child: const Text('Publicar primer producto'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    String mensajeFiltro = '';
    
    switch (_filtroActual) {
      case FilterType.soloEspontaneos:
        mensajeFiltro = 'con vendedores espontáneos';
        break;
      case FilterType.soloEmpresas:
        mensajeFiltro = 'con empresas establecidas';
        break;
      case FilterType.todos:
      default:
        mensajeFiltro = '';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textoSecundario.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron resultados',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textoSecundario,
            ),
          ),
          if (mensajeFiltro.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              'Filtro activo: $mensajeFiltro',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primario,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Intenta con otros términos de búsqueda',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textoSecundario.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  if (mounted) {
                    setState(() {
                      _searchQuery = '';
                    });
                  }
                },
                child: const Text('Limpiar búsqueda'),
              ),
              if (_filtroActual != FilterType.todos)
                OutlinedButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _filtroActual = FilterType.todos;
                      });
                    }
                  },
                  child: const Text('Quitar filtro'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<Producto> productos) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final producto = productos[index];
        final bool esEmpresa = producto.tipoVendedor == 'empresarial' || 
                               producto.tipoVendedor == 'dual';
        
        return _buildProductCard(producto, esEmpresa);
      },
    );
  }

  // =============================================
  // 🎬 VERSIÓN ANIMADA DE LA TARJETA DE PRODUCTO (CORREGIDA)
  // =============================================
  Widget _buildProductCard(Producto producto, bool esEmpresa) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Material(
          color: AppColors.fondo,
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          shadowColor: AppColors.primario.withOpacity(0.2),
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
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📸 IMAGEN DEL PRODUCTO
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: AppColors.fondoGris,
                      child: Image.network(
                        producto.imagenUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppColors.fondoGris,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.acento,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.fondoGris,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo,
                                  size: 40,
                                  color: AppColors.textoSecundario.withOpacity(0.3),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Imagen no disponible',
                                  style: TextStyle(
                                    color: AppColors.textoSecundario.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 🏷️ BADGE DE EMPRESA (si aplica)
                  if (esEmpresa && producto.nombreEmpresa != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.acento.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.acento.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business, size: 12, color: AppColors.acento),
                          const SizedBox(width: 4),
                          Text(
                            producto.nombreEmpresa!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.acento,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // 📝 TÍTULO Y PRECIO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          producto.nombre,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primario,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 💰 PRECIO ANIMADO
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: producto.precio),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.acento.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.acento.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Bs. ${value.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.acento,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 📄 DESCRIPCIÓN
                  Text(
                    producto.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textoSecundario,
                      height: 1.4,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 💳 MÉTODO DE PAGO Y FECHA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 💳 CHIP DE PAGO ANIMADO
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(10 * (1 - value), 0),
                              child: _buildPaymentChip(producto.metodoCobro),
                            ),
                          );
                        },
                      ),
                      
                      // 📅 FECHA ANIMADA
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Text(
                              _formatDate(producto.fechaCreacion),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textoSecundario.withOpacity(0.6),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =============================================
  // FUNCIONES AUXILIARES
  // =============================================

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildPaymentChip(String metodoCobro) {
    String _getMetodoCobroText(String metodo) {
      switch (metodo) {
        case 'efectivo':
          return 'Efectivo';
        case 'qr':
          return 'QR';
        case 'ambos':
          return 'Efectivo o QR';
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getMetodoCobroColor(metodoCobro).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _getMetodoCobroColor(metodoCobro).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.payment,
            size: 14,
            color: _getMetodoCobroColor(metodoCobro),
          ),
          const SizedBox(width: 4),
          Text(
            _getMetodoCobroText(metodoCobro),
            style: TextStyle(
              fontSize: 12,
              color: _getMetodoCobroColor(metodoCobro),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomePage(),
          const PublishPage(),
          const ChatsListPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selectedIndex == 0) {
      return AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.shopping_bag,
                    color: AppColors.primario,
                    size: 28,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "UNIMARKET",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Comunidad Universitaria",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _mostrarFiltros ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _mostrarFiltros = !_mostrarFiltros;
              });
            },
            tooltip: 'Filtrar productos',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _cerrarSesion(context),
            tooltip: 'Cerrar Sesión',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primario,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar productos o empresas...',
                  hintStyle: TextStyle(color: AppColors.textoSecundario.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: AppColors.primario),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _searchQuery = value;
                    });
                  }
                },
              ),
            ),
          ),
        ),
      );
    } else {
      return AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.shopping_bag,
                    color: AppColors.primario,
                    size: 20,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                _getAppBarTitle(_selectedIndex),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _cerrarSesion(context),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      );
    }
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 1: return 'Publicar Producto';
      case 2: return 'Mensajes';
      case 3: return 'Mi Perfil';
      default: return 'UniMarket';
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Publicar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: 'Mensajes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}