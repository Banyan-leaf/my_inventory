/// 模块：app / pages / dashboard
/// 职责：数据仪表盘主页面。
/// 约束：
///   1. 本页只做数据加载与布局，不直接绘制图表。
///   2. 监听 AppRefresh，任何数据变更都会自动刷新。
library;

import 'package:flutter/material.dart';

import '../../../core/di/port_registry.dart';
import '../../../core/refresh/app_refresh.dart';
import '../../../modules/stats/domain/entities/stats_data.dart';
import '../../../modules/stats/domain/ports/stats_port.dart';
import 'widgets/category_pie.dart';
import 'widgets/expiry_list.dart';
import 'widgets/location_ranking.dart';
import 'widgets/overview_cards.dart';
import 'widgets/status_pie.dart';
import 'widgets/tag_ranking.dart';
import 'widgets/value_trend_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Overview _overview = Overview.empty;
  List<CategorySlice> _categories = const [];
  List<StatusSlice> _statuses = const [];
  List<TimePoint> _valueTrend = const [];
  List<LocationSlice> _locations = const [];
  List<ExpiryItem> _expiry = const [];
  List<TagSlice> _tagSlices = const [];
  bool _loading = true;

  StatsPort get _port => PortRegistry.instance.resolve<StatsPort>();

  @override
  void initState() {
    super.initState();
    AppRefresh.instance.addListener(_onRefresh);
    _load();
  }

  @override
  void dispose() {
    AppRefresh.instance.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _port.overview(),
        _port.categoryDistribution(),
        _port.statusDistribution(),
        _port.valueTrend(),
        _port.locationDistribution(),
        _port.expiringSoon(),
        _port.tagDistribution(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as Overview;
        _categories = results[1] as List<CategorySlice>;
        _statuses = results[2] as List<StatusSlice>;
        _valueTrend = results[3] as List<TimePoint>;
        _locations = results[4] as List<LocationSlice>;
        _expiry = results[5] as List<ExpiryItem>;
        _tagSlices = results[6] as List<TagSlice>;
        _loading = false;
      });
    } catch (e, st) {
      // 兜底：加载失败时退出 loading，避免永远转圈。
      // ignore: avoid_print
      print('DashboardPage load failed: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据仪表盘'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  OverviewCards(data: _overview),
                  const SizedBox(height: 16),
                  _sectionTitle('分类分布'),
                  CategoryPie(slices: _categories),
                  const SizedBox(height: 16),
                  _sectionTitle('状态分布'),
                  StatusPie(slices: _statuses),
                  const SizedBox(height: 16),
                  _sectionTitle('价值趋势'),
                  ValueTrendChart(points: _valueTrend),
                  const SizedBox(height: 16),
                  _sectionTitle('位置分布'),
                  LocationRanking(slices: _locations),
                  const SizedBox(height: 16),
                  _sectionTitle('标签分布'),
                  TagRanking(slices: _tagSlices),
                  const SizedBox(height: 16),
                  _sectionTitle('即将到期 / 已过期'),
                  ExpiryList(items: _expiry),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}