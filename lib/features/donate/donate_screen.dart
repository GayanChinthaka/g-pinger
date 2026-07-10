import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  static const _solAddress = 'EjfrikoyhXGxxDeYbZpPk3YEzyjfJADfoz8gZEKenXpp';
  static const _usdtAddress = '0x69380b3518a5fda238a51ebd6752c5f1bd24f1ea';
  static const _coffeeUrl = 'https://www.buymeacoffee.com/gayanchinthaka';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Development')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Text(
              'Every contribution helps keep this app free and maintained.\nThank you! 🙏',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 24),
            _CryptoCard(
              coin: 'SOL',
              network: 'Solana',
              address: _solAddress,
              coinColor: const Color(0xFF9945FF),
              qrAsset: 'assets/wallets/SOL.jpeg',
            ),
            const SizedBox(height: 16),
            _CryptoCard(
              coin: 'USDT',
              network: 'BNB Smart Chain (BEP20)',
              address: _usdtAddress,
              coinColor: const Color(0xFF26A17B),
              qrAsset: 'assets/wallets/USDT.jpeg',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black87,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _openUrl(context, _coffeeUrl),
              icon: const Icon(Icons.coffee_outlined),
              label: const Text(
                'Buy me a coffee',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
      }
    }
  }
}

class _CryptoCard extends StatelessWidget {
  final String coin;
  final String network;
  final String address;
  final Color coinColor;
  final String qrAsset;

  const _CryptoCard({
    required this.coin,
    required this.network,
    required this.address,
    required this.coinColor,
    required this.qrAsset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final truncated = '${address.substring(0, 8)}…${address.substring(address.length - 6)}';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // QR tap to expand
            GestureDetector(
              onTap: () => _showQr(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  qrAsset,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: coinColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          coin,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          network,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    truncated,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _copyAddress(context),
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copy address'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyAddress(BuildContext context) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$coin address copied!')),
    );
  }

  void _showQr(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(qrAsset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
