import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// =======================
// 1) 노선 설정 (번호 + URL)
// =======================
class BusRouteConfig {
  final int routeNumber;
  final String url;
  const BusRouteConfig(this.routeNumber, this.url);
}

const List<BusRouteConfig> kRoutes = [
  BusRouteConfig(
    518,
    "https://apis.data.go.kr/1613000/BusLcInfoInqireService/getRouteAcctoBusLcList?serviceKey=30cd0a0964f70dcbb2c274ae4bb9c44ba1d7ba81515c3c9d68f0e708664da513&pageNo=1&numOfRows=100&_type=json&cityCode=33010&routeId=CJB270024700",
  ),
  BusRouteConfig(
    913,
    "https://apis.data.go.kr/1613000/BusLcInfoInqireService/getRouteAcctoBusLcList?serviceKey=30cd0a0964f70dcbb2c274ae4bb9c44ba1d7ba81515c3c9d68f0e708664da513&pageNo=1&numOfRows=100&_type=json&cityCode=33010&routeId=CJB270014300",
  ),
  BusRouteConfig(
    514,
    "https://apis.data.go.kr/1613000/BusLcInfoInqireService/getRouteAcctoBusLcList?serviceKey=30cd0a0964f70dcbb2c274ae4bb9c44ba1d7ba81515c3c9d68f0e708664da513&pageNo=1&numOfRows=100&_type=json&cityCode=33010&routeId=CJB270008300",
  ),
  BusRouteConfig(
    513,
    "https://apis.data.go.kr/1613000/BusLcInfoInqireService/getRouteAcctoBusLcList?serviceKey=30cd0a0964f70dcbb2c274ae4bb9c44ba1d7ba81515c3c9d68f0e708664da513&pageNo=1&numOfRows=100&_type=json&cityCode=33010&routeId=CJB270008000",
  ),
];

// =======================
// 2) 데이터 모델
// =======================
class BusLocation {
  final double gpsLat;
  final double gpsLng;
  final String nodeId;
  final String nodeName;
  final int nodeOrd;
  final int routeNm;
  final String routeTp;
  final String vehicleNo;

  const BusLocation({
    required this.gpsLat,
    required this.gpsLng,
    required this.nodeId,
    required this.nodeName,
    required this.nodeOrd,
    required this.routeNm,
    required this.routeTp,
    required this.vehicleNo,
  });

  factory BusLocation.fromJson(Map<String, dynamic> j) {
    double toDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse("$v") ?? 0.0;
    int toInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse("$v") ?? 0;

    return BusLocation(
      gpsLat: toDouble(j["gpslati"]),
      gpsLng: toDouble(j["gpslong"]),
      nodeId: (j["nodeid"] ?? "").toString(),
      nodeName: (j["nodenm"] ?? "").toString(),
      nodeOrd: toInt(j["nodeord"]),
      routeNm: toInt(j["routenm"]),
      routeTp: (j["routetp"] ?? "").toString(),
      vehicleNo: (j["vehicleno"] ?? "").toString(),
    );
  }
}

class RouteResult {
  final int routeNumber;
  final List<BusLocation> buses;
  const RouteResult({required this.routeNumber, required this.buses});
}

// =======================
// 3) App
// =======================
void main() {
  runApp(const BusApp());
}

class BusApp extends StatelessWidget {
  const BusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Location',
      theme: ThemeData(useMaterial3: true),
      home: const BusHomePage(),
    );
  }
}

class BusHomePage extends StatefulWidget {
  const BusHomePage({super.key});

  @override
  State<BusHomePage> createState() => _BusHomePageState();
}

class _BusHomePageState extends State<BusHomePage> {
  // Meal 코드 구조 유지: 날짜/로딩/에러/데이터맵 형태
  DateTime _date = DateTime.now(); // 버스 API는 날짜 파라미터 없지만 UI 구조 유지
  bool _loading = false;
  String? _error;

  // 노선번호(String) -> 버스목록
  Map<String, List<BusLocation>> _busByRoute = {
    for (final r in kRoutes) r.routeNumber.toString(): <BusLocation>[],
  };

  @override
  void initState() {
    super.initState();
    fetchBusLocations();
  }

  Future<void> fetchBusLocations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 4개 노선을 병렬로 조회
      final results = await Future.wait(kRoutes.map(_fetchRoute));

      final nextMap = <String, List<BusLocation>>{};
      for (final rr in results) {
        nextMap[rr.routeNumber.toString()] = rr.buses;
      }

      setState(() {
        _busByRoute = nextMap;
        _date = DateTime.now(); // 조회 시각 갱신 용도
      });
    } catch (e) {
      setState(() {
        _error = "데이터를 불러오지 못했습니다.\n$e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<RouteResult> _fetchRoute(BusRouteConfig cfg) async {
    final uri = Uri.parse(cfg.url);

    final res = await http.get(
      uri,
      headers: {"Accept": "application/json"},
    );

    if (res.statusCode != 200) {
      throw Exception("노선 ${cfg.routeNumber}: HTTP ${res.statusCode}");
    }

    // 공공데이터는 UTF-8인 경우가 많지만, 안전하게 bodyBytes decode 사용
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));

    final response = decoded["response"];
    if (response == null) {
      throw Exception("노선 ${cfg.routeNumber}: response 없음");
    }

    final header = response["header"];
    final resultCode = (header?["resultCode"] ?? "").toString();
    final resultMsg = (header?["resultMsg"] ?? "").toString();
    if (resultCode != "00") {
      throw Exception("노선 ${cfg.routeNumber}: API 오류($resultCode) $resultMsg");
    }

    final body = response["body"];
    final items = body?["items"];
    final item = items?["item"];

    final List<dynamic> list;
    if (item == null) {
      list = const [];
    } else if (item is List) {
      list = item;
    } else if (item is Map<String, dynamic>) {
      // item이 1개면 List가 아니라 Map으로 올 수도 있어 방어
      list = [item];
    } else {
      list = const [];
    }

    final buses = list
        .whereType<Map>()
        .map((e) => BusLocation.fromJson(e.cast<String, dynamic>()))
        .toList();

    // 정류장 순번 기준 정렬 (보기 좋게)
    buses.sort((a, b) => a.nodeOrd.compareTo(b.nodeOrd));

    return RouteResult(routeNumber: cfg.routeNumber, buses: buses);
  }

  String fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} "
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("버스 현재 정류장"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : fetchBusLocations,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text("조회 시각: ${fmt(_date)}")),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _loading ? null : fetchBusLocations,
                  child: const Text("조회"),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // MealBlock 3개 대신 RouteBlock 4개
                for (final r in kRoutes)
                  RouteBlock(
                    title: "노선 ${r.routeNumber}",
                    items: _busByRoute[r.routeNumber.toString()] ?? const [],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// 4) 노선별 블록 UI (MealBlock 스타일 유지)
// =======================
class RouteBlock extends StatelessWidget {
  final String title;
  final List<BusLocation> items;

  const RouteBlock({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  "(${items.length}대)",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text("현재 위치 정보 없음")
            else
              ...items.map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("• 차량번호: ${b.vehicleNo}"),
                      Text("  정류장: ${b.nodeName} (순번 ${b.nodeOrd})"),
                      Text("  좌표: ${b.gpsLat.toStringAsFixed(5)}, ${b.gpsLng.toStringAsFixed(5)}"),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
