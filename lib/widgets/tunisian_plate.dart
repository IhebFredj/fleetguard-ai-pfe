import 'package:flutter/material.dart';

/// A simple Tunisian license plate widget.
/// Expects a `plate` string like: "228 tun 412" (case/spacing tolerant).
class TunisianPlate extends StatelessWidget {
  final String plate;
  final double height;
  final EdgeInsetsGeometry padding;

  const TunisianPlate({
    super.key,
    required this.plate,
    this.height = 72,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final parsed = _parsePlate(plate);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF2F3337),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black87, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Plate row
          Container(
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF2F3337),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      parsed.left,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                // Middle Arabic text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Text(
                    'تونس',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      parsed.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Small bottom bar (date placeholder or id)
          Text(
            parsed.caption,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedPlate {
  final String left;
  final String right;
  final String caption;

  const _ParsedPlate(this.left, this.right, this.caption);
}

_ParsedPlate _parsePlate(String raw) {
  // Normalize
  final s = raw.trim().replaceAll(RegExp(r"\s+"), ' ').toLowerCase();

  // Try to split by the 'tun' token
  final parts = s.split(' tun ');
  if (parts.length == 2) {
    final left = parts[0].trim();
    final right = parts[1].trim();
    return _ParsedPlate(left, right, raw);
  }

  // Fallback: extract all numbers, first to left, last to right
  final nums = RegExp(r"\d+").allMatches(s).map((m) => m.group(0)!).toList();
  if (nums.length >= 2) {
    return _ParsedPlate(nums.first, nums.last, raw);
  }

  // Last resort: show the whole string in the caption
  return const _ParsedPlate('—', '—', '');
}
