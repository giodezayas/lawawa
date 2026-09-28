import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/wawa_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/ui.dart';

class UserEditorScreen extends ConsumerStatefulWidget {
  const UserEditorScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<UserEditorScreen> createState() => _UserEditorScreenState();
}

class _UserEditorScreenState extends ConsumerState<UserEditorScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  var _role = 'trabajador';
  var _active = true;
  var _error = '';
  var _loading = false;

  bool get _create => widget.userId == null;

  @override
  void initState() {
    super.initState();
    final id = widget.userId;
    if (id != null) {
      ref.read(wawaClientProvider).staffById(id).then((row) {
        if (!mounted) {
          return;
        }
        setState(() {
          _email.text = row.email;
          _name.text = row.fullName;
          _role = row.role;
          _active = row.isActive;
        });
      }).catchError((error) {
        if (mounted) {
          setState(() => _error = error.toString());
        }
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final api = ref.read(wawaClientProvider);
      if (_create) {
        await api.inviteStaff(
          username: _email.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          role: _role,
        );
      } else {
        await api.updateStaff(
          id: widget.userId!,
          fullName: _name.text.trim(),
          role: _role,
          isActive: _active,
          password: _password.text,
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_create ? 'Invitar Usuario' : 'Usuario')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ErrorBanner(_error),
          LabeledField(label: 'Usuario *', controller: _email, enabled: _create),
          LabeledField(label: 'Nombre Completo', controller: _name),
          LabeledField(label: _create ? 'Contraseña *' : 'Nueva Contraseña', controller: _password, obscureText: true),
          DropdownButtonFormField<String>(
            value: _role,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'manager', child: Text('Manager')),
              DropdownMenuItem(value: 'trabajador', child: Text('Trabajador')),
            ],
            onChanged: (value) => setState(() => _role = value ?? 'trabajador'),
          ),
          if (!_create)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Guardar', loading: _loading, onPressed: _save),
          if (!_create)
            TextButton(
              onPressed: () async {
                if (!await confirmAction(context, '¿Borrar este usuario?')) {
                  return;
                }
                await ref.read(wawaClientProvider).deleteStaff(widget.userId!);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Borrar Usuario', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
    );
  }
}
