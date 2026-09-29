import 'package:flutter/material.dart';

/// Shared checklist and result controls for condition inspections.
///
/// The widget only collects inspection input. Maintenance status and reminder
/// dates are calculated by MaintenanceCalculator from the saved rule policy.
class ConditionChecklistEditor extends StatelessWidget {
  const ConditionChecklistEditor({
    super.key,
    required this.items,
    required this.completedItems,
    required this.conditionPassed,
    required this.onItemChanged,
    required this.onConditionChanged,
    this.accentColor = const Color(0xFF00D27A),
    this.enabled = true,
  });

  final List<String> items;
  final Map<String, bool> completedItems;
  final bool? conditionPassed;
  final ValueChanged<Map<String, bool>> onItemChanged;
  final ValueChanged<bool?> onConditionChanged;
  final Color accentColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111113),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFF29292F)),
            ),
            child: CheckboxListTile(
              value: completedItems[item] ?? false,
              onChanged: enabled
                  ? (value) {
                      onItemChanged({...completedItems, item: value ?? false});
                    }
                  : null,
              activeColor: accentColor,
              checkColor: const Color(0xFF070708),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              dense: true,
              title: Text(
                item,
                style: const TextStyle(
                  color: Color(0xFFE5E7EA),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: const Text(
            'INSPECTION RESULT',
            style: TextStyle(
              color: Color(0xFF777B82),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _resultButton(
                label: 'ALL CLEAR',
                passed: true,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _resultButton(
                label: 'NEEDS ATTENTION',
                passed: false,
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultButton({
    required String label,
    required bool passed,
    required IconData icon,
  }) {
    final selected = conditionPassed == passed;
    final color = passed ? accentColor : const Color(0xFFFF542C);
    return OutlinedButton.icon(
      onPressed: enabled ? () => onConditionChanged(passed) : null,
      icon: Icon(icon, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? color : const Color(0xFF9EA2A8),
        backgroundColor: selected
            ? color.withOpacity(0.10)
            : Colors.transparent,
        side: BorderSide(
          color: selected ? color.withOpacity(0.65) : const Color(0xFF41434A),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}
