import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quimisol_movil/core/services/notifications/fcm_token_service.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class AdminSupportChatPage extends StatefulWidget {
  final String chatId;
  final String? clientName;

  const AdminSupportChatPage({
    super.key,
    required this.chatId,
    this.clientName,
  });

  @override
  State<AdminSupportChatPage> createState() => _AdminSupportChatPageState();
}

class _AdminSupportChatPageState extends State<AdminSupportChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  bool _isTyping = false;
  bool _sending = false;

  String? _adminUid;
  String? _adminName;

  // Datos del ticket (se actualizan con snapshot)
  String _status = 'pending';
  String? _assignedSupportUid;
  String? _assignedSupportName;
  String _clientName = 'Cliente';

  // ✅ Para evitar parpadeos / no dejar scrollear
  int _lastMsgCount = 0;
  bool _userIsNearBottom = true;
  bool _forceScrollToBottomOnce = true; // al abrir
  bool _takingOnOpen = false; // evita doble “take”
  bool _greetingPrefilled = false; // evita re-escribir input

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      _db.collection('support_chats').doc(widget.chatId);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _chatRef.collection('messages');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final user = _auth.currentUser;
    _adminUid = user?.uid;
    _adminName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Soporte');

    if (widget.clientName != null && widget.clientName!.trim().isNotEmpty) {
      _clientName = widget.clientName!.trim();
    }

    _messageCtrl.addListener(() {
      final hasText = _messageCtrl.text.trim().isNotEmpty;
      if (hasText != _isTyping) setState(() => _isTyping = hasText);
    });

    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      final pos = _scrollCtrl.position.pixels;
      final near = (max - pos) < 180;
      if (near != _userIsNearBottom) setState(() => _userIsNearBottom = near);
    });

    // ✅ Asegura token FCM del admin al entrar al chat (por si aún no existe)
    // Esto permite que le llegue push cuando NO está en la pantalla.
    FcmTokenService.ensureTokenIfMissingForCurrentUser();

    // ✅ Marca presencia del soporte en este chat
    _setSupportChatPresence(true);

    _markSupportRead(); // una vez al abrir
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // no await en dispose
    _setSupportChatPresence(false);

    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // si la app se minimiza o pierde foco, ya no está "viendo" el chat
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setSupportChatPresence(false);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _setSupportChatPresence(true);
    }
  }

  Future<void> _setSupportChatPresence(bool isOpen) async {
    try {
      await _chatRef.set({
        'supportInChatPage': isOpen,
        'supportInChatPageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _markSupportRead() async {
    try {
      await _chatRef.set({
        'unreadCountSupport': 0,
        'lastReadAtSupport': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// ✅ Prefill del saludo EN EL INPUT (NO se envía solo)
  void _prefillGreetingMessage() {
    if (_messageCtrl.text.trim().isNotEmpty) return;
    if (_greetingPrefilled) return;

    final greeting =
        'Hola, soy ${_adminName ?? 'Soporte'}, ¿En qué puedo ayudarle?';

    _messageCtrl.text = greeting;
    _messageCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: greeting.length),
    );

    _greetingPrefilled = true;
    setState(() => _isTyping = true);

    _inputFocus.requestFocus();
  }

  /// ✅ Tomar ticket al abrir si NO tiene asignado
  Future<void> _takeTicketOnOpenIfNeeded() async {
    if (_takingOnOpen) return;
    if (_adminUid == null) return;

    _takingOnOpen = true;
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(_chatRef);
        if (!snap.exists) return;

        final data = snap.data() ?? {};
        final assignedUid = (data['assignedSupportUid'] ?? '').toString().trim();

        if (assignedUid.isEmpty) {
          tx.set(
            _chatRef,
            {
              'assignedSupportUid': _adminUid,
              'assignedSupportName': _adminName,
              'takenAt': FieldValue.serverTimestamp(),
              'status': 'in_progress',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });

      _prefillGreetingMessage();
    } catch (_) {
      // silencioso
    } finally {
      _takingOnOpen = false;
    }
  }

  /// ✅ Re-abrir si estaba completado y yo respondo
  Future<void> _ensureInProgressIfNeeded() async {
    if (_adminUid == null) return;

    await _chatRef.set({
      'status': 'in_progress',
      'updatedAt': FieldValue.serverTimestamp(),
      'assignedSupportUid': _adminUid,
      'assignedSupportName': _adminName,
      'completedAt': null,
      'completedByUid': null,
      'completedByName': null,
    }, SetOptions(merge: true));
  }

  Future<void> _sendTextMessage({required bool canReply}) async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    if (!canReply) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ticket está asignado a otro asesor.')),
      );
      return;
    }

    if (_adminUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión como admin.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      if (_status == 'completed') {
        await _ensureInProgressIfNeeded();
      }

      final msgRef = _messagesRef.doc();
      final batch = _db.batch();

      batch.set(msgRef, {
        'messageId': msgRef.id,
        'senderUid': _adminUid,
        'senderRole': 'support',
        'senderName': _adminName ?? 'Soporte',
        'type': 'text',
        'text': text,
        'imageUrl': null,
        'storagePath': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'readAt': null,
        'status': 'sent',
      });

      batch.set(
        _chatRef,
        {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': text,
          'lastMessageType': 'text',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'status': 'in_progress',
          'unreadCountClient': FieldValue.increment(1),
          'assignedSupportUid': _adminUid,
          'assignedSupportName': _adminName,
          'lastReadAtSupport': FieldValue.serverTimestamp(),
          'completedAt': null,
          'completedByUid': null,
          'completedByName': null,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      _messageCtrl.clear();
      _greetingPrefilled = false;
      _scrollToBottom(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar el mensaje: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage({required bool canReply}) async {
    if (_sending) return;

    if (!canReply) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este ticket está asignado a otro asesor.')),
      );
      return;
    }

    if (_adminUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión como admin.')),
      );
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;

      setState(() => _sending = true);

      if (_status == 'completed') {
        await _ensureInProgressIfNeeded();
      }

      final msgRef = _messagesRef.doc();
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';

      final storagePath = 'support_chats/${widget.chatId}/${msgRef.id}.$ext';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: 'image/$ext',
            customMetadata: {
              'chatId': widget.chatId,
              'messageId': msgRef.id,
              'senderUid': _adminUid!,
              'senderRole': 'support',
            },
          ),
        );
      } else {
        uploadTask = storageRef.putFile(
          File(file.path),
          SettableMetadata(
            contentType: 'image/$ext',
            customMetadata: {
              'chatId': widget.chatId,
              'messageId': msgRef.id,
              'senderUid': _adminUid!,
              'senderRole': 'support',
            },
          ),
        );
      }

      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      final batch = _db.batch();

      batch.set(msgRef, {
        'messageId': msgRef.id,
        'senderUid': _adminUid,
        'senderRole': 'support',
        'senderName': _adminName ?? 'Soporte',
        'type': 'image',
        'text': null,
        'imageUrl': imageUrl,
        'storagePath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'readAt': null,
        'status': 'sent',
      });

      batch.set(
        _chatRef,
        {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': '📷 Imagen',
          'lastMessageType': 'image',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'status': 'in_progress',
          'unreadCountClient': FieldValue.increment(1),
          'assignedSupportUid': _adminUid,
          'assignedSupportName': _adminName,
          'lastReadAtSupport': FieldValue.serverTimestamp(),
          'completedAt': null,
          'completedByUid': null,
          'completedByName': null,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      _scrollToBottom(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la imagen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markCompleted() async {
    if (_adminUid == null) return;

    try {
      await _chatRef.set({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completedByUid': _adminUid,
        'completedByName': _adminName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final msgRef = _messagesRef.doc();
      await msgRef.set({
        'messageId': msgRef.id,
        'senderUid': _adminUid,
        'senderRole': 'system',
        'senderName': 'Sistema',
        'type': 'system',
        'text': '✅ El ticket fue marcado como completado por soporte.',
        'imageUrl': null,
        'storagePath': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'readAt': null,
        'status': 'sent',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket marcado como completado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo completar el ticket: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (!force && !_userIsNearBottom) return;

      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 140,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chatRef.snapshots(),
      builder: (context, chatSnap) {
        final chatData = chatSnap.data?.data() ?? {};

        _status = (chatData['status'] ?? 'pending').toString();
        _assignedSupportUid =
            (chatData['assignedSupportUid'] ?? '').toString().trim();
        _assignedSupportName =
            (chatData['assignedSupportName'] ?? '').toString().trim().isEmpty
                ? null
                : chatData['assignedSupportName'].toString();
        _clientName = (chatData['clientName'] ?? _clientName).toString();

        final bool assignedToOther = _assignedSupportUid != null &&
            _assignedSupportUid!.isNotEmpty &&
            _adminUid != null &&
            _assignedSupportUid != _adminUid;

        // ✅ Otros admins ven pero NO hablan mientras esté asignado
        final bool canReply = !assignedToOther;

        // ✅ Si NO tiene asignado, lo tomamos al abrir (una vez)
        if ((_assignedSupportUid == null || _assignedSupportUid!.isEmpty) &&
            !_takingOnOpen &&
            chatSnap.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _takeTicketOnOpenIfNeeded();
          });
        }

        return Scaffold(
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
                  backgroundColor: Palette.button.withOpacity(0.14),
                  child: Text(
                    _initials(_clientName),
                    style: const TextStyle(
                      color: Palette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Palette.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel(_status, assignedToOther: assignedToOther),
                        style: TextStyle(
                          color: _statusColor(_status, assignedToOther: assignedToOther),
                          fontSize: 11.4,
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
                tooltip: 'Marcar completado',
                onPressed: (_status == 'completed' || !canReply)
                    ? null
                    : _markCompleted,
                icon: const Icon(Icons.check_circle_outline_rounded),
                color: Colors.green,
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Palette.button.withOpacity(0.20)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Palette.primary.withOpacity(0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assignedToOther
                            ? 'Este ticket está siendo atendido por ${_assignedSupportName ?? 'otro asesor'}.'
                            : (_status == 'completed'
                                ? 'Ticket completado. Si respondes, se reabre.'
                                : 'Respondiendo como ${_adminName ?? 'Soporte'}.'),
                        style: const TextStyle(
                          fontSize: 12.2,
                          color: Palette.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesRef
                      .orderBy('createdAt', descending: false)
                      .limit(300)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: Palette.primary),
                      );
                    }

                    if (snap.hasError) {
                      return const Center(
                        child: Text('No se pudieron cargar los mensajes'),
                      );
                    }

                    final docs = snap.data?.docs ?? [];

                    final newCount = docs.length;
                    final hasNewMessages = newCount > _lastMsgCount;
                    _lastMsgCount = newCount;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (hasNewMessages) _markSupportRead();

                      if (_forceScrollToBottomOnce) {
                        _forceScrollToBottomOnce = false;
                        _scrollToBottom(force: true);
                      } else if (hasNewMessages) {
                        _scrollToBottom(force: false);
                      }
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'Sin mensajes todavía',
                          style: TextStyle(
                            color: Palette.ink.withOpacity(0.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final d = docs[index].data();
                        final senderRole = (d['senderRole'] ?? '').toString();
                        final type = (d['type'] ?? 'text').toString();
                        final text = (d['text'] ?? '').toString();
                        final imageUrl = (d['imageUrl'] ?? '').toString();

                        final ts = d['createdAt'];
                        DateTime? dt;
                        if (ts is Timestamp) dt = ts.toDate();

                        final isMine = senderRole == 'support';
                        final isSystem = senderRole == 'system';

                        return _AdminMessageBubble(
                          isMine: isMine,
                          isSystem: isSystem,
                          type: type,
                          text: text,
                          imageUrl: imageUrl,
                          time: _fmtTime(dt),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: Palette.white,
                    border: Border(
                      top: BorderSide(
                        color: Palette.button.withOpacity(0.18),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
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
                            color: canReply ? Palette.fieldBg : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Palette.button.withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageCtrl,
                                  focusNode: _inputFocus,
                                  enabled: canReply && !_sending,
                                  minLines: 1,
                                  maxLines: 4,
                                  textCapitalization: TextCapitalization.sentences,
                                  onSubmitted: (_) => _sendTextMessage(canReply: canReply),
                                  decoration: InputDecoration(
                                    hintText: assignedToOther
                                        ? 'Ticket asignado a otro asesor'
                                        : 'Responder al cliente...',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: (canReply && !_sending)
                                    ? () => _pickAndSendImage(canReply: canReply)
                                    : null,
                                icon: Icon(
                                  Icons.attach_file_rounded,
                                  color: canReply
                                      ? Palette.primary.withOpacity(0.8)
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (_isTyping && canReply && !_sending)
                              ? Palette.button
                              : Palette.button.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Palette.button.withOpacity(0.85),
                            width: 1.4,
                          ),
                        ),
                        child: IconButton(
                          onPressed: (_isTyping && canReply && !_sending)
                              ? () => _sendTextMessage(canReply: canReply)
                              : null,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Palette.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static String _statusLabel(String status, {required bool assignedToOther}) {
    if (assignedToOther) return 'Atendido por otro asesor';
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'in_progress':
        return 'En atención';
      case 'completed':
        return 'Completado';
      default:
        return 'Soporte';
    }
  }

  static Color _statusColor(String status, {required bool assignedToOther}) {
    if (assignedToOther) return Colors.deepOrange;
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Palette.primary;
    }
  }
}

class _AdminMessageBubble extends StatelessWidget {
  final bool isMine;
  final bool isSystem;
  final String type;
  final String text;
  final String imageUrl;
  final String time;

  const _AdminMessageBubble({
    required this.isMine,
    required this.isSystem,
    required this.type,
    required this.text,
    required this.imageUrl,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isSystem
        ? Palette.fieldBg
        : (isMine ? Palette.button.withOpacity(0.92) : Palette.white);

    final textColor = isMine ? Palette.white : Palette.ink;

    return Align(
      alignment: isSystem
          ? Alignment.center
          : (isMine ? Alignment.centerRight : Alignment.centerLeft),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isSystem
                ? MediaQuery.of(context).size.width * 0.88
                : MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              9,
              10,
              type == 'text' || type == 'system' ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              border: isSystem
                  ? Border.all(color: Palette.button.withOpacity(0.12))
                  : (isMine
                      ? null
                      : Border.all(color: Palette.button.withOpacity(0.18))),
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (type == 'image' && imageUrl.isNotEmpty)
                  _RemoteImageView(imageUrl: imageUrl)
                else
                  Text(
                    text,
                    style: TextStyle(
                      color: isSystem ? Palette.primary : textColor,
                      fontSize: isSystem ? 13 : 15.5,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: isMine
                        ? Palette.white.withOpacity(0.9)
                        : Palette.ink.withOpacity(0.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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

class _RemoteImageView extends StatelessWidget {
  final String imageUrl;

  const _RemoteImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 140,
          maxWidth: 240,
          minHeight: 120,
          maxHeight: 260,
        ),
        color: Colors.black.withOpacity(0.05),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 180,
            height: 140,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_rounded, size: 34),
          ),
        ),
      ),
    );
  }
}