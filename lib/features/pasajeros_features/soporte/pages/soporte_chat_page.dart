import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quimisol_movil/core/services/notifications/fcm_token_service.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class SoporteChatPage extends StatefulWidget {
  const SoporteChatPage({super.key});

  @override
  State<SoporteChatPage> createState() => _SoporteChatPageState();
}

class _SoporteChatPageState extends State<SoporteChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();

  final List<_ChatMessage> _messages = [];

  bool _isTyping = false;
  bool _showEmojiPicker = false;

  // Flujo soporte cliente
  bool _awaitingOpenTicketAnswer = false;
  bool _chatCreated = false;
  bool _chatRejected = false;
  bool _creatingChat = false;
  bool _loadingChat = true;

  String? _chatId;
  String? _clientUid;
  String? _clientName;
  String? _clientEmail;
  String? _chatStatus;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  final List<String> _emojis = const [
    '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😎', '🤗', '🤔',
    '😢', '😭', '😡', '😴', '🙌', '👏', '👍', '👎', '💪', '🙏',
    '🔥', '💯', '✨', '🎉', '❤️', '💙', '💚', '🧡', '💛', '🤍',
    '🚚', '📦', '🛒', '💳', '📍', '📞', '📷', '⚠️', '✅', '❌',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final user = _auth.currentUser;
    _clientUid = user?.uid;
    _clientName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'Cliente';
    _clientEmail = user?.email;

    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });

    _bootstrapChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // no await en dispose
    _setClientChatPresence(false);

    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la app se minimiza o pierde foco, ya no está "viendo" esta página
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setClientChatPresence(false);
      return;
    }

    // Si vuelve a primer plano, marcar presencia
    if (state == AppLifecycleState.resumed) {
      _setClientChatPresence(true);
    }
  }

  Future<void> _setClientChatPresence(bool isOpen) async {
    if (_chatId == null || _clientUid == null) return;

    try {
      await _db.collection('support_chats').doc(_chatId).set({
        'clientInSupportChatPage': isOpen,
        'clientInSupportChatPageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // silencioso para no romper UI
    }
  }

  Future<void> _bootstrapChat() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _loadingChat = false;
          _chatRejected = true;
          _messages
            ..clear()
            ..add(
              _ChatMessage.text(
                text: 'Debes iniciar sesión para usar soporte.',
                isMine: false,
                time: _formatNow(),
              ),
            );
        });
        return;
      }

      _chatId = 'chat_${user.uid}';
      final chatRef = _db.collection('support_chats').doc(_chatId);
      final chatSnap = await chatRef.get();

      if (chatSnap.exists) {
        final data = chatSnap.data() ?? {};
        _chatStatus = (data['status'] ?? '').toString();

        _chatCreated = true;
        _awaitingOpenTicketAnswer = false;
        _chatRejected = false;

        await _loadMessagesFromFirestore();
        await _setClientChatPresence(true);

        setState(() {
          _loadingChat = false;
        });

        _scrollToBottom();
        return;
      }

      // No existe ticket: crear pre-chat persistido en Firestore
      await _createPendingChatWithPreMessages();

      await _loadMessagesFromFirestore();
      await _setClientChatPresence(true);

      setState(() {
        _chatCreated = true; // ya existe doc de ticket (pendiente de confirmación)
        _awaitingOpenTicketAnswer = true;
        _chatRejected = false;
        _chatStatus = 'draft';
        _loadingChat = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _loadingChat = false;
        _messages
          ..clear()
          ..add(
            _ChatMessage.text(
              text: '❌ No se pudo cargar el chat de soporte.',
              isMine: false,
              time: _formatNow(),
            ),
          );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando soporte: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _loadMessagesFromFirestore() async {
    if (_chatId == null) return;

    final query = await _db
        .collection('support_chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .get();

    final loaded = <_ChatMessage>[];
    bool hasOpenQuestion = false;

    for (final doc in query.docs) {
      final d = doc.data();
      final type = (d['type'] ?? 'text').toString();
      final senderRole = (d['senderRole'] ?? '').toString();
      final isMine = senderRole == 'client';

      final ts = d['createdAt'];
      String time = _formatNow();
      if (ts is Timestamp) {
        final dt = ts.toDate();
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        time = '$hh:$mm';
      }

      if (type == 'image') {
        final imageUrl = (d['imageUrl'] ?? '').toString();
        if (imageUrl.isNotEmpty) {
          loaded.add(
            _ChatMessage.image(
              imagePath: imageUrl,
              isMine: isMine,
              time: time,
              isRemoteImage: true,
            ),
          );
        }
      } else {
        final text = (d['text'] ?? '').toString();
        if (text.isNotEmpty) {
          final metaType = (d['metaType'] ?? '').toString();

          if (metaType == 'open_ticket_question') {
            hasOpenQuestion = true;
          }

          loaded.add(
            _ChatMessage.text(
              text: text,
              isMine: isMine,
              time: time,
              isBotQuestion: metaType == 'open_ticket_question',
              isBotAnswer: metaType == 'open_ticket_answer',
            ),
          );
        }
      }
    }

    setState(() {
      _messages
        ..clear()
        ..addAll(loaded);
    });

    // Reconstruir estado del flujo según metadata del chat
    final chatDoc = await _db.collection('support_chats').doc(_chatId).get();
    final data = chatDoc.data() ?? {};
    final status = (data['status'] ?? '').toString();
    _chatStatus = status;

    _awaitingOpenTicketAnswer = status == 'draft' && hasOpenQuestion;
    _chatRejected = status == 'cancelled_by_client';
    _chatCreated = true;
  }

  String _formatNow() {
    final now = TimeOfDay.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _addSystemMessage({
    required String text,
    required String metaType,
    bool countAsLastMessage = false,
  }) async {
    if (_chatId == null) return;

    final chatRef = _db.collection('support_chats').doc(_chatId);
    final msgRef = chatRef.collection('messages').doc();

    final batch = _db.batch();

    batch.set(msgRef, {
      'messageId': msgRef.id,
      'senderUid': 'system',
      'senderRole': 'system',
      'senderName': 'Soporte Quimisol',
      'type': 'text',
      'metaType': metaType,
      'text': text,
      'imageUrl': null,
      'storagePath': null,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
      'status': 'sent',
    });

    batch.set(
      chatRef,
      {
        'updatedAt': FieldValue.serverTimestamp(),
        if (countAsLastMessage) ...{
          'lastMessage': text,
          'lastMessageType': 'text',
          'lastMessageAt': FieldValue.serverTimestamp(),
        }
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> _addClientTextMessage({
    required String text,
    required String metaType,
  }) async {
    if (_chatId == null || _clientUid == null) return;

    final chatRef = _db.collection('support_chats').doc(_chatId);
    final msgRef = chatRef.collection('messages').doc();

    await msgRef.set({
      'messageId': msgRef.id,
      'senderUid': _clientUid,
      'senderRole': 'client',
      'senderName': _clientName ?? 'Cliente',
      'type': 'text',
      'metaType': metaType,
      'text': text,
      'imageUrl': null,
      'storagePath': null,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'readAt': null,
      'status': 'sent',
    });
  }

  Future<void> _createPendingChatWithPreMessages() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para abrir soporte.');
    }

    _clientUid = user.uid;
    _clientName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : 'Cliente';
    _clientEmail = user.email;

    final chatId = 'chat_${user.uid}';
    _chatId = chatId;

    final chatRef = _db.collection('support_chats').doc(chatId);

    await chatRef.set({
      'chatId': chatId,
      'clientUid': user.uid,
      'clientName': _clientName,
      'clientEmail': _clientEmail,
      'clientPhotoUrl': user.photoURL,
      'status': 'draft',
      'priority': 'normal',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageType': null,
      'lastMessageAt': null,
      'unreadCountClient': 0,
      'unreadCountSupport': 0,
      'assignedSupportUid': null,
      'assignedSupportName': null,
      'takenAt': null,
      'completedAt': null,
      'completedByUid': null,
      'completedByName': null,
      'source': 'app_cliente',
      'isActive': true,
      'lastReadAtClient': FieldValue.serverTimestamp(),
      'lastReadAtSupport': null,
      // Presence flags
      'clientInSupportChatPage': false,
      'clientInSupportChatPageAt': null,
      'supportInChatPage': false,
      'supportInChatPageAt': null,
    }, SetOptions(merge: true));

    await _addSystemMessage(
      text: 'Hola 👋 Bienvenido a soporte de Quimisol.',
      metaType: 'welcome',
      countAsLastMessage: false,
    );

    await _addSystemMessage(
      text: 'Antes de continuar, ¿deseas abrir un ticket de soporte con un asesor?',
      metaType: 'open_ticket_question',
      countAsLastMessage: false,
    );
  }

  void _handleTyping(String v) {
    final hasText = v.trim().isNotEmpty;
    if (hasText != _isTyping) {
      setState(() => _isTyping = hasText);
    }
  }

  void _toggleEmojiPicker() {
    final canUse = _chatStatus == 'pending' ||
        _chatStatus == 'in_progress' ||
        _chatStatus == 'completed';

    if (!canUse) return;

    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _inputFocus.requestFocus();
    } else {
      _inputFocus.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _insertEmoji(String emoji) {
    final text = _messageCtrl.text;
    final selection = _messageCtrl.selection;

    final int start = selection.start >= 0 ? selection.start : text.length;
    final int end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;

    _messageCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );

    _handleTyping(newText);
  }

  void _backspaceEmojiOrText() {
    final text = _messageCtrl.text;
    final selection = _messageCtrl.selection;

    if (text.isEmpty) return;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    if (start != end) {
      final newText = text.replaceRange(start, end, '');
      _messageCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
      _handleTyping(newText);
      return;
    }

    if (start == 0) return;

    final newStart = start - 1;
    final newText = text.replaceRange(newStart, start, '');
    _messageCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newStart),
    );
    _handleTyping(newText);
  }

  Future<void> _onBotAnswerOpenTicket(bool yes) async {
    if (!_awaitingOpenTicketAnswer || _creatingChat) return;

    final answerText = yes ? 'Sí' : 'No';

    setState(() {
      _messages.add(
        _ChatMessage.text(
          text: answerText,
          isMine: true,
          time: _formatNow(),
          isBotAnswer: true,
        ),
      );
      _awaitingOpenTicketAnswer = false;
      _creatingChat = yes;
    });
    _scrollToBottom();

    try {
      await _addClientTextMessage(
        text: answerText,
        metaType: 'open_ticket_answer',
      );

      final chatRef = _db.collection('support_chats').doc(_chatId);

      if (!yes) {
        await chatRef.set({
          'status': 'cancelled_by_client',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': 'No',
          'lastMessageType': 'text',
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _addSystemMessage(
          text: 'Perfecto 👍 No se abrió ningún ticket.',
          metaType: 'ticket_not_created_info',
          countAsLastMessage: false,
        );

        await _loadMessagesFromFirestore();

        setState(() {
          _chatRejected = true;
          _creatingChat = false;
        });

        _scrollToBottom();
        return;
      }

      // ✅ Asegurar token FCM solo si aún no existe
      await FcmTokenService.ensureTokenIfMissingForCurrentUser();

      await chatRef.set({
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Sí',
        'lastMessageType': 'text',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastReadAtClient': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _addSystemMessage(
        text:
            '✅ Tu ticket fue creado correctamente.\nUn asesor te responderá pronto. Por favor espera unos minutos.',
        metaType: 'ticket_created_info',
        countAsLastMessage: false,
      );

      await _loadMessagesFromFirestore();
      await _setClientChatPresence(true);

      if (!mounted) return;
      setState(() {
        _chatCreated = true;
        _creatingChat = false;
        _chatStatus = 'pending';
        _chatRejected = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      try {
        await _addSystemMessage(
          text: '❌ No se pudo crear el ticket. Intenta nuevamente más tarde.',
          metaType: 'ticket_create_error',
          countAsLastMessage: false,
        );
        await _loadMessagesFromFirestore();
      } catch (_) {}

      setState(() {
        _creatingChat = false;
        _chatRejected = true;
      });

      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creando ticket: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final canSend = _chatStatus == 'pending' ||
        _chatStatus == 'in_progress' ||
        _chatStatus == 'completed';

    if (!canSend || _chatId == null || _clientUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero responde Sí para abrir el ticket.')),
      );
      return;
    }

    if (_chatStatus == 'completed') {
      _chatStatus = 'pending';
    }

    setState(() {
      _messages.add(
        _ChatMessage.text(
          text: text,
          isMine: true,
          time: _formatNow(),
        ),
      );
      _messageCtrl.clear();
      _isTyping = false;
    });

    _scrollToBottom();

    try {
      final chatRef = _db.collection('support_chats').doc(_chatId);
      final msgRef = chatRef.collection('messages').doc();

      final batch = _db.batch();

      batch.set(msgRef, {
        'messageId': msgRef.id,
        'senderUid': _clientUid,
        'senderRole': 'client',
        'senderName': _clientName ?? 'Cliente',
        'type': 'text',
        'metaType': 'client_message',
        'text': text,
        'imageUrl': null,
        'storagePath': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'readAt': null,
        'status': 'sent',
      });

      batch.set(
        chatRef,
        {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': text,
          'lastMessageType': 'text',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCountSupport': FieldValue.increment(1),
          'status': 'pending',
          'lastReadAtClient': FieldValue.serverTimestamp(),
          'completedAt': null,
          'completedByUid': null,
          'completedByName': null,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      setState(() => _chatStatus = 'pending');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar el mensaje: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final canSend = _chatStatus == 'pending' ||
        _chatStatus == 'in_progress' ||
        _chatStatus == 'completed';

    if (!canSend || _chatId == null || _clientUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero responde Sí para abrir el ticket.')),
      );
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (file == null) return;

      setState(() {
        _messages.add(
          _ChatMessage.image(
            imagePath: file.path,
            isMine: true,
            time: _formatNow(),
            isRemoteImage: false,
          ),
        );
      });
      _scrollToBottom();

      final chatRef = _db.collection('support_chats').doc(_chatId);
      final msgRef = chatRef.collection('messages').doc();

      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';

      final storagePath = 'support_chats/$_chatId/${msgRef.id}.$ext';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: 'image/$ext',
            customMetadata: {
              'chatId': _chatId!,
              'messageId': msgRef.id,
              'senderUid': _clientUid!,
              'senderRole': 'client',
            },
          ),
        );
      } else {
        uploadTask = storageRef.putFile(
          File(file.path),
          SettableMetadata(
            contentType: 'image/$ext',
            customMetadata: {
              'chatId': _chatId!,
              'messageId': msgRef.id,
              'senderUid': _clientUid!,
              'senderRole': 'client',
            },
          ),
        );
      }

      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      final batch = _db.batch();

      batch.set(msgRef, {
        'messageId': msgRef.id,
        'senderUid': _clientUid,
        'senderRole': 'client',
        'senderName': _clientName ?? 'Cliente',
        'type': 'image',
        'metaType': 'client_image',
        'text': null,
        'imageUrl': imageUrl,
        'storagePath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'readAt': null,
        'status': 'sent',
      });

      batch.set(
        chatRef,
        {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '📷 Imagen',
          'lastMessageType': 'image',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCountSupport': FieldValue.increment(1),
          'status': 'pending',
          'lastReadAtClient': FieldValue.serverTimestamp(),
          'completedAt': null,
          'completedByUid': null,
          'completedByName': null,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      setState(() => _chatStatus = 'pending');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la imagen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  bool get _inputEnabled {
    final canSend = _chatStatus == 'pending' ||
        _chatStatus == 'in_progress' ||
        _chatStatus == 'completed';
    return canSend && !_creatingChat && !_loadingChat;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Palette.fieldBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Palette.white,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: Palette.primary,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Palette.button.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Palette.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Soporte Quimisol',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Palette.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _loadingChat
                          ? 'Cargando...'
                          : (_chatStatus == 'in_progress'
                              ? 'En atención'
                              : _chatStatus == 'completed'
                                  ? 'Completado'
                                  : _chatStatus == 'pending'
                                      ? 'Ticket pendiente'
                                      : _chatStatus == 'draft'
                                          ? 'Pre-chat'
                                          : _creatingChat
                                              ? 'Creando ticket...'
                                              : 'Pre-chat'),
                      style: TextStyle(
                        color: _chatStatus == 'completed'
                            ? Colors.green
                            : _chatStatus == 'in_progress'
                                ? Colors.blue
                                : _chatStatus == 'pending'
                                    ? Colors.orange
                                    : Palette.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loadingChat ? null : _bootstrapChat,
              icon: const Icon(Icons.refresh_rounded),
              color: Palette.primary,
            ),
          ],
        ),
        body: _loadingChat
            ? Center(
                child: CircularProgressIndicator(color: Palette.primary),
              )
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Palette.button.withValues(alpha: 0.20)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Palette.primary.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _chatStatus == 'draft'
                                ? 'Primero responde Sí o No para continuar.'
                                : _chatStatus == 'cancelled_by_client'
                                    ? 'No se abrió ticket. Si deseas soporte, vuelve a responder Sí.'
                                    : _chatStatus == 'completed'
                                        ? 'Este ticket está completado. Si envías un mensaje, se reabrirá.'
                                        : _chatStatus == 'in_progress'
                                            ? 'Tu ticket está siendo atendido por soporte.'
                                            : 'Tu ticket está pendiente de atención.',
                            style: const TextStyle(
                              fontSize: 12.3,
                              color: Palette.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final showYesNo =
                            msg.isBotQuestion && _awaitingOpenTicketAnswer && !_creatingChat;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MessageBubble(message: msg),
                            if (showYesNo)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 6,
                                  right: 6,
                                  bottom: 10,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _QuickReplyButton(
                                      label: 'Sí',
                                      icon: Icons.check_circle_outline,
                                      color: Colors.green,
                                      onTap: () => _onBotAnswerOpenTicket(true),
                                    ),
                                    _QuickReplyButton(
                                      label: 'No',
                                      icon: Icons.cancel_outlined,
                                      color: Colors.redAccent,
                                      onTap: () => _onBotAnswerOpenTicket(false),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_creatingChat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Palette.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Creando ticket...',
                            style: TextStyle(
                              color: Palette.primary.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          decoration: BoxDecoration(
                            color: Palette.white,
                            border: Border(
                              top: BorderSide(
                                color: Palette.button.withValues(alpha: 0.18),
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _inputEnabled
                                        ? Palette.fieldBg
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Palette.button.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: _inputEnabled ? _toggleEmojiPicker : null,
                                        icon: Icon(
                                          _showEmojiPicker
                                              ? Icons.keyboard_rounded
                                              : Icons.sentiment_satisfied_alt_rounded,
                                          color: _inputEnabled
                                              ? Palette.primary.withValues(alpha: 0.8)
                                              : Colors.grey,
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _messageCtrl,
                                          focusNode: _inputFocus,
                                          enabled: _inputEnabled,
                                          minLines: 1,
                                          maxLines: 4,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          onChanged: _handleTyping,
                                          onTap: () {
                                            if (_showEmojiPicker) {
                                              setState(() => _showEmojiPicker = false);
                                            }
                                          },
                                          onSubmitted: (_) => _sendMessage(),
                                          decoration: InputDecoration(
                                            hintText: _inputEnabled
                                                ? 'Escribe tu mensaje...'
                                                : 'Primero responde Sí/No',
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _inputEnabled ? _pickAndSendImage : null,
                                        icon: Icon(
                                          Icons.attach_file_rounded,
                                          color: _inputEnabled
                                              ? Palette.primary.withValues(alpha: 0.8)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: (_isTyping && _inputEnabled)
                                      ? Palette.button
                                      : Palette.button.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Palette.button.withValues(alpha: 0.85),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: (_isTyping && _inputEnabled) ? _sendMessage : null,
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: Palette.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showEmojiPicker && _inputEnabled)
                          _SimpleEmojiPanel(
                            emojis: _emojis,
                            onEmojiTap: _insertEmoji,
                            onBackspace: _backspaceEmojiOrText,
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

class _QuickReplyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickReplyButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleEmojiPanel extends StatelessWidget {
  final List<String> emojis;
  final ValueChanged<String> onEmojiTap;
  final VoidCallback onBackspace;

  const _SimpleEmojiPanel({
    required this.emojis,
    required this.onEmojiTap,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      color: Palette.white,
      child: Column(
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Palette.button.withValues(alpha: 0.12)),
                bottom: BorderSide(color: Palette.button.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Emojis',
                  style: TextStyle(
                    color: Palette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onBackspace,
                  icon: Icon(
                    Icons.backspace_outlined,
                    color: Palette.primary.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                final emoji = emojis[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onEmojiTap(emoji),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final isSystem = !isMine && (message.isBotQuestion || (!isMine && !message.isRemoteImage));

    final bubbleColor = isMine
        ? Palette.button.withValues(alpha: 0.92)
        : (isSystem ? Colors.white : Palette.white);

    final textColor = isMine ? Palette.white : Palette.ink;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              9,
              10,
              message.type == _MessageType.text ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              border: isMine
                  ? null
                  : Border.all(
                      color: Palette.button.withValues(alpha: 0.18),
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (message.type == _MessageType.text)
                  Text(
                    message.text ?? '',
                    softWrap: true,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (message.type == _MessageType.image) ...[
                  _ChatImageView(message: message),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.time,
                      style: TextStyle(
                        color: isMine
                            ? Palette.white.withValues(alpha: 0.9)
                            : Palette.ink.withValues(alpha: 0.55),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: Palette.white.withValues(alpha: 0.92),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatImageView extends StatelessWidget {
  final _ChatMessage message;

  const _ChatImageView({required this.message});

  @override
  Widget build(BuildContext context) {
    final path = message.imagePath ?? '';

    final Widget imageWidget = message.isRemoteImage
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageErrorBox(),
          )
        : (kIsWeb
            ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imageErrorBox(),
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imageErrorBox(),
              ));

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 140,
          maxWidth: 240,
          minHeight: 120,
          maxHeight: 260,
        ),
        color: Colors.black.withValues(alpha: 0.05),
        child: imageWidget,
      ),
    );
  }

  Widget _imageErrorBox() {
    return Container(
      width: 180,
      height: 140,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_rounded, size: 34),
    );
  }
}

enum _MessageType { text, image }

class _ChatMessage {
  final String? text;
  final String? imagePath;
  final bool isMine;
  final String time;
  final _MessageType type;

  final bool isBotQuestion;
  final bool isBotAnswer;
  final bool isRemoteImage;

  _ChatMessage.text({
    required String text,
    required this.isMine,
    required this.time,
    this.isBotQuestion = false,
    this.isBotAnswer = false,
  })  : text = text,
        imagePath = null,
        type = _MessageType.text,
        isRemoteImage = false;

  _ChatMessage.image({
    required String imagePath,
    required this.isMine,
    required this.time,
    this.isRemoteImage = false,
  })  : text = null,
        imagePath = imagePath,
        type = _MessageType.image,
        isBotQuestion = false,
        isBotAnswer = false;
}