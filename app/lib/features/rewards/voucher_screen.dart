import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/state.dart';

/// Voucher hasil tukar saldo: kode QR yang dipindai di bus atau di loket.
class VoucherScreen extends ConsumerWidget {
  const VoucherScreen({super.key, required this.voucherId});
  final String voucherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voucher = ref.watch(walletProvider).vouchers.where((v) => v.id == voucherId).firstOrNull;
    final now = ref.watch(nowProvider);

    return Scaffold(
      backgroundColor: voucher?.item.color ?? AppColors.background,
      body: SafeArea(
        child: voucher == null
            ? const Column(children: [ScreenHeader(title: 'Voucher')])
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Voucher',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(voucher.item.icon, color: voucher.item.color, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(voucher.item.name, style: AppText.cardTitle),
                                  Text(voucher.item.operator, style: AppText.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        QrImageView(
                          data: 'SPARTA-VOUCHER:${voucher.code}:${voucher.item.id}',
                          size: 220,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.text),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SelectableText(
                          voucher.code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(voucher.item.unit, style: AppText.caption),
                        const Divider(height: 32),
                        _Row(Icons.schedule_rounded, 'Berlaku sampai ${dateTimeLabel(voucher.validUntil)}'),
                        _Row(Icons.qr_code_scanner_rounded, voucher.item.howTo),
                        _Row(
                          Icons.info_outline_rounded,
                          'Sekali pakai. Ditukar ${timeAgo(voucher.issuedAt, now).toLowerCase()}.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Naikkan kecerahan layar agar QR mudah dipindai.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Colors.white70),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 13.5, height: 1.35))),
        ],
      ),
    );
  }
}
