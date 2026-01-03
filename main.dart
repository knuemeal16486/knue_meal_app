import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// [알람 패키지 import]
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
//위젯 기능을 위한 패키지
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBaseUrl = "https://knue-meal-backend.onrender.com";

// 전역 테마 상태 관리
final ValueNotifier<Color> themeColor = ValueNotifier<Color>(
  const Color(0xFF2563EB),
);

// 20가지 색상 팔레트
const List<Color> kColorPalette = [
  Color(0xFFEF5350),
  Color(0xFFEC407A),
  Color(0xFFAB47BC),
  Color(0xFF7E57C2),
  Color(0xFF5C6BC0),
  Color(0xFF2563EB),
  Color(0xFF039BE5),
  Color(0xFF00ACC1),
  Color(0xFF00897B),
  Color(0xFF43A047),
  Color(0xFF7CB342),
  Color(0xFFC0CA33),
  Color(0xFFFDD835),
  Color(0xFFFFB300),
  Color(0xFFFB8C00),
  Color(0xFFF4511E),
  Color(0xFF6D4C41),
  Color(0xFF757575),
  Color(0xFF546E7A),
  Color(0xFF000000),
];

// -----------------------------------------------------------------------------
// 알람 서비스 클래스 (Windows 렉 방지 수정됨)
// -----------------------------------------------------------------------------
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    // [중요 수정] Windows 등 모바일이 아니면 아예 초기화를 하지 않음 (렉 방지)
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return;
    }

    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      } catch (e) {
        debugPrint("Timezone 설정 오류: $e");
      }

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestSoundPermission: false,
            requestBadgePermission: false,
            requestAlertPermission: false,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint("알림 서비스 초기화 실패: $e");
    }
  }

  Future<void> requestPermissions() async {
    // Windows에서는 실행 안 함
    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    // Windows에서는 실행 안 함
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) return;

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meal_alarm_channel',
            '식단 알림',
            channelDescription: '식사 시간 시작/종료 10분 전 알림',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint("알람 예약 중 오류: $e");
    }
  }

  Future<void> cancelAll() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) return;
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {}
  }
}

// -----------------------------------------------------------------------------
// Main 함수
// -----------------------------------------------------------------------------
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 화면 세로 고정 (모바일용)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).catchError((e) {
    // Windows에서는 회전 고정이 지원되지 않으므로 에러 무시
  });

  runApp(const MealApp());
}

