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
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        patient.initials,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    ),
    title: Text(
      patient.name,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
    subtitle: Text(
      patient.goal,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
      ),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      color: Color(0xFF94A3B8),
      size: 20,
    ),
    onTap: () => context.push('/patients/${patient.id}'),
  );
}
