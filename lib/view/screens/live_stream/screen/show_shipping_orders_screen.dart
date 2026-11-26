import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_route.dart';
import '../../../../data/services/api_client.dart';

class ShowShippingOrdersScreen extends StatefulWidget {
  const ShowShippingOrdersScreen({super.key, this.streamId});

  final String? streamId;

  @override
  State<ShowShippingOrdersScreen> createState() => _ShowShippingOrdersScreenState();
}

class _ShowShippingOrdersScreenState extends State<ShowShippingOrdersScreen> {
  late Future<dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<dynamic> _load() async {
    final streamId = widget.streamId;
    final response = await Get.find<ApiClient>().getData(
      '/auctions/shipping/shows${streamId == null ? '' : '/$streamId'}',
    );
    if (response.statusCode != 200) {
      throw StateError('Could not load shipping orders.');
    }
    return jsonDecode(response.body)['data'];
  }

  void _refresh() => setState(() => _data = _load());

  String _money(dynamic amount) => '\$${(amount as num? ?? 0).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping Orders'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<dynamic>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(onPressed: _refresh, child: const Text('Could not load shipping orders. Retry')),
            );
          }
          if (widget.streamId == null) {
            final shows = snapshot.data as List? ?? [];
            if (shows.isEmpty) return const Center(child: Text('No completed shows yet.'));
            return ListView.builder(
              itemCount: shows.length,
              itemBuilder: (context, index) {
                final show = shows[index] as Map;
                return ListTile(
                  title: Text(show['title']?.toString() ?? 'Live show'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.to(() => ShowShippingOrdersScreen(streamId: show['_id'].toString())),
                );
              },
            );
          }

          final data = snapshot.data as Map? ?? {};
          final shipments = data['shipments'] as List? ?? [];
          if (shipments.isEmpty) return const Center(child: Text('No paid orders for this show.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(data['show']?['title']?.toString() ?? 'Live show',
                style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final shipment in shipments)
                Card(
                  child: ExpansionTile(
                    title: Text(shipment['buyerName'].toString()),
                    subtitle: Text('${(shipment['items'] as List).length} item(s) · ${_money(shipment['total'])}'),
                    children: [
                      for (final item in shipment['items'] as List)
                        ListTile(
                          title: Text(item['title'].toString()),
                          subtitle: item['description'] == null ? null : Text(item['description'].toString()),
                          trailing: Text(_money(item['soldPrice'])),
                        ),
                      ListTile(
                        title: Text(shipment['labelUrl'] == null ? 'Get shipping label' : 'View shipping label'),
                        subtitle: shipment['trackingNumber'] == null ? null : Text(shipment['trackingNumber'].toString()),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Get.toNamed(AppRoute.trackOrder, arguments: shipment['orderId'].toString());
                          if (mounted) _refresh();
                        },
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
