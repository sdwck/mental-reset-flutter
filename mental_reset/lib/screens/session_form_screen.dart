import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/result.dart';
import '../data/session.dart';
import '../state/sessions_model.dart';

/// Форма из L3, теперь связанная с моделью: валидный submit пишет через repository.
/// sessionId == null → создание, иначе → редактирование.
class SessionFormScreen extends StatefulWidget {
  const SessionFormScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _practiceType;
  bool _soundEnabled = true;
  bool _saving = false; // эфемерное состояние формы
  MindfulSession? _editing;

  @override
  void initState() {
    super.initState();
    final id = widget.sessionId;
    if (id != null) {
      _editing = context.read<SessionsModel>().byId(id);
      final s = _editing;
      if (s != null) {
        _titleCtrl.text = s.title;
        _durationCtrl.text = '${s.durationMin}';
        _notesCtrl.text = s.notes;
        _practiceType = s.practiceType;
        _soundEnabled = s.soundEnabled;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final model = context.read<SessionsModel>();
    final draft = MindfulSession(
      id: _editing?.id ?? '',
      title: _titleCtrl.text.trim(),
      practiceType: _practiceType!,
      durationMin: int.parse(_durationCtrl.text),
      notes: _notesCtrl.text.trim(),
      soundEnabled: _soundEnabled,
      createdAt: _editing?.createdAt ?? DateTime.now(),
    );
    final r = _editing == null ? await model.add(draft) : await model.edit(draft);

    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context);
    switch (r) {
      case Ok(:final value):
        messenger.showSnackBar(SnackBar(
            content: Text('✓ Сохранено: ${value.title} (+${value.durationMin} мин)')));
        context.pop();
      case Err(:final message):
        messenger.showSnackBar(SnackBar(
          content: Text('Ошибка: $message'),
          action: SnackBarAction(label: 'Повторить', onPressed: _submit),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_editing == null ? 'Новая сессия осознанности' : 'Редактирование')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Название сессии'),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Название обязательно (мин. 3 символа)'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _practiceType,
              items: [
                for (final e in practiceTypeLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _practiceType = v),
              decoration: const InputDecoration(labelText: 'Тип практики'),
              validator: (v) => v == null ? 'Выберите тип практики' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Длительность (минут: 1 — 120)'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 1 || n > 120)
                    ? 'Укажите длительность от 1 до 120 мин'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Заметки и намерения'),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Добавьте описание намерения (мин. 5 символов)'
                  : null,
            ),
            SwitchListTile(
              title: const Text('Звуковое сопровождение'),
              value: _soundEnabled,
              onChanged: (v) => setState(() => _soundEnabled = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Сохранить сессию'),
            ),
          ],
        ),
      ),
    );
  }
}
