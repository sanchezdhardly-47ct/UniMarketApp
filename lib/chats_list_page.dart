import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_model.dart';
import 'chat_page.dart';
import 'app_colors.dart';

class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final Map<String, String> _userNameCache = {};

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return _buildUnauthenticatedState();
    }

    return Scaffold(
      // ❌ ELIMINADO: AppBar
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('❌ Error cargando chats: ${snapshot.error}');
            return _buildErrorState('Error al cargar chats');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final chats = snapshot.data!.docs
              .map((doc) => Chat.fromFirestore(doc))
              .toList();

          return _buildChatsList(chats, currentUser);
        },
      ),
    );
  }

  // ... (el resto de los métodos se mantienen igual)
  Widget _buildUnauthenticatedState() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Usuario no autenticado',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia sesión para ver tus mensajes',
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

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primario,
            ),
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
          CircularProgressIndicator(
            color: AppColors.primario,
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando chats...',
            style: TextStyle(
              color: Colors.grey[600],
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
            Icons.chat_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes mensajes aún',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando contactes a un vendedor\naparecerán aquí',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // No hacer nada - el HomePage maneja la navegación
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primario,
            ),
            child: const Text('Explorar Productos'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsList(List<Chat> chats, User currentUser) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return _buildChatItem(chat, currentUser);
      },
    );
  }

  Widget _buildChatItem(Chat chat, User currentUser) {
    final otherUsers = chat.participants.where((id) => id != currentUser.uid).toList();
    final isValidChat = otherUsers.isNotEmpty;
    final otherUserId = isValidChat ? otherUsers.first : null;

    if (!isValidChat) {
      return _buildInvalidChatItem(chat);
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _obtenerInfoOtroUsuario(otherUserId!, chat),
      builder: (context, snapshot) {
        final isReady = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
        final otherUserName = isReady ? snapshot.data!['nombre'] : 'Usuario';
        final otherUserEmail = isReady ? snapshot.data!['email'] : '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primario,
              child: Text(
                otherUserName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              otherUserName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.lastMessage.isNotEmpty 
                      ? chat.lastMessage 
                      : 'Nuevo chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                if (otherUserEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    otherUserEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatTime(chat.lastMessageTime.toDate()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (chat.productId != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.acento.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Producto',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.acento,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    chatId: chat.id,
                    otherUserId: otherUserId,
                    otherUserName: otherUserName,
                    productName: chat.productId != null ? 'Producto' : null,
                  ),
                ),
              );
            },
            onLongPress: () {
              _mostrarOpcionesChat(context, chat.id);
            },
          ),
        );
      },
    );
  }

  // ... (el resto de los métodos se mantienen igual)
  Future<Map<String, dynamic>> _obtenerInfoOtroUsuario(String otherUserId, Chat chat) async {
    if (_userNameCache.containsKey(otherUserId)) {
      return {
        'nombre': _userNameCache[otherUserId]!,
        'email': '',
      };
    }

    try {
      final nombreDelChat = chat.participantNames[otherUserId];
      if (nombreDelChat != null && nombreDelChat.isNotEmpty) {
        _userNameCache[otherUserId] = nombreDelChat;
        return {
          'nombre': nombreDelChat,
          'email': '',
        };
      }

      final userDoc = await _firestore.collection('users').doc(otherUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final nombre = userData['nombre'] ?? 'Usuario';
        final email = userData['email'] ?? '';
        
        _userNameCache[otherUserId] = nombre;
        return {
          'nombre': nombre,
          'email': email,
        };
      }

      final nombreGenerico = 'Usuario${otherUserId.substring(0, 4)}';
      _userNameCache[otherUserId] = nombreGenerico;
      return {
        'nombre': nombreGenerico,
        'email': '',
      };

    } catch (e) {
      print('❌ Error obteniendo info usuario $otherUserId: $e');
      return {
        'nombre': 'Usuario',
        'email': '',
      };
    }
  }

  Widget _buildInvalidChatItem(Chat chat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange[50],
      child: ListTile(
        leading: const Icon(Icons.warning, color: Colors.orange),
        title: const Text(
          'Chat no disponible',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.orange,
          ),
        ),
        subtitle: const Text(
          'Problema técnico - contactar soporte',
          style: TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _mostrarDialogoEliminarChat(chat.id),
          tooltip: 'Eliminar chat',
        ),
      ),
    );
  }

  void _mostrarOpcionesChat(BuildContext context, String chatId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar chat',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _mostrarDialogoEliminarChat(chatId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancelar'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoEliminarChat(String chatId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar chat'),
            ],
          ),
          content: const Text('¿Estás seguro de que quieres eliminar este chat? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  Navigator.pop(context);
                  
                  final batch = _firestore.batch();
                  final chatRef = _firestore.collection('chats').doc(chatId);
                  
                  final messagesSnapshot = await chatRef.collection('messages').get();
                  for (final doc in messagesSnapshot.docs) {
                    batch.delete(doc.reference);
                  }
                  
                  batch.delete(chatRef);
                  await batch.commit();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chat eliminado correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }

                } catch (e) {
                  print('❌ Error eliminando chat: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Ahora';
    }
  }

  @override
  void dispose() {
    _userNameCache.clear();
    super.dispose();
  }
}