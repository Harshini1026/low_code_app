import 'package:flutter/material.dart';
import '../services/ai_chat_service.dart';

enum ChatStatus { idle, thinking }

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatProvider extends ChangeNotifier {
  final AiChatService _service = AiChatService();

  final List<ChatMessage> _messages = [];
  ChatStatus _status = ChatStatus.idle;
  bool _hasNewSuggestion = false;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatStatus get status => _status;
  bool get isThinking => _status == ChatStatus.thinking;
  bool get hasNewSuggestion => _hasNewSuggestion;
  bool get isEmpty => _messages.isEmpty;

  // ── Init with welcome message ─────────────────────────────────────────────
  ChatProvider() {
    _addBotMessage(
      "👋 Hi! I'm your AppForge AI assistant.\n\n"
      "I can help you:\n"
      "• Add and customize widgets\n"
      "• Set up your Firebase database\n"
      "• Bind data to your UI\n"
      "• Publish your app\n\n"
      "What would you like to build today?",
    );
  }

  // ── Send user message ─────────────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    _messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _status = ChatStatus.thinking;
    notifyListeners();

    // Simulate thinking delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Get AI response — getResponse() is synchronous, no await
    final response = _service.getResponse(text);
    _addBotMessage(response);

    _status = ChatStatus.idle;
    _hasNewSuggestion = true;
    notifyListeners();
  }

  // ── Quick reply shortcut ──────────────────────────────────────────────────
  Future<void> sendQuickReply(String text) => sendMessage(text);

  // ── Mark suggestions as read ──────────────────────────────────────────────
  void clearNewSuggestion() {
    _hasNewSuggestion = false;
    notifyListeners();
  }

  // ── Clear chat history ────────────────────────────────────────────────────
  void clearHistory() {
    _messages.clear();
    _hasNewSuggestion = false;
    _addBotMessage("Chat cleared! How can I help you?");
    notifyListeners();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────
  void _addBotMessage(String text) {
    _messages.add(ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_bot',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }
}