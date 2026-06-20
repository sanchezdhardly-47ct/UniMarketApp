import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_colors.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? productName;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.productName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  
  bool _shouldAutoScroll = true;
  bool _isFirstLoad = true;

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final String _cloudinaryCloudName = 'dg1m1gslr';
  final String _uploadPreset = 'unimarket_ueb';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      
      if (maxScroll - currentScroll > 200) {
        _shouldAutoScroll = false;
      }
      
      if (currentScroll >= maxScroll - 50) {
        _shouldAutoScroll = true;
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _shouldAutoScroll) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String messageText) async {
    final user = _auth.currentUser;
    if (user == null || messageText.trim().isEmpty) {
      return;
    }

    try {
      final messageData = {
        'senderId': user.uid,
        'text': messageText.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': false,
        'messageType': 'text',
        'imageUrl': null,
      };

      final chatUpdateData = {
        'lastMessage': messageText.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();
      
      final messageRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();
      batch.set(messageRef, messageData);
      
      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      batch.update(chatRef, chatUpdateData);
      
      await batch.commit();

      _messageController.clear();
      _shouldAutoScroll = true;

    } catch (e) {
      print('❌ Error enviando mensaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al enviar mensaje'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _subirImagenACloudinary(File imageFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final responseJson = json.decode(responseData);
        return responseJson['secure_url'];
      } else {
        print('❌ Error Cloudinary: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error subiendo a Cloudinary: $e');
      return null;
    }
  }

  Future<void> _enviarImagen() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      File imageFile = File(image.path);
      
      String? downloadUrl = await _subirImagenACloudinary(imageFile);

      if (downloadUrl == null) {
        throw Exception('No se pudo obtener la URL de Cloudinary');
      }

      final messageData = {
        'senderId': user.uid,
        'text': '',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': false,
        'messageType': 'image',
        'imageUrl': downloadUrl,
      };

      final chatUpdateData = {
        'lastMessage': '📷 Imagen',
        'lastMessageTime': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();
      
      final messageRef = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();
      batch.set(messageRef, messageData);
      
      final chatRef = _firestore.collection('chats').doc(widget.chatId);
      batch.update(chatRef, chatUpdateData);
      
      await batch.commit();
      _shouldAutoScroll = true;

    } catch (e) {
      print('❌ Error enviando imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al enviar imagen'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildMessageItem(Message message) {
    final currentUser = _auth.currentUser;
    bool isMyMessage = message.senderId == currentUser?.uid;

    final alignment = isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isMyMessage ? AppColors.primario : Colors.grey[300];
    final textColor = isMyMessage ? Colors.white : Colors.black87;

    Widget messageContent;

    switch (message.messageType) {
      case 'image':
        messageContent = Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: 300,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message.imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: isMyMessage ? Colors.white : AppColors.primario,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Icon(Icons.broken_image, color: AppColors.error.withOpacity(0.6), size: 40),
                );
              },
            ),
          ),
        );
        break;
      
      case 'text':
      default:
        messageContent = Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Text(
            message.text,
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            padding: message.messageType == 'image' 
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: messageContent,
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(message.timestamp),
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.attach_file, 
              color: _isUploading ? Colors.grey : AppColors.primario
            ),
            onPressed: _isUploading ? null : _enviarImagen,
          ),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: 12,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _sendMessage(text);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, 
                  color: AppColors.primario,
                ),
              ),
            )
          else
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primario,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () {
                if (_messageController.text.trim().isNotEmpty) {
                  _sendMessage(_messageController.text);
                }
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ❌ ELIMINADO: AppBar
      body: Column(
        children: [
          // Información del chat en la parte superior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primario,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.otherUserName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.productName != null)
                        Text(
                          'Producto: ${widget.productName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de Mensajes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
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
                          'Error al cargar mensajes',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primario,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Inicia la conversación',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_isFirstLoad) {
                    _scrollToBottom();
                    _isFirstLoad = false;
                  } else if (_shouldAutoScroll) {
                    _scrollToBottom();
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final message = Message.fromFirestore(doc);
                    return _buildMessageItem(message);
                  },
                );
              },
            ),
          ),

          // Input de mensaje
          _buildMessageInput(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}