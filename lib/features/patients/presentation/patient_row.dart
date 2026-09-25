import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/patient.dart';

class PatientRow extends StatelessWidget {
  const PatientRow({super.key, required this.patient});
  final Patient patient;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    leading: CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      child: Text(patient.initials),
    ),
    title: Text(patient.name),
    subtitle: Text(patient.goal),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push('/patients/${patient.id}'),
  );
}
