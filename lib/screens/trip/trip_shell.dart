import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';

class TripShell extends ConsumerWidget {
  final Widget child;
  const TripShell({super.key, required this.child});

  String _tripId(BuildContext context) {
    final segments = GoRouterState.of(context).uri.pathSegments;
    // /trips/<tripId>/dashboard → segments[1]
    return segments.length >= 2 ? segments[1] : '';
  }

  int _activeTab(String path) {
    if (path.contains('/lodging')) return 1;
    if (path.contains('/supplies')) return 2;
    if (path.contains('/carpool')) return 3;
    if (path.contains('/group')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripId = _tripId(context);
    final path = GoRouterState.of(context).uri.path;
    final tripAsync = ref.watch(tripStreamProvider(tripId));
    final tripName = tripAsync.valueOrNull?.name ?? '';
    final uid = ref.watch(currentUidProvider);
    final isAdmin = tripAsync.valueOrNull?.ownerId == uid;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(tripName.isEmpty ? 'Trip' : tripName),
      ),
      drawer: _TripDrawer(tripId: tripId, isAdmin: isAdmin),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _activeTab(path),
        onDestinationSelected: (i) {
          const tabs = ['dashboard', 'lodging', 'supplies', 'carpool', 'group'];
          context.go('/trips/$tripId/${tabs[i]}');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bed_outlined),
            selectedIcon: Icon(Icons.bed),
            label: 'Lodging',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Supplies',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Carpool',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Group',
          ),
        ],
      ),
    );
  }
}

class _TripDrawer extends StatelessWidget {
  final String tripId;
  final bool isAdmin;
  const _TripDrawer({required this.tripId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void nav(void Function() go) {
      Navigator.of(context).pop();
      go();
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Frientrip',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Change Trips'),
              onTap: () => nav(() => context.go('/trips')),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => nav(() => context.push('/profile')),
            ),
            if (isAdmin) ...[
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Manage Group'),
                onTap: () =>
                    nav(() => context.push('/trips/$tripId/manage')),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Trip History'),
                onTap: () =>
                    nav(() => context.push('/trips/$tripId/history')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
