import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

import '../models/reading_models.dart';
import '../models/user_profile.dart';
import '../services/history_service.dart';
import '../services/secure_storage_service.dart';
import 'profile_drawer.dart';
import 'profile_dialogs.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardScreen();
  }
}

class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen();

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  List<LocalReadingHistory> _history = [];
  // BOLT: Pre-calculated data to avoid expensive transformations in build()
  List<LocalReadingHistory> _chronologicalHistory = [];
  List<FlSpot> _chartSpots = [];
  bool _isLoading = true;
  AppStateData? _appState;
  // BOLT: Cache DateFormat instance to avoid repeated creation in ListView.builder
  late final DateFormat _historyDateFormat;

  final GlobalKey _drawerKey = GlobalKey();
  final GlobalKey _tabsKey = GlobalKey();
  final GlobalKey _addReadingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _historyDateFormat = DateFormat.yMMMd().add_jm();
    ShowcaseView.register();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final state = await SecureStorageService().getAppState();

    // BOLT: Only fetch history for the active profile to improve performance and ensure data isolation.
    String? activeProfileId;
    if (state.profiles.isNotEmpty &&
        state.activeProfileIndex >= 0 &&
        state.activeProfileIndex < state.profiles.length) {
      activeProfileId = state.profiles[state.activeProfileIndex].id;
    }

    final history =
        await HistoryService().getHistory(profileId: activeProfileId);

    // BOLT: Pre-calculate expensive data transformations outside the build method.
    // This improves UI responsiveness, especially as history grows.
    final chronological = history.reversed.toList();
    final spots = <FlSpot>[];
    for (int i = 0; i < chronological.length; i++) {
      final valStr = chronological[i].valorContador1;
      final val = double.tryParse(valStr) ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    setState(() {
      _appState = state;
      _history = history;
      _chronologicalHistory = chronological;
      _chartSpots = spots;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hasSeen = await SecureStorageService().hasSeenTutorial();
      if (!hasSeen && mounted && state.profiles.isNotEmpty) {
        ShowcaseView.get().startShowCase([_drawerKey, _tabsKey, _addReadingKey]);
        await SecureStorageService().setSeenTutorial(true);
      }
    });
  }

  Future<void> _addProfile() async {
    if (_appState != null) {
      await ProfileDialogs.showAddProfileDialog(
        context: context,
        appState: _appState!,
        onSuccess: _loadData,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasProfiles = _appState?.profiles.isNotEmpty ?? false;
    final activeProfileName = hasProfiles
        ? _appState!.profiles[_appState!.activeProfileIndex].name
        : 'dashboard.no_properties'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text(activeProfileName),
        leading: Builder(
          builder: (context) {
            return Showcase(
              key: _drawerKey,
              title: 'tutorial.menu_title'.tr(),
              description: 'tutorial.menu_desc'.tr(),
              disposeOnTap: true,
              onTargetClick: () {
                Scaffold.of(context).openDrawer();
                ShowcaseView.get().dismiss();
              },
              child: IconButton(
                tooltip: 'dashboard.menu_tooltip'.tr(),
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            );
          },
        ),
      ),
      drawer: _appState != null
          ? ProfileDrawer(appState: _appState!, onProfileChanged: _loadData)
          : null,
      body: !hasProfiles
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.home_work_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'dashboard.no_properties_desc'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _addProfile,
                      icon: const Icon(Icons.add),
                      label: Text('drawer.add_profile'.tr()),
                      style: FilledButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'dashboard.no_history'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                )
              : _buildContent(),
      floatingActionButton: hasProfiles
          ? Showcase(
              key: _addReadingKey,
              title: 'tutorial.add_title'.tr(),
              description: 'tutorial.add_desc'.tr(),
              disposeOnTap: true,
              onTargetClick: () {
                ShowcaseView.get().dismiss();
                Navigator.pushNamed(context, '/reading').then((result) {
                  if (result == true) {
                    _loadData();
                  }
                });
              },
              child: Tooltip(
                message: 'dashboard.add_reading_tooltip'.tr(),
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    final result =
                        await Navigator.pushNamed(context, '/reading');
                    if (result == true) {
                      _loadData();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text('dashboard.add_reading'.tr()),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Showcase(
              key: _tabsKey,
              title: 'tutorial.views_title'.tr(),
              description: 'tutorial.views_desc'.tr(),
              disposeOnTap: true,
              onTargetClick: () {
                ShowcaseView.get().completed(_tabsKey); // or next()
              },
              child: TabBar(
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(
                    text: 'dashboard.chart_tab'.tr(),
                    icon: const Icon(Icons.show_chart),
                  ),
                  Tab(
                    text: 'dashboard.history_tab'.tr(),
                    icon: const Icon(Icons.history),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(children: [_buildChartTab(), _buildHistoryTab()]),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab() {
    if (_chartSpots.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int idx = value.toInt();
                      if (idx < 0 || idx >= _chronologicalHistory.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${_chronologicalHistory[idx].date.day}/${_chronologicalHistory[idx].date.month}',
                        ),
                      );
                    },
                    reservedSize: 32,
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: _chartSpots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.flash_on,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              '${item.valorContador1} kWh',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_historyDateFormat.format(item.date)),
            trailing: item.valorContador2 != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'C2: ${item.valorContador2}',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
