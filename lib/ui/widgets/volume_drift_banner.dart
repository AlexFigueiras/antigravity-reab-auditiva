import 'package:flutter/material.dart';
import '../../services/audio_accessibility.dart';
import '../../l10n/gen/app_localizations.dart';

class VolumeDriftBanner extends StatelessWidget {
  final VoidCallback onResume;
  final EdgeInsets? margin;

  const VolumeDriftBanner({
    super.key,
    required this.onResume,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA000).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFFFFA000)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_off, color: Color(0xFFFFC246)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.thresholdTestVolumeDriftTitle,
                  style: const TextStyle(
                      color: Color(0xFFFFC246),
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.thresholdTestVolumeDriftBody,
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA000),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await AudioAccessibility.rampToReferenceVolume();
                onResume();
              },
              child: Text(
                l10n.thresholdTestVolumeDriftButton,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
