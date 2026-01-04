import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const BusCatchApp());
}

class BusCatchApp extends StatelessWidget {
  const BusCatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BusCatch',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB), // bg-gray-50
        useMaterial3: true,
        fontFamily: 'Pretendard', // 기기에 폰트가 없다면 기본 폰트로 나옵니다
      ),
      home: const BusHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 데이터 모델 클래스
class Bus {
  final int id;
  final String number;
  final String type; // blue, green, red, yellow
  final String direction;
  int arrival1;
  final int? arrival2;
  final String congestion; // empty, normal, crowded
  final String currentStop;

  Bus({
    required this.id,
    required this.number,
    required this.type,
    required this.direction,
    required this.arrival1,
    this.arrival2,
    required this.congestion,
    required this.currentStop,
  });
}

class BusHomePage extends StatefulWidget {
  const BusHomePage({super.key});

  @override
  State<BusHomePage> createState() => _BusHomePageState();
}

class _BusHomePageState extends State<BusHomePage> {
  bool _loading = false;
  int _selectedIndex = 0; // Bottom Navigation Tab Index
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 즐겨찾기 ID 목록
  List<int> _favorites = [1, 4];

  // 샘플 데이터
  List<Bus> _buses = [
    Bus(id: 1, number: '143', type: 'blue', direction: '고속터미널', arrival1: 3, arrival2: 12, congestion: 'normal', currentStop: '3번째 전'),
    Bus(id: 2, number: '402', type: 'blue', direction: '광화문', arrival1: 0, arrival2: 9, congestion: 'crowded', currentStop: '진입 중'),
    Bus(id: 3, number: '6411', type: 'green', direction: '구로동', arrival1: 7, arrival2: 15, congestion: 'empty', currentStop: '5번째 전'),
    Bus(id: 4, number: '9401', type: 'red', direction: '서울역', arrival1: 18, arrival2: 35, congestion: 'normal', currentStop: '판교IC'),
    Bus(id: 5, number: '마포02', type: 'yellow', direction: '신촌역', arrival1: 4, arrival2: 10, congestion: 'empty', currentStop: '2번째 전'),
    Bus(id: 6, number: 'N26', type: 'blue', direction: '강서', arrival1: 55, arrival2: null, congestion: 'normal', currentStop: '차고지 대기'),
  ];

  // 새로고침 로직
  Future<void> _handleRefresh() async {
    setState(() {
      _loading = true;
    });

    // API 호출 시뮬레이션 (0.8초 딜레이)
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      for (var bus in _buses) {
        if (bus.arrival1 > 0) bus.arrival1 -= 1;
      }
      _loading = false;
    });
  }

  // 즐겨찾기 토글
  void _toggleFavorite(int id) {
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 필터링 로직
    final filteredBuses = _buses.where((bus) {
      return bus.number.contains(_searchQuery) || bus.direction.contains(_searchQuery);
    }).toList();

    final favoriteBuses = _buses.where((bus) => _favorites.contains(bus.id)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // 배경색
      
      // 상단 앱바
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'BusCatch',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            const Text(
              '논현역 3번 출구 정류장',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _handleRefresh,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                  )
                : const Icon(Icons.refresh, color: Colors.grey),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // 메인 바디
      body: Column(
        children: [
          // 검색창
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: '버스 번호 또는 행선지 검색',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // 리스트 영역
          Expanded(
            child: _selectedIndex == 0 // 홈 탭일 때만 리스트 표시
                ? ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      // 즐겨찾기 섹션 (검색 중이 아닐 때만)
                      if (_searchQuery.isEmpty && _favorites.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.amber),
                              SizedBox(width: 6),
                              Text('즐겨찾기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                            ],
                          ),
                        ),
                        ...favoriteBuses.map((bus) => BusCard(
                              bus: bus,
                              isFavorite: true,
                              onToggleFavorite: () => _toggleFavorite(bus.id),
                            )),
                      ],

                      // 전체 버스 섹션
                      if (_searchQuery.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_filled, size: 16, color: Colors.blue),
                              SizedBox(width: 6),
                              Text('실시간 도착 예정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                            ],
                          ),
                        ),
                      
                      if (filteredBuses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ...filteredBuses.map((bus) => BusCard(
                              bus: bus,
                              isFavorite: _favorites.contains(bus.id),
                              onToggleFavorite: () => _toggleFavorite(bus.id),
                            )),
                    ],
                  )
                : Center(child: Text('${_selectedIndex == 1 ? "주변 정류장" : "설정"} 화면 준비중입니다.')),
          ),
        ],
      ),

      // 하단 네비게이션
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: '주변 정류장'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '설정'),
          ],
        ),
      ),
    );
  }
}

// 버스 카드 위젯
class BusCard extends StatelessWidget {
  final Bus bus;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const BusCard({
    super.key,
    required this.bus,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  // 버스 타입별 색상
  Color getBusColor(String type) {
    switch (type) {
      case 'blue': return const Color(0xFF3B82F6); // Blue-500
      case 'green': return const Color(0xFF22C55E); // Green-500
      case 'red': return const Color(0xFFEF4444); // Red-500
      case 'yellow': return const Color(0xFFFACC15); // Yellow-400
      default: return Colors.grey;
    }
  }

  // 버스 타입별 텍스트 색상 (노랑 버스는 검정 글씨)
  Color getBusTextColor(String type) {
    return type == 'yellow' ? Colors.black : Colors.white;
  }

  // 혼잡도 뱃지 스타일
  Map<String, dynamic> getCongestionStyle(String level) {
    switch (level) {
      case 'empty':
        return {'text': '여유', 'color': Colors.green, 'bg': Colors.green[50]};
      case 'normal':
        return {'text': '보통', 'color': Colors.blue, 'bg': Colors.blue[50]};
      case 'crowded':
        return {'text': '혼잡', 'color': Colors.red, 'bg': Colors.red[50]};
      default:
        return {'text': '-', 'color': Colors.grey, 'bg': Colors.grey[100]};
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isArrivingSoon = bus.arrival1 <= 2;
    final bool isArrived = bus.arrival1 == 0;
    final congStyle = getCongestionStyle(bus.congestion);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)), // gray-100
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 카드 상단: 버스 번호 및 정보
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 버스 번호 뱃지
              Container(
                width: 56,
                height: 48,
                decoration: BoxDecoration(
                  color: getBusColor(bus.type),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  bus.number,
                  style: TextStyle(
                    color: getBusTextColor(bus.type),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // 방향 및 혼잡도
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bus.direction} 방면',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: congStyle['bg'],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            congStyle['text'],
                            style: TextStyle(color: congStyle['color'], fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          bus.type == 'blue' ? '간선' : bus.type == 'green' ? '지선' : bus.type == 'red' ? '광역' : '마을',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // 즐겨찾기 버튼
              GestureDetector(
                onTap: onToggleFavorite,
                child: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : Colors.grey[300],
                  size: 26,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 카드 하단: 도착 시간 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (isArrived)
                         const Text(
                          '진입 중',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else ...[
                        Text(
                          '${bus.arrival1}',
                          style: TextStyle(
                            color: isArrivingSoon ? Colors.red : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '분',
                          style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        '(${bus.currentStop})',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                  if (bus.arrival2 != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '다음 버스 ${bus.arrival2}분 후',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ),
                ],
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300]),
            ],
          )
        ],
      ),
    );
  }
}