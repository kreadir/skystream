import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/utils/responsive_breakpoints.dart';
import 'package:skystream/shared/widgets/custom_bottom_nav.dart';
import 'package:virtual_mouse/virtual_mouse.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  void _onItemTapped(int index, BuildContext context) {
    widget.navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceProfileAsync = ref.watch(deviceProfileProvider);
    final isHome = widget.navigationShell.currentIndex == 0;

    return deviceProfileAsync.when(
      data: (profile) {
        // Desktop or TV use Side Navigation
        // Or if the screen is physically wide enough (like iPads/Tablets in landscape)
        // VirtualMouse cursor only shown on TV, not desktop
        if (profile.isTv || context.isTabletOrLarger) {
          final sideNavScaffold = PopScope(
            canPop: isHome,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                widget.navigationShell.goBranch(0);
              }
            },
            child: Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    elevation: 8,
                    backgroundColor: Theme.of(
                      context,
                    ).appBarTheme.backgroundColor,
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: (index) =>
                        _onItemTapped(index, context),
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: 0.0, // Center
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search),
                        label: Text('Search'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Discover'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.library_books_outlined),
                        selectedIcon: Icon(Icons.library_books),
                        label: Text('Library'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  Expanded(child: widget.navigationShell),
                ],
              ),
            ),
          );

          // Wrap with VirtualMouse only on TV
          if (profile.isTv) {
            // Focus wrapper ensures the remote's back key is delivered to Flutter
            // after returning from the player (which captures all key events itself).
            // Without this, back key goes to the OS with nothing focused and is swallowed.
            return VirtualMouse(
              visible: true,
              velocity: 3,
              pointerColor: Theme.of(context).colorScheme.primary,
              child: Focus(
                autofocus: true,
                child: sideNavScaffold,
              ),
            );
          }

          return sideNavScaffold;
        }

        // Mobile uses Bottom Navigation
        return PopScope(
          canPop: isHome,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              widget.navigationShell.goBranch(0);
            }
          },
          child: Scaffold(
            body: widget.navigationShell,
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: (index) => _onItemTapped(index, context),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}
