import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<FlSpot> _chartSpots = [];
  List<String> _chartLabels = [];
  List<String> _historyFormattedDates = [];
  // BOLT: Pre-calculated accessibility labels to avoid O(N) tr() and StringBuffer calls during scrolling.
  List<String> _historySemantics = [];
  // BOLT: Pre-calculated consumption deltas to ensure O(1) build performance.
  List<double?> _historyDeltas = [];
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

    // BOLT: Consolidate data transformations into a single pass to reduce iteration
    // overhead and object allocations. We pre-calculate all display strings and
    // chart spots here to keep the build() method lean and responsive.
    final historyLength = history.length;
    final spots = List<FlSpot>.filled(historyLength, const FlSpot(0, 0));
    final labels = List<String>.filled(historyLength, '');
    final formattedDates = List<String>.filled(historyLength, '');
    final semantics = List<String>.filled(historyLength, '');
    final deltas = List<double?>.filled(historyLength, null);

    for (int i = 0; i < historyLength; i++) {
      final reverseIdx = historyLength - 1 - i;
      final item = history[i];

      // BOLT: Extract properties once to minimize redundant property access and list lookups.
      final date = item.date;
      final c1 = item.valorContador1;
      final c2 = item.valorContador2;
      final c3 = item.valorContador3;
      final val1 = item.val1;

      // History list uses newest-first order.
      final formattedDate = _historyDateFormat.format(date);
      formattedDates[i] = formattedDate;

      // BOLT: Pre-calculate consumption delta (difference from previous reading in chronological order).
      // Since 'history' is newest-first, the previous reading is at index i + 1.
      if (i < historyLength - 1) {
        final prevVal = history[i + 1].val1;
        if (val1 > prevVal) {
          deltas[i] = val1 - prevVal;
        }
      }

      // BOLT: Move accessibility label generation out of the build loop.
      final buffer = StringBuffer();
      buffer.write('dashboard.reading_history_item'.tr(args: [c1, formattedDate]));
      if (deltas[i] != null) {
        final d = deltas[i]!;
        buffer.write(', +${d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 2)} kWh');
      }
      if (c2?.isNotEmpty == true) buffer.write(', C2: $c2');
      if (c3?.isNotEmpty == true) buffer.write(', C3: $c3');
      semantics[i] = buffer.toString();

      // Charts use chronological order (oldest to newest). We use the same 'item'
      // but map it to 'reverseIdx' to eliminate the 'reverseItem' lookup and halving O(N) work.
      spots[reverseIdx] = FlSpot(reverseIdx.toDouble(), val1);
      labels[reverseIdx] = '${date.day}/${date.month}';
    }

    setState(() {
      _appState = state;
      _history = history;
      _chartSpots = spots;
      _chartLabels = labels;
      _historyFormattedDates = formattedDates;
      _historySemantics = semantics;
      _historyDeltas = deltas;
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

    // BOLT: Hoist Theme and ColorScheme lookups to avoid redundant InheritedWidget traversals.
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // BOLT: Hoist alpha-blended color calculations to avoid repeated math in builders.
    final primaryWithAlpha01 = colorScheme.primary.withValues(alpha: 0.1);
    final primaryWithAlpha02 = colorScheme.primary.withValues(alpha: 0.2);
    final primaryWithAlpha05 = colorScheme.primary.withValues(alpha: 0.5);

    final hasProfiles = _appState?.profiles.isNotEmpty ?? false;
    final safeIndex = hasProfiles
        ? _appState!.activeProfileIndex.clamp(0, _appState!.profiles.length - 1)
        : 0;
    final activeProfileName = hasProfiles
        ? _appState!.profiles[safeIndex].name
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
                      color: primaryWithAlpha05,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'dashboard.no_properties_desc'.tr(),
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _addProfile();
                      },
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: primaryWithAlpha05,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'dashboard.no_history'.tr(),
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final result =
                                await Navigator.pushNamed(context, '/reading');
                            if (result == true) {
                              _loadData();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: Text('dashboard.add_reading'.tr()),
                          style: FilledButton.styleFrom(
                            enabledMouseCursor: SystemMouseCursors.click,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(colorScheme, primaryWithAlpha01, primaryWithAlpha02),
      floatingActionButton: hasProfiles
          ? Showcase(
              key: _addReadingKey,
              title: 'tutorial.add_title'.tr(),
              description: 'tutorial.add_desc'.tr(),
              disposeOnTap: true,
              onTargetClick: () {
                HapticFeedback.lightImpact();
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
                    HapticFeedback.lightImpact();
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

  Widget _buildContent(
    ColorScheme colorScheme,
    Color primaryWithAlpha01,
    Color primaryWithAlpha02,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: primaryWithAlpha01,
            child: Showcase(
              key: _tabsKey,
              title: 'tutorial.views_title'.tr(),
              description: 'tutorial.views_desc'.tr(),
              disposeOnTap: true,
              onTargetClick: () {
                ShowcaseView.get().completed(_tabsKey); // or next()
              },
              child: TabBar(
                indicatorColor: colorScheme.primary,
                labelColor: colorScheme.onSurface,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                onTap: (_) => HapticFeedback.selectionClick(),
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
            child: TabBarView(children: [
              _KeepAliveWrapper(
                child: _buildChartTab(colorScheme, primaryWithAlpha02),
              ),
              _KeepAliveWrapper(child: _buildHistoryTab(colorScheme)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab(ColorScheme colorScheme, Color primaryWithAlpha02) {
    if (_chartSpots.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: RepaintBoundary(
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
                        if (idx < 0 || idx >= _chartLabels.length) {
                          return const SizedBox();
                        }
                        // BOLT: Use pre-calculated labels to avoid repeated string formatting.
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_chartLabels[idx]),
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
                    color: colorScheme.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: primaryWithAlpha02,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        // BOLT: Use pre-calculated formatted date to avoid redundant processing.
        final formattedDate = _historyFormattedDates[index];
        final delta = _historyDeltas[index];

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Semantics(
            // BOLT: Use pre-calculated semantics label for O(1) build performance.
            label: _historySemantics[index],
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: const Icon(Icons.flash_on),
              ),
              title: Row(
                children: [
                  Text(
                    '${item.valorContador1} kWh',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (delta != null) ...[
                    const SizedBox(width: 8),
                    _ConsumptionDeltaBadge(delta: delta, colorScheme: colorScheme),
                  ],
                ],
              ),
              subtitle: Text(formattedDate),
              trailing: _HistoryTrailing(item: item, colorScheme: colorScheme),
            ),
          ),
        );
      },
    );
  }
}

// BOLT: Wrapper to preserve tab state (scroll position, etc.) using AutomaticKeepAliveClientMixin.
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

// BOLT: Refactor trailing badges into a StatelessWidget to optimize widget reconstruction and reconciliation.
class _HistoryTrailing extends StatelessWidget {
  final LocalReadingHistory item;
  final ColorScheme colorScheme;

  const _HistoryTrailing({required this.item, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    if (item.valorContador2?.isNotEmpty == true) {
      badges.add(_HistoryBadge(
        label: 'C2',
        value: item.valorContador2!,
        colorScheme: colorScheme,
      ));
    }
    if (item.valorContador3?.isNotEmpty == true) {
      if (badges.isNotEmpty) {
        badges.add(const SizedBox(height: 4));
      }
      badges.add(_HistoryBadge(
        label: 'C3',
        value: item.valorContador3!,
        colorScheme: colorScheme,
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: badges,
    );
  }
}

class _HistoryBadge extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _HistoryBadge({
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// PALETTE: Display consumption delta with visual delight and clarity.
class _ConsumptionDeltaBadge extends StatelessWidget {
  final double delta;
  final ColorScheme colorScheme;

  const _ConsumptionDeltaBadge({required this.delta, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up,
            size: 14,
            color: colorScheme.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            '+${delta.toStringAsFixed(delta.truncateToDouble() == delta ? 0 : 2)}',
            style: TextStyle(
              color: colorScheme.secondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
