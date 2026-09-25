import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/di/providers.dart';
import '../../../core/widgets/common.dart';
import 'patient_form_dialog.dart';
import 'patient_row.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  String _query = '';

  Future<void> _openAddPatientDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => PatientFormDialog(
        title: 'Add new patient',
        submitLabel: 'Save patient',
        onSave: (name, goal) async {
          final repo = ref.read(patientRepositoryProvider);
          await repo.createPatient(name: name, goal: goal);
          ref.invalidate(patientsProvider);
        },
      ),
    );

    if (created == true && mounted) {
      showPhaseNotice(context, 'Patient record created.');
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageHeading('Patients', 'Their goals. Your guidance.'),
      FilledButton.icon(
        onPressed: _openAddPatientDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add patient'),
      ),
      const SizedBox(height: 16),
      TextField(
        onChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
        decoration: const InputDecoration(
          labelText: 'Search patients',
          prefixIcon: Icon(Icons.search),
          hintText: 'Name or patient ID',
        ),
      ),
      const SizedBox(height: 16),
      AsyncContent(
        value: ref.watch(patientsProvider),
        onRetry: () => ref.invalidate(patientsProvider),
        builder: (patients) {
          final filtered = patients
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_query) ||
                    p.id.toLowerCase().contains(_query),
              )
              .toList();
          if (filtered.isEmpty) {
            return StateMessage(
              title: patients.isEmpty
                  ? 'No patients yet'
                  : 'No matching patients',
              message: patients.isEmpty
                  ? 'Tap "Add patient" above to register your first patient.'
                  : 'Try another name or patient ID.',
            );
          }
          return Column(
            children: [
              for (final patient in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(child: PatientRow(patient: patient)),
                ),
            ],
          );
        },
      ),
    ],
  );
}
