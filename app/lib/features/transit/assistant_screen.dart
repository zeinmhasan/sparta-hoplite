import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/state.dart';

class _Message {
  const _Message(this.text, {required this.fromUser, this.transitCard = false});
  final String text;
  final bool fromUser;
  final bool transitCard;
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _messages = <_Message>[const _Message(mock.assistantGreeting, fromUser: false)];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _messages.add(_Message(text, fromUser: true));
      _thinking = true;
    });
    _scrollToEnd();
    final reply = await ref.read(repositoryProvider).askAssistant(text);
    if (!mounted) return;
    setState(() {
      _thinking = false;
      _messages.add(_Message(reply.text, fromUser: false, transitCard: reply.showTransitCard));
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Transit Assistant',
              trailing: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Padding(padding: const EdgeInsets.all(5), child: Image.asset('assets/images/logo.png')),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                children: [
                  for (var i = 0; i < _messages.length; i++)
                    _Bubble(
                      key: ValueKey(i),
                      message: _messages[i],
                      // Hanya jawaban terbaru yang diketik huruf demi huruf.
                      typewriter: !_messages[i].fromUser && i == _messages.length - 1 && i > 0,
                      onTick: _scrollToEnd,
                    ),
                  if (_thinking) const _TypingIndicator(),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mock.assistantSuggestions.length,
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(mock.assistantSuggestions[i]),
                  labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.maroon),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  onPressed: () => _ask(mock.assistantSuggestions[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: _ask,
                      textInputAction: TextInputAction.send,
                      style: AppText.body,
                      decoration: InputDecoration(
                        hintText: 'Tanya soal Suroboyo Bus...',
                        hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(99),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(99),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: AppColors.maroon,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _ask(_input.text),
                    ),
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

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, required this.typewriter, required this.onTick});
  final _Message message;
  final bool typewriter;
  final VoidCallback onTick;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    final style = TextStyle(fontSize: 14, height: 1.45, color: user ? Colors.white : AppColors.text);

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: user ? AppColors.maroon : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (typewriter)
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: message.text.length),
                duration: Duration(milliseconds: message.text.length * 14),
                builder: (context, count, _) {
                  onTick();
                  return Text(message.text.substring(0, count), style: style);
                },
              )
            else
              Text(message.text, style: style),
            if (message.transitCard) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.go('/transit'),
                icon: const Icon(Icons.directions_bus_rounded, size: 18),
                label: const Text('Lihat rute di Transit'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.15, end: 0);
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: const BoxDecoration(color: AppColors.textSecondary, shape: BoxShape.circle),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 0.25, end: 1, duration: 450.ms, delay: (i * 150).ms),
          ],
        ),
      ),
    );
  }
}
