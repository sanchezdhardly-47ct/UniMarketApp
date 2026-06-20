import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String lastMessage;
  final Timestamp lastMessageTime;
  final String? productId; // Para saber de qué producto viene el chat

  Chat({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.lastMessage,
    required this.lastMessageTime,
    this.productId,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Chat(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      productId: data['productId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantNames': participantNames,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'productId': productId,
    };
  }
}

class Message {
  final String id;
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final bool isSystemMessage;
  
  // 🔽 CAMPOS NUEVOS
  final String messageType; // 'text' o 'image'
  final String? imageUrl;   // URL de la imagen (opcional)

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isSystemMessage = false,
    
    // 🔽 Valores por defecto para los campos nuevos
    this.messageType = 'text', 
    this.imageUrl,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isSystemMessage: data['isSystemMessage'] ?? false,
      
      // 🔽 Leer los campos nuevos
      messageType: data['messageType'] ?? 'text',
      imageUrl: data['imageUrl'],
    );
  }

  // 🔽 NUEVO: Método toMap para crear mensajes
  // (No lo tenías, pero es útil para escribir en Firestore)
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isSystemMessage': isSystemMessage,
      'messageType': messageType,
      'imageUrl': imageUrl,
    };
  }
}