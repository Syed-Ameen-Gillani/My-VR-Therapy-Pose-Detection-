import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/di/providers.dart';
import '../../../core/widgets/common.dart';
import '../domain/rehabilitation_plan.dart';

class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key, required this.patientId});
  final String patientId;
  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  int _step = 0;
  bool _dirty = false;
  bool _isSaving = false;
  bool _hasLoadedInitialDraft = false;
  bool _draftLoadScheduled = false;
  final _selected = <String>{};
  final _form = GlobalKey<FormState>();
  final _sessions = TextEditingController(text: '4');
  @override
  void dispose() {
    _sessions.dispose();
    super.dispose();
  }

  void _loadInitialDraft(RehabilitationPlan? plan) {
    if (_hasLoadedInitialDraft || _dirty) return;
    _selected
      ..clear()
      ..addAll(plan?.exerciseIds ?? const <String>[]);
    if (plan != null) {
      _sessions.text = plan.scheduledSessions.toString();
    }
    _hasLoadedInitialDraft = true;
  }

  Future<void> _exit() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard preview changes?'),
        content: const Text('This draft exists only on this screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansValue = ref.watch(plansProvider);
    final currentPlan = switch (plansValue) {
      AsyncData(:final value) =>
        value.where((plan) => plan.patientId == widget.patientId).firstOrNull,
      _ => null,
    };
    if (plansValue.hasValue &&
        !_hasLoadedInitialDraft &&
        !_draftLoadScheduled &&
        !_dirty) {
      _draftLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loadInitialDraft(currentPlan));
      });
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Prescription editor')),
        body: PageBody(
          children: [
            StatusBadge(
              _step == 2
                  ? 'Prescription ready to publish'
                  : 'Prescription setup • Step ${_step + 1} of 3',
            ),
            const SizedBox(height: 16),
            PageHeading(
              [
                'Choose exercises',
                'Targets and schedule',
                'Review prescription draft',
              ][_step],
              'Step ${_step + 1} of 3 · Patient ${widget.patientId.toUpperCase()}',
            ),
            LinearProgressIndicator(
              value: (_step + 1) / 3,
              semanticsLabel: 'Plan editor step ${_step + 1} of 3',
            ),
            const SizedBox(height: 24),
            AsyncContent(
              value: ref.watch(exercisesProvider),
              onRetry: () => ref.invalidate(exercisesProvider),
              builder: (exercises) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step == 0) ...[
                    for (final e in exercises)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: CheckboxListTile(
                            title: Text(e.name),
                            subtitle: Text(e.category),
                            value: _selected.contains(e.id),
                            onChanged: (checked) => setState(() {
                              _dirty = true;
                              checked == true
                                  ? _selected.add(e.id)
                                  : _selected.remove(e.id);
                            }),
                          ),
                        ),
                      ),
                    if (exercises.isEmpty)
                      const StateMessage(
                        title: 'No exercises available',
                        message:
                            'An exercise catalog is needed before creating a plan.',
                      ),
                  ],
                  if (_step == 1)
                    Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _sessions,
                            onChanged: (_) => _dirty = true,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Weekly session frequency',
                              helperText:
                                  'Recommended target: 1–12 sessions per week.',
                            ),
                            validator: (value) {
                              final n = int.tryParse(value ?? '');
                              return n == null || n < 1 || n > 12
                                  ? 'Enter a whole number from 1 to 12.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const ContentCard(
                            child: Text(
                              'Configured exercises will be dispatched to the VR headset when the patient starts a session.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_step == 2)
                    ContentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Draft summary',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          for (final e in exercises.where(
                            (e) => _selected.contains(e.id),
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('• ${e.name}'),
                            ),
                          Text('${_sessions.text} weekly sessions'),
                          const SizedBox(height: 12),
                          const Text(
                            'Publishing this plan activates it for the patient and prepares session targets for VR.',
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: (_step == 0 && _selected.isEmpty) || _isSaving
                        ? null
                        : () async {
                            if (_step == 1 && !_form.currentState!.validate()) {
                              return;
                            }
                            if (_step < 2) {
                              setState(() => _step++);
                            } else {
                              setState(() => _isSaving = true);
                              try {
                                final repo = ref.read(planRepositoryProvider);
                                final sessions =
                                    int.tryParse(_sessions.text.trim()) ?? 4;
                                await repo.savePlan(
                                  patientId: widget.patientId,
                                  title:
                                      currentPlan?.title ??
                                      'Personalized mobility routine',
                                  exerciseIds: _selected.toList(),
                                  scheduledSessions: sessions,
                                );
                                ref.invalidate(plansProvider);
                                ref.invalidate(patientsProvider);
                                if (!context.mounted) return;
                                setState(() => _dirty = false);
                                showPhaseNotice(
                                  context,
                                  'Prescription saved and activated.',
                                );
                                Navigator.of(context).pop();
                              } catch (e) {
                                if (!context.mounted) return;
                                setState(() => _isSaving = false);
                                showPhaseNotice(
                                  context,
                                  'Could not save prescription: $e',
                                );
                              }
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _step == 2 ? 'Publish prescription' : 'Continue',
                          ),
                  ),
                  if (_step > 0 && !_isSaving)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Previous step'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
