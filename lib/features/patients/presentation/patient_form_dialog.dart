import 'package:flutter/material.dart';
import '../../../core/errors/app_failure.dart';

class PatientFormDialog extends StatefulWidget {
  const PatientFormDialog({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSave,
    this.initialName = '',
    this.initialGoal = '',
  });

  final String title;
  final String submitLabel;
  final String initialName;
  final String initialGoal;
  final Future<void> Function(String name, String goal) onSave;

  @override
  State<PatientFormDialog> createState() => _PatientFormDialogState();
}

class _PatientFormDialogState extends State<PatientFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _goalController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _goalController = TextEditingController(text: widget.initialGoal);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.onSave(
        _nameController.text.trim(),
        _goalController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'Could not save patient. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorText!,
                      style: TextStyle(color: colors.error, fontSize: 13),
                    ),
                  ),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Patient full name',
                    hintText: 'e.g. Fatima Tariq',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter patient name.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _goalController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Rehabilitation goal',
                    hintText: 'e.g. Improve shoulder range of motion',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter rehabilitation goal.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
