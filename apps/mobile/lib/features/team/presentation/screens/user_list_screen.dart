import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';
import 'user_editor_screen.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  List<StaffRow> _rows = [];
  var _error = '';
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final rows = await ref.read(wawaClientProvider).staff();
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _roleLabel(String role) {
    return switch (role) {
      'admin' => 'Admin',
      'manager' => 'Manager',
      _ => 'Trabajador',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PrimaryButton(
              label: 'Invitar Usuario',
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const UserEditorScreen()));
                await _load();
              },
            ),
            const SizedBox(height: 16),
            ErrorBanner(_error),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ..._rows.map(
              (row) => Card(
                child: ListTile(
                  title: Text(row.fullName.isEmpty ? row.email : row.fullName),
                  subtitle: Text('${row.email} · ${_roleLabel(row.role)}${row.isActive ? '' : ' · Inactivo'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => UserEditorScreen(userId: row.id)),
                    );
                    await _load();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
