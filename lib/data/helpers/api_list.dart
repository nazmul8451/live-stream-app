/// Extracts the item list from any of the backend's response shapes:
///   { data: [...] }
///   { data: { meta, data: [...] } }   (paginated)
///   { products: [...] } / { result: [...] }
List<Map<String, dynamic>> extractApiList(dynamic body) {
  dynamic raw = body;
  if (raw is Map) {
    raw = raw['data'] ?? raw['products'] ?? raw['result'];
    if (raw is Map) {
      raw = raw['data'] ?? raw['items'] ?? raw['result'];
    }
  }
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

/// True when a product can still be sold / auctioned / given away.
bool isProductAvailable(Map<String, dynamic> p) {
  final status = (p['status'] ?? 'active').toString();
  final stock = p['stock'];
  final hasStock = stock == null || (num.tryParse('$stock') ?? 1) > 0;
  return status == 'active' && hasStock && p['isSold'] != true;
}
