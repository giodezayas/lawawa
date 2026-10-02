import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/finance/presentation/screens/cards_screen.dart';
import '../features/finance/presentation/screens/expense_list_screen.dart';
import '../features/finance/presentation/screens/reports_screen.dart';
import '../features/finance/presentation/screens/results_screen.dart';
import '../features/inventory/presentation/screens/ipv_list_screen.dart';
import '../features/inventory/presentation/screens/products_screen.dart';
import '../features/inventory/presentation/screens/purchase_list_screen.dart';
import '../features/team/presentation/screens/user_list_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final canManage = user?.canManageStaff ?? false;

    final pages = [
      const DashboardScreen(),
      const IpvListScreen(),
      const ExpenseListScreen(),
      const ResultsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('La Wawa'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Salir'),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('La Wawa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  Text(user?.displayName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(user?.roleLabel ?? '', style: const TextStyle(color: AppColors.primary)),
                ],
              ),
            ),
            ListTile(
              title: const Text('Inicio'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 0);
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('INVENTARIO', style: TextStyle(fontSize: 11, letterSpacing: 1.4, color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              title: const Text('IPV'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 1);
              },
            ),
            ListTile(
              title: const Text('Productos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProductsScreen()));
              },
            ),
            ListTile(
              title: const Text('Compras'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PurchaseListScreen()));
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('FINANZAS', style: TextStyle(fontSize: 11, letterSpacing: 1.4, color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              title: const Text('Resultados'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 3);
              },
            ),
            ListTile(
              title: const Text('Reportes'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ReportsScreen()));
              },
            ),
            ListTile(
              title: const Text('Tarjetas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CardsScreen()));
              },
            ),
            ListTile(
              title: const Text('Gastos'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 2);
              },
            ),
            if (canManage) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('EQUIPO', style: TextStyle(fontSize: 11, letterSpacing: 1.4, color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              ListTile(
                title: const Text('Usuarios'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const UserListScreen()));
                },
              ),
            ],
          ],
        ),
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'IPV'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Gastos'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Resultados'),
        ],
      ),
    );
  }
}