class MealApp extends StatelessWidget {
  const MealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: themeColor,
      builder: (context, color, child) {
        return MaterialApp(
          title: 'KNUE Meal',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            // [색상 적용 최적화]
            colorScheme: ColorScheme.fromSeed(
              seedColor: color,
              primary: color,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF7F7FB),
            appBarTheme: AppBarTheme(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          ),
          home: const MealMainScreen(),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 메인 스크린
// -----------------------------------------------------------------------------
class MealMainScreen extends StatefulWidget {
  const MealMainScreen({super.key});

  @override
  State<MealMainScreen> createState() => _MealMainScreenState();
}

class _MealMainScreenState extends State<MealMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const TodayMealPage(),
    const MonthlyMealPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 알림 서비스 초기화 시도 (Windows는 내부에서 무시됨)
    _initNotification();
  }

  Future<void> _initNotification() async {
    await NotificationService().init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. 오늘 식단 페이지
// -----------------------------------------------------------------------------
class TodayMealPage extends StatefulWidget {
  const TodayMealPage({super.key});

  @override
  State<TodayMealPage> createState() => _TodayMealPageState();
}

class _TodayMealPageState extends State<TodayMealPage> {
  DateTime _date = DateTime.now();
  MealType _selected = MealType.lunch;
  MealSource _source = MealSource.a;
  bool _loading = false;
  String? _error;
  bool _alarmOn = false;
  Map<String, List<String>> _meals = {
    "breakfast": [],
    "lunch": [],
    "dinner": [],
  };
  int _kcal = 0;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    fetchMeals();
  }

  Future<void> fetchMeals() async {
    final int myReq = ++_reqId;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final res = await _fetchMealApi(_date, _source);
      if (myReq != _reqId) return;
      _applyMealsFromBackend(res);
      if (mounted)
        setState(() {
          _loading = false;
        });
    } catch (e) {
      if (mounted && myReq == _reqId) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _meals = {"breakfast": [], "lunch": [], "dinner": []};
        });
      }
    }
  }

  void _applyMealsFromBackend(dynamic decoded) {
    if (decoded is! Map) throw const FormatException("Invalid JSON");
    final meals = decoded["meals"];
    if (meals is! Map) throw const FormatException("Invalid response");

    // 1. 데이터 파싱
    final bf = meals["조식"] ?? meals["아침"] ?? meals["breakfast"];
    final lu = meals["중식"] ?? meals["점심"] ?? meals["lunch"];
    final di = meals["석식"] ?? meals["저녁"] ?? meals["dinner"];

    _meals = {
      "breakfast": _asStringList(bf),
      "lunch": _asStringList(lu),
      "dinner": _asStringList(di),
    };
    _kcal = int.tryParse("${decoded["kcal"] ?? 0}") ?? 0;

    // 2. [수정됨] 위젯 업데이트 부분 (여기가 문제였습니다!)
    // 4개의 재료를 모두 준비해서 넣어야 합니다.
    if (Platform.isAndroid || Platform.isIOS) {
      // 메뉴 리스트를 깔끔한 문자열로 변환 (메뉴1, 메뉴2...)
      final bText = _meals['breakfast']?.isEmpty ?? true
          ? "운영 없음"
          : _meals['breakfast']!.join(", ");
      final lText = _meals['lunch']?.isEmpty ?? true
          ? "운영 없음"
          : _meals['lunch']!.join(", ");
      final dText = _meals['dinner']?.isEmpty ?? true
          ? "운영 없음"
          : _meals['dinner']!.join(", ");

      // updateWidget 함수에 4개(제목, 아침, 점심, 저녁)를 꽉 채워 보냅니다.
      WidgetService.updateWidget("오늘의 식단", bText, lText, dText);
    }
  }

  void _changeDate(int deltaDays) {
    setState(() {
      _date = _date.add(Duration(days: deltaDays));
      _selected = MealType.lunch;
    });
    fetchMeals();
  }

  // 알람 토글 핸들러
  Future<void> _handleAlarmToggle() async {
    // Windows 체크
    if (!Platform.isAndroid && !Platform.isIOS) {
      _toast(context, "PC에서는 알람 기능이 지원되지 않습니다.");
      return;
    }

    setState(() => _alarmOn = !_alarmOn);

    if (_alarmOn) {
      await NotificationService().requestPermissions();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int alarmId = 0;
      int count = 0;

      for (var type in MealType.values) {
        final times = type.timeRange.split("~");
        final startParts = times[0].trim().split(":");
        final endParts = times[1].trim().split(":");

        final start = DateTime(
          today.year,
          today.month,
          today.day,
          int.parse(startParts[0]),
          int.parse(startParts[1]),
        );
        final end = DateTime(
          today.year,
          today.month,
          today.day,
          int.parse(endParts[0]),
          int.parse(endParts[1]),
        );

        final notifyStart = start.subtract(const Duration(minutes: 10));
        final notifyEnd = end.subtract(const Duration(minutes: 10));

        if (notifyStart.isAfter(now)) {
          await NotificationService().scheduleAlarm(
            id: alarmId++,
            title: "🍱 ${type.label} 식사 준비",
            body: "10분 뒤 식당 운영을 시작해요!",
            scheduledTime: notifyStart,
          );
          count++;
        }

        if (notifyEnd.isAfter(now)) {
          await NotificationService().scheduleAlarm(
            id: alarmId++,
            title: "⏳ ${type.label} 마감 임박",
            body: "10분 뒤 식당 운영이 마감돼요!",
            scheduledTime: notifyEnd,
          );
          count++;
        }
      }

      if (mounted) {
        if (count > 0) {
          _toast(context, "오늘 남은 식사 시간 알람이 설정되었습니다.");
        } else {
          _toast(context, "오늘 남은 식사 시간이 없습니다.");
          setState(() => _alarmOn = false);
        }
      }
    } else {
      await NotificationService().cancelAll();
      if (mounted) _toast(context, "모든 알람이 해제되었습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CommonMealLayout(
      header: _Header(
        alarmOn: _alarmOn,
        onToggleAlarm: _handleAlarmToggle,
        date: _date,
        isToday: _isSameDate(_date, DateTime.now()),
        onPrev: _loading ? null : () => _changeDate(-1),
        onNext: _loading ? null : () => _changeDate(1),
        source: _source,
        onSourceChanged: _loading
            ? null
            : (s) async {
                setState(() => _source = s);
                await fetchMeals();
              },
        sourceHint: _source == MealSource.b
            ? "B는 선택한 날짜의 요일(${_weekdayToDayParam(_date)}) 메뉴를 조회합니다."
            : null,
      ),
      content: Column(
        children: [
          const SizedBox(height: 12),
          _MealTabs(
            selected: _selected,
            onSelect: (t) => setState(() => _selected = t),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          if (!_loading && _error != null) _ErrorCard(message: _error!),
          if (!_loading)
            _MealDetailCard(
              status: _statusFor(_selected, DateTime.now(), _date),
              type: _selected,
              items: _meals[_selected.stdKey] ?? [],
              kcal: _kcal,
              onShare: () => _shareCopy(
                context,
                _date,
                _source,
                _selected,
                _meals[_selected.stdKey],
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. 월간 식단 페이지
// -----------------------------------------------------------------------------
class MonthlyMealPage extends StatefulWidget {
  const MonthlyMealPage({super.key});

  @override
  State<MonthlyMealPage> createState() => _MonthlyMealPageState();
}

class _MonthlyMealPageState extends State<MonthlyMealPage> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  MealSource _source = MealSource.a;
  MealType _selectedType = MealType.lunch;

  bool _loading = false;
  String? _error;
  Map<String, List<String>> _meals = {
    "breakfast": [],
    "lunch": [],
    "dinner": [],
  };
  int _kcal = 0;

  @override
  void initState() {
    super.initState();
    _fetchForSelectedDate();
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
        1,
      );
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      if (_focusedMonth.month != date.month) {
        _focusedMonth = DateTime(date.year, date.month, 1);
      }
    });
    _fetchForSelectedDate();
  }

  Future<void> _fetchForSelectedDate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _fetchMealApi(_selectedDate, _source);
      _applyMealsFromBackend(res);
      if (mounted)
        setState(() {
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _meals = {"breakfast": [], "lunch": [], "dinner": []};
        });
      }
    }
  }

  void _applyMealsFromBackend(dynamic decoded) {
    if (decoded is! Map) return;
    final meals = decoded["meals"];
    if (meals is! Map) return;

    final bf = meals["조식"] ?? meals["아침"] ?? meals["breakfast"];
    final lu = meals["중식"] ?? meals["점심"] ?? meals["lunch"];
    final di = meals["석식"] ?? meals["저녁"] ?? meals["dinner"];
    _meals = {
      "breakfast": _asStringList(bf),
      "lunch": _asStringList(lu),
      "dinner": _asStringList(di),
    };
    _kcal = int.tryParse("${decoded["kcal"] ?? 0}") ?? 0;
    // [추가] 위젯 데이터 업데이트 (오늘 점심 메뉴 기준)
    if (Platform.isAndroid || Platform.isIOS) {
      // 메뉴 리스트를 깔끔한 문자열로 변환 (메뉴1, 메뉴2...)
      final bText = _meals['breakfast']?.isEmpty ?? true
          ? "운영 없음"
          : _meals['breakfast']!.join(", ");
      final lText = _meals['lunch']?.isEmpty ?? true
          ? "운영 없음"
          : _meals['lunch']!.join(", ");
      final dText = _meals['dinner']?.isEmpty ?? true
          ? "운영 없음"
          : _meals['dinner']!.join(", ");

      WidgetService.updateWidget("오늘의 식단", bText, lText, dText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text(
          "월간 식단",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _SourceBtn(
                    label: "기숙사",
                    isSel: _source == MealSource.a,
                    onTap: () {
                      setState(() => _source = MealSource.a);
                      _fetchForSelectedDate();
                    },
                  ),
                  _SourceBtn(
                    label: "학생회관",
                    isSel: _source == MealSource.b,
                    onTap: () {
                      setState(() => _source = MealSource.b);
                      _fetchForSelectedDate();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(blurRadius: 10, color: Color(0x0A000000)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        "${_focusedMonth.year}년 ${_focusedMonth.month}월",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("일", style: TextStyle(color: Colors.red)),
                      Text("월"),
                      Text("화"),
                      Text("수"),
                      Text("목"),
                      Text("금"),
                      Text("토", style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _CalendarGrid(
                    focusedMonth: _focusedMonth,
                    selectedDate: _selectedDate,
                    onDateSelected: _onDateSelected,
                    primaryColor: primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.restaurant_menu,
                      size: 20,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${_selectedDate.month}월 ${_selectedDate.day}일 메뉴",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MealTabs(
                  selected: _selectedType,
                  onSelect: (t) => setState(() => _selectedType = t),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (!_loading && _error != null) _ErrorCard(message: _error!),
                if (!_loading && _error == null)
                  _MealDetailCard(
                    status: _statusFor(
                      _selectedType,
                      DateTime.now(),
                      _selectedDate,
                    ),
                    type: _selectedType,
                    items: _meals[_selectedType.stdKey] ?? [],
                    kcal: _kcal,
                    onShare: () => _shareCopy(
                      context,
                      _selectedDate,
                      _source,
                      _selectedType,
                      _meals[_selectedType.stdKey],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. 설정 페이지
// -----------------------------------------------------------------------------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: themeColor,
      builder: (context, currentColor, child) {
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "설정",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "테마 설정",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.palette, size: 24, color: currentColor),
                            const SizedBox(width: 10),
                            const Text(
                              "테마 색상 선택",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text("원하는 색상을 선택하세요."),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: kColorPalette
                              .map(
                                (color) => _ColorPickerItem(
                                  color: color,
                                  isSelected: color.value == currentColor.value,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    "앱 정보",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "KNUE Meal App",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Version 1.5.0 (Windows Fix)",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColorPickerItem extends StatelessWidget {
  final Color color;
  final bool isSelected;
  const _ColorPickerItem({required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => themeColor.value = color,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        width: 45,
        height: 45,
        transform: isSelected
            ? Matrix4.diagonal3Values(1.15, 1.15, 1.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 24)
            : null,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Classes & Widgets
// -----------------------------------------------------------------------------

Future<dynamic> _fetchMealApi(DateTime date, MealSource source) async {
  late Uri uri;
  if (source == MealSource.a) {
    uri = Uri.parse(
      "$kBaseUrl/meals-a?y=${date.year}&m=${date.month}&d=${date.day}",
    );
  } else {
    uri = Uri.parse("$kBaseUrl/meals-b?day=${_weekdayToDayParam(date)}");
  }
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}");
  return jsonDecode(utf8.decode(res.bodyBytes));
}

String _weekdayToDayParam(DateTime d) {
  switch (d.weekday) {
    case 1:
      return "mon";
    case 2:
      return "tue";
    case 3:
      return "wed";
    case 4:
      return "thu";
    case 5:
      return "fri";
    case 6:
      return "sat";
    default:
      return "sun";
  }
}

List<String> _asStringList(dynamic v) =>
    (v is List) ? v.map((e) => e.toString()).toList() : [];
bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

ServeStatus _statusFor(MealType type, DateTime now, DateTime targetDate) {
  if (!_isSameDate(now, targetDate)) return ServeStatus.waiting;
  final range = type.timeRange.split("~").map((e) => e.trim()).toList();
  final start = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(range[0].split(":")[0]),
    int.parse(range[0].split(":")[1]),
  );
  final end = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(range[1].split(":")[0]),
    int.parse(range[1].split(":")[1]),
  );
  if (now.isBefore(start)) return ServeStatus.waiting;
  if (now.isAfter(end)) return ServeStatus.closed;
  return ServeStatus.open;
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

Future<void> _shareCopy(
  BuildContext context,
  DateTime date,
  MealSource src,
  MealType type,
  List<String>? items,
) async {
  final text =
      "[KNUE ${src == MealSource.a ? '기숙사' : '학생회관'} ${date.month}/${date.day} ${type.label}]\n${(items == null || items.isEmpty) ? '메뉴 없음' : items.join(', ')}";
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) _toast(context, "메뉴 복사 완료");
}

enum MealSource { a, b }

enum MealType { breakfast, lunch, dinner }

enum ServeStatus { open, waiting, closed }

extension MealTypeX on MealType {
  String get stdKey => toString().split('.').last;
  String get label {
    switch (this) {
      case MealType.breakfast:
        return "아침";
      case MealType.lunch:
        return "점심";
      case MealType.dinner:
        return "저녁";
    }
  }

  String get timeRange {
    switch (this) {
      case MealType.breakfast:
        return "07:30 ~ 09:00";
      case MealType.lunch:
        return "11:30 ~ 13:30";
      case MealType.dinner:
        return "17:30 ~ 19:00";
    }
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Color primaryColor;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(
      focusedMonth.year,
      focusedMonth.month,
    );
    final firstDayWeekday = DateTime(
      focusedMonth.year,
      focusedMonth.month,
      1,
    ).weekday;
    final offset = firstDayWeekday % 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: daysInMonth + offset,
      itemBuilder: (context, index) {
        if (index < offset) return const SizedBox();
        final day = index - offset + 1;
        final date = DateTime(focusedMonth.year, focusedMonth.month, day);
        final isSelected = _isSameDate(date, selectedDate);
        final isToday = _isSameDate(date, DateTime.now());

        return InkWell(
          onTap: () => onDateSelected(date),
          borderRadius: BorderRadius.circular(99),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor
                  : (isToday
                        ? primaryColor.withOpacity(0.2)
                        : Colors.transparent),
              shape: BoxShape.circle,
            ),
            child: Text(
              "$day",
              style: TextStyle(
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isToday ? primaryColor : Colors.black),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourceBtn extends StatelessWidget {
  final String label;
  final bool isSel;
  final VoidCallback onTap;
  const _SourceBtn({
    required this.label,
    required this.isSel,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSel ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommonMealLayout extends StatelessWidget {
  final Widget header;
  final Widget content;
  const _CommonMealLayout({required this.header, required this.content});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7FB),
                border: Border(
                  left: BorderSide(color: Color(0xFFE5E7EB)),
                  right: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealTabs extends StatelessWidget {
  final MealType selected;
  final ValueChanged<MealType> onSelect;
  const _MealTabs({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x11000000),
          ),
        ],
      ),
      child: Row(
        children: MealType.values
            .map(
              (t) => Expanded(
                child: InkWell(
                  onTap: () => onSelect(t),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: t == selected
                          ? primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: t == selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: t == selected
                              ? primary
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MealDetailCard extends StatelessWidget {
  final ServeStatus status;
  final MealType type;
  final List<String> items;
  final int kcal;
  final VoidCallback onShare;
  const _MealDetailCard({
    required this.status,
    required this.type,
    required this.items,
    required this.kcal,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    String statusLabel = "";
    Color statusColor = Colors.grey;
    Color statusBg = Colors.grey.shade100;
    switch (status) {
      case ServeStatus.open:
        statusLabel = "식당 운영 중";
        statusColor = const Color(0xFF15803D);
        statusBg = const Color(0xFFEAF7EE);
        break;
      case ServeStatus.waiting:
        statusLabel = "식사 준비중";
        statusColor = const Color(0xFF1D4ED8);
        statusBg = const Color(0xFFEAF2FF);
        break;
      case ServeStatus.closed:
        statusLabel = "식사시간 종료";
        statusColor = const Color(0xFF64748B);
        statusBg = const Color(0xFFF1F5F9);
        break;
    }
    final bool unavailable =
        items.isEmpty ||
        items.first.contains("없음") ||
        items.first.contains("미운영");

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  type.timeRange,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: unavailable
                ? const Center(
                    child: Text(
                      "운영하지 않는 시간입니다.",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items.first,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (items.length > 1)
                        Text(
                          "+ ${items[1]}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "전체 메뉴",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 5),
                            ...items.map(
                              (e) => Text(
                                "• $e",
                                style: const TextStyle(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "ENERGY",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "$kcal kcal",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text("공유"),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.restaurant,
            label: "오늘",
            active: currentIndex == 0,
            onTap: () => onTap(0),
            color: primary,
          ),
          _NavItem(
            icon: Icons.calendar_today,
            label: "월간",
            active: currentIndex == 1,
            onTap: () => onTap(1),
            color: primary,
          ),
          _NavItem(
            icon: Icons.settings,
            label: "설정",
            active: currentIndex == 2,
            onTap: () => onTap(2),
            color: primary,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color color;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? color : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: active ? color : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  final bool alarmOn;
  final VoidCallback onToggleAlarm;
  final DateTime date;
  final bool isToday;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final MealSource source;
  final ValueChanged<MealSource>? onSourceChanged;
  final String? sourceHint;

  const _Header({
    super.key,
    required this.alarmOn,
    required this.onToggleAlarm,
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.source,
    required this.onSourceChanged,
    required this.sourceHint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mainColor = theme.colorScheme.primary;
    final tagText = source == MealSource.a ? "기숙사 식당" : "학생회관 식당";

    const wd = ["일", "월", "화", "수", "목", "금", "토"];
    final formatted =
        "${date.year}. ${date.month}. ${date.day} (${wd[date.weekday % 7]})";
    final iso =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    return Container(
      decoration: BoxDecoration(
        color: mainColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 6),
            color: Color(0x22000000),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 54, 18, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Text(
                          "KNUE 밥상",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            tagText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.place,
                          size: 14,
                          color: Color(0xFFDBEAFE),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            source == MealSource.a ? "기숙사 식당" : "학생회관 식당",
                            style: const TextStyle(
                              color: Color(0xFFDBEAFE),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onToggleAlarm,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: alarmOn
                        ? Colors.white
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    alarmOn
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    color: alarmOn ? mainColor : const Color(0xFFDBEAFE),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<MealSource>(
                    segments: const [
                      ButtonSegment(value: MealSource.a, label: Text("기숙사 식당")),
                      ButtonSegment(
                        value: MealSource.b,
                        label: Text("학생회관 식당"),
                      ),
                    ],
                    selected: {source},
                    onSelectionChanged: onSourceChanged == null
                        ? null
                        : (s) => onSourceChanged!(s.first),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith(
                        (states) => states.contains(MaterialState.selected)
                            ? Colors.white
                            : Colors.white.withOpacity(0.12),
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith(
                        (states) => states.contains(MaterialState.selected)
                            ? mainColor
                            : const Color(0xFFDBEAFE),
                      ),
                      side: MaterialStateProperty.all(
                        BorderSide(color: Colors.white.withOpacity(0.25)),
                      ),
                      textStyle: MaterialStateProperty.all(
                        const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (sourceHint != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                sourceHint!,
                style: const TextStyle(
                  color: Color(0xFFDBEAFE),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _HeaderNavBtn(icon: Icons.chevron_left, onTap: onPrev),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        isToday ? "오늘" : iso,
                        style: const TextStyle(
                          color: Color(0xFFDBEAFE),
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _HeaderNavBtn(icon: Icons.chevron_right, onTap: onNext),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderNavBtn({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 28),
      splashRadius: 22,
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool pulsing;

  const _PulsingDot({super.key, required this.color, required this.pulsing});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.pulsing) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulsing && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final scale = widget.pulsing ? (0.85 + 0.25 * _c.value) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      },
    );
  }
}

// main.dart 파일 맨 아래에 추가
class WidgetService {
  static const String androidWidgetName = 'MealWidget';

  // [수정] 인자를 3개 받도록 변경
  static Future<void> updateWidget(
    String title,
    String bf,
    String lu,
    String di,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      // SharedPreferences 저장 (백업용)
      await prefs.setString('widget_title', title);
      await prefs.setString('widget_breakfast', bf);
      await prefs.setString('widget_lunch', lu);
      await prefs.setString('widget_dinner', di);

      // HomeWidget 저장
      await HomeWidget.saveWidgetData<String>('widget_title', title);
      await HomeWidget.saveWidgetData<String>('widget_breakfast', bf);
      await HomeWidget.saveWidgetData<String>('widget_lunch', lu);
      await HomeWidget.saveWidgetData<String>('widget_dinner', di);

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (e) {
      debugPrint("위젯 업데이트 오류: $e");
    }
  }
}
