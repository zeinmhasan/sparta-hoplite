import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';

/// Pencarian tujuan seperti di aplikasi peta: ketik, lalu saran tempat muncul
/// di bawahnya. Tempat populer dicocokkan seketika; sisanya dicari daring.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _input = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Place> _online = const [];
  bool _searching = false;
  bool _failed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final query = text.trim();
    _debounce?.cancel();
    setState(() {
      _query = query;
      _failed = false;
      _searching = query.length >= 2;
      if (query.length < 2) _online = const [];
    });
    // Tunggu jeda mengetik sebelum bertanya ke server.
    if (query.length >= 2) _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await ref.read(repositoryProvider).searchPlaces(query);
      if (!mounted || query != _query) return;
      setState(() {
        _online = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || query != _query) return;
      setState(() {
        _searching = false;
        _failed = true;
      });
    }
  }

  List<Place> get _suggestions {
    if (_query.isEmpty) return mock.places;
    final needle = _query.toLowerCase();
    final local = mock.places
        .where((p) => p.name.toLowerCase().contains(needle) || p.address.toLowerCase().contains(needle))
        .toList();
    final localNames = {for (final p in local) p.name.toLowerCase()};
    return [...local, ..._online.where((p) => !localNames.contains(p.name.toLowerCase()))];
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final empty = _query.length >= 2 && suggestions.isEmpty && !_searching;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.maroon),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        autofocus: true,
                        onChanged: _onChanged,
                        textInputAction: TextInputAction.search,
                        style: AppText.body.copyWith(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Cari tujuan di Surabaya',
                          hintStyle: AppText.body.copyWith(fontSize: 15, color: AppColors.textSecondary),
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () {
                          _input.clear();
                          _onChanged('');
                        },
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 2, child: _searching ? const LinearProgressIndicator(minHeight: 2) : null),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (_query.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Text('TEMPAT POPULER', style: AppText.overline),
                    ),
                  for (final place in suggestions)
                    _SuggestionTile(place: place, query: _query, onTap: () => context.pop(place)),
                  if (empty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            _failed ? Icons.wifi_off_rounded : Icons.search_off_rounded,
                            size: 40,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _failed
                                ? 'Pencarian butuh koneksi internet. Coba lagi sebentar.'
                                : 'Tidak ada tempat bernama "$_query" di Surabaya.',
                            textAlign: TextAlign.center,
                            style: AppText.body.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
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

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.place, required this.query, required this.onTap});
  final Place place;
  final String query;
  final VoidCallback onTap;

  /// Nama tempat dengan bagian yang cocok dengan ketikan ditebalkan.
  TextSpan _highlighted() {
    const normal = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.text);
    const bold = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text);
    final start = query.isEmpty ? -1 : place.name.toLowerCase().indexOf(query.toLowerCase());
    if (start < 0) {
      // Tanpa ketikan (daftar tempat populer) nama tampil semi-tebal.
      return TextSpan(text: place.name, style: query.isEmpty ? bold : normal);
    }
    final end = start + query.length;
    return TextSpan(
      style: normal,
      children: [
        TextSpan(text: place.name.substring(0, start)),
        TextSpan(text: place.name.substring(start, end), style: bold),
        TextSpan(text: place.name.substring(end)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: AppColors.field, shape: BoxShape.circle),
              child: Icon(place.icon, size: 19, color: AppColors.maroon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(_highlighted(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.north_west_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
