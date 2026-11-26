import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';

class ConfidenceField extends StatelessWidget {
  const ConfidenceField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.confidence = 1,
    this.keyboardType,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final double confidence;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final low = confidence < 0.6;
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: low
            ? Tooltip(
                message: context.l10n.lowOcrConfidence,
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                ),
              )
            : null,
        enabledBorder: low
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.amber, width: 1.5),
              )
            : null,
      ),
    );
  }
}
