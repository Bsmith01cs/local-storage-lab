import 'package:flutter/material.dart';

import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
    runApp(DirectoryApp(helper: helper));
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check logs.',
            ),
          ),
        ),
      ),
    );
  }
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fall Festival Roster',
    home: RosterScreen(helper: helper),
  );
}

class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  int? _editingId;
  bool _busy = false;
  bool _loaded = false;
  String? _readError;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  void _clearForm() {
    _editingId = null;
    _name.clear();
    _age.clear();
    _formKey.currentState?.reset();
  }

  Future<bool> _load() async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return false;
      setState(() {
        _rows = rows;
        _count = count;
        _loaded = true;
        _readError = null;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() {
        _readError = 'Could not load records. Tap Refresh to retry.';
        _loaded = true;
      });
      return false;
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final age = int.parse(_age.text.trim()); // guaranteed by validator
    final selectedId = _editingId;
    setState(() => _busy = true);
    try {
      int result;
      if (selectedId == null) {
        result = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
      } else {
        result = await widget.helper.update({
          DatabaseHelper.columnId: selectedId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
      }
      if (!mounted) return;
      if (selectedId != null && result == 0) {
        setState(() => _message = 'Record ID $selectedId no longer exists.');
        await _load();
        return;
      }
      setState(() {
        _message = selectedId == null
            ? 'Added guest with ID $result.'
            : 'Updated ID $selectedId ($result row affected).';
        _clearForm();
      });
      final refreshed = await _load();
      if (!refreshed && mounted) {
        setState(() => _message = 'Saved, but refresh failed. Tap Refresh.');
      }
    } catch (error, stackTrace) {
      debugPrint('Write failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _message = 'Save failed. Check logs and retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit(Map<String, dynamic> row) {
    if (_busy) return;
    setState(() {
      _editingId = row[DatabaseHelper.columnId] as int;
      _name.text = row[DatabaseHelper.columnName] as String;
      _age.text = '${row[DatabaseHelper.columnAge]}';
      _message = 'Editing ID $_editingId.';
    });
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_busy) return;
    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete $name (ID $id)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      final affected = await widget.helper.delete(id);
      if (!mounted) return;
      setState(() {
        _message = affected == 1
            ? 'Deleted ID $id ($affected row affected).'
            : 'ID $id no longer exists (0 rows deleted).';
        if (affected == 1 && _editingId == id) _clearForm();
      });
      final refreshed = await _load();
      if (!refreshed && mounted && affected == 1) {
        setState(() => _message = 'Deleted, but refresh failed. Tap Refresh.');
      }
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _message = 'Delete failed. Check logs and retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fall Festival Roster')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Guest name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a guest name.'
                      : null,
                ),
                TextFormField(
                  controller: _age,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age (0–130)'),
                  validator: (value) {
                    final age = int.tryParse((value ?? '').trim());
                    if (age == null || age < 0 || age > 130) {
                      return 'Enter a whole-number age from 0 to 130.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _busy ? null : _save,
                      child: Text(
                        _editingId == null ? 'Add guest' : 'Save edit',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy || _editingId == null
                          ? null
                          : () => setState(() {
                              _clearForm();
                              _message = 'Edit cancelled; no changes saved.';
                            }),
                      child: const Text('Cancel edit'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _refresh,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message!),
            ),
          const SizedBox(height: 12),
          Text(
            'Record count: $_count',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_readError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_readError!),
            )
          else if (_loaded && _rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No festival guests yet.'),
            )
          else
            ..._rows.map(
              (row) => Card(
                child: ListTile(
                  title: Text('${row[DatabaseHelper.columnName]}'),
                  subtitle: Text(
                    'ID: ${row[DatabaseHelper.columnId]}  •  Age: ${row[DatabaseHelper.columnAge]}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: _busy ? null : () => _edit(row),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: _busy ? null : () => _delete(row),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
