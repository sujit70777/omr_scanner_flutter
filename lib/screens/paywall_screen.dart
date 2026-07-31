import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/entitlement_service.dart';
import '../services/premium_config.dart';

/// Full-screen (or pushed) paywall for unlocking Premium.
class PaywallScreen extends StatelessWidget {
  final String? reason;
  const PaywallScreen({super.key, this.reason});

  static Future<bool> open(BuildContext context, {String? reason}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PaywallScreen(reason: reason)),
    );
    return result == true || EntitlementService.instance.isPremium;
  }

  @override
  Widget build(BuildContext context) {
    final ent = EntitlementService.instance;
    return AnimatedBuilder(
      animation: ent,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Premium')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(Icons.workspace_premium,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                ent.isPremium ? 'You have Premium' : 'Unlock Premium',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (reason != null) ...[
                const SizedBox(height: 8),
                Text(reason!, textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange[800])),
              ],
              const SizedBox(height: 20),
              ...PremiumConfig.premiumBullets.map(
                (b) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(b),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Free plan: ${PremiumConfig.freeExamLimit} exam · '
                '${PremiumConfig.freeScansPerMonth} scans/month · CSV export only',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              if (ent.isPremium)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Continue'),
                )
              else ...[
                FilledButton(
                  onPressed: ent.purchasePending
                      ? null
                      : () async {
                          await ent.buyPremium();
                          if (context.mounted && ent.isPremium) {
                            Navigator.pop(context, true);
                          }
                        },
                  child: ent.purchasePending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(ent.premiumPriceLabel == null
                          ? 'Buy Premium'
                          : 'Buy Premium · ${ent.premiumPriceLabel}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: ent.purchasePending
                      ? null
                      : () async {
                          await ent.restorePurchases();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ent.isPremium
                                    ? 'Premium restored'
                                    : (ent.lastError ?? 'No previous purchase found')),
                              ),
                            );
                            if (ent.isPremium) Navigator.pop(context, true);
                          }
                        },
                  child: const Text('Restore purchases'),
                ),
              ],
              if (ent.lastError != null) ...[
                const SizedBox(height: 12),
                Text(ent.lastError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
              if (kDebugMode && !ent.isPremium) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await ent.debugUnlockPremium();
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('[Debug] Unlock Premium'),
                ),
              ],
              if (kDebugMode && ent.isPremium) ...[
                TextButton(
                  onPressed: () async {
                    await ent.debugLockPremium();
                  },
                  child: const Text('[Debug] Lock Premium'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
