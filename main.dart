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

// API 주소
const String kBaseUrl = "https://knue-meal-api.onrender.com";

// 전역 테마 상태 관리
final ValueNotifier<Color> themeColor = ValueNotifier<Color>(
  const Color(0xFF2563EB),
);

// 다크모드 상태 관리
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
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
// 알람 서비스 클래스
// -----------------------------------------------------------------------------
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) return;
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
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).catchError((e) {});

  runApp(const MealApp());
}

class MealApp extends StatelessWidget {
  const MealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: themeColor,
      builder: (context, color, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              title: 'KNUE Meal',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              // [라이트 테마]
              theme: ThemeData(
                useMaterial3: true,
                fontFamilyFallback: const [
                  'Pretendard',
                  'Apple SD Gothic Neo',
                  'Noto Sans KR',
                  'sans-serif',
                ],
                // [수정] primary 색상을 사용자가 선택한 색(color)으로 강제 지정하여 정확히 일치시킴
                colorScheme: ColorScheme.fromSeed(
                  seedColor: color,
                  primary: color,
                  brightness: Brightness.light,
                  surface: const Color(0xFFF8F9FA),
                ),
                scaffoldBackgroundColor: const Color(0xFFF8F9FA),
                appBarTheme: AppBarTheme(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                cardColor: Colors.white,
                textTheme: const TextTheme(
                  bodyMedium: TextStyle(
                    letterSpacing: -0.3,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                  bodyLarge: TextStyle(
                    letterSpacing: -0.3,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              // [다크 테마]
              darkTheme: ThemeData(
                useMaterial3: true,
                fontFamilyFallback: const [
                  'Pretendard',
                  'Apple SD Gothic Neo',
                  'Noto Sans KR',
                  'sans-serif',
                ],
                colorScheme: ColorScheme.fromSeed(
                  seedColor: color,
                  // 다크모드에서도 포인트 컬러는 유지
                  primary: color,
                  brightness: Brightness.dark,
                  surface: const Color(0xFF1E1E1E),
                ),
                scaffoldBackgroundColor: const Color(0xFF121212),
                appBarTheme: AppBarTheme(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                cardColor: const Color(0xFF1E1E1E),
                textTheme: const TextTheme(
                  bodyMedium: TextStyle(
                    letterSpacing: -0.3,
                    fontSize: 15,
                    color: Color(0xFFEEEEEE),
                  ),
                  bodyLarge: TextStyle(
                    letterSpacing: -0.3,
                    fontSize: 16,
                    color: Color(0xFFEEEEEE),
                  ),
                ),
              ),
              home: const MealMainScreen(),
            );
          },
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
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _updateSelectionByTime();
    fetchMeals();
  }

  void _updateSelectionByTime() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour < 9) {
      _selected = MealType.breakfast;
    } else if (hour < 14) {
      _selected = MealType.lunch;
    } else {
      _selected = MealType.dinner;
    }
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
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted && myReq == _reqId) {
        setState(() {
          _error = "식단 정보를 가져올 수 없습니다.";
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
    final bf = meals["조식"] ?? meals["아침"] ?? meals["breakfast"];
    final lu = meals["중식"] ?? meals["점심"] ?? meals["lunch"];
    final di = meals["석식"] ?? meals["저녁"] ?? meals["dinner"];
    _meals = {
      "breakfast": _asStringList(bf),
      "lunch": _asStringList(lu),
      "dinner": _asStringList(di),
    };
  }

  void _changeDate(int deltaDays) {
    setState(() {
      _date = _date.add(Duration(days: deltaDays));
    });
    fetchMeals();
  }

  Future<void> _handleAlarmToggle() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _toast(context, "모바일 환경에서만 알람 설정이 가능합니다.");
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
            body: "10분 뒤 식당 운영을 시작합니다!",
            scheduledTime: notifyStart,
          );
          count++;
        }
        if (notifyEnd.isAfter(now)) {
          await NotificationService().scheduleAlarm(
            id: alarmId++,
            title: "⏳ ${type.label} 마감 임박",
            body: "10분 뒤 식당 운영이 종료됩니다!",
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
      if (mounted) _toast(context, "알람이 해제되었습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDate(_date, DateTime.now());

    return _CommonMealLayout(
      header: _Header(
        alarmOn: _alarmOn,
        onToggleAlarm: _handleAlarmToggle,
        date: _date,
        isToday: isToday,
        onPrev: _loading ? null : () => _changeDate(-1),
        onNext: _loading ? null : () => _changeDate(1),
        source: _source,
        onSourceChanged: _loading
            ? null
            : (s) async {
                setState(() => _source = s);
                await fetchMeals();
              },
      ),
      content: Column(
        children: [
          const SizedBox(height: 16),
          _MealTabs(
            selected: _selected,
            onSelect: (t) => setState(() => _selected = t),
          ),
          const SizedBox(height: 16),

          if (_loading)
            SizedBox(
              height: 300,
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),

          if (!_loading && _error != null) _ErrorCard(message: _error!),

          if (!_loading && _error == null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _MealDetailCard(
                key: ValueKey("$_date-$_selected-$_source"),
                status: _statusFor(_selected, DateTime.now(), _date),
                type: _selected,
                items: _meals[_selected.stdKey] ?? [],
                isToday: isToday,
                onShare: () => _shareCopy(
                  context,
                  _date,
                  _source,
                  _selected,
                  _meals[_selected.stdKey],
                ),
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
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "정보 없음";
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
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isToday = _isSameDate(_selectedDate, DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "월간 식단",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<MealSource>(
              value: _source,
              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              selectedItemBuilder: (context) {
                return [
                  const Center(
                    child: Text(
                      "기숙사 식당",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      "학생회관 식당",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ];
              },
              items: [
                DropdownMenuItem(
                  value: MealSource.a,
                  child: Text(
                    "기숙사 식당",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: MealSource.b,
                  child: Text(
                    "학생회관 식당",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _source = val);
                  _fetchForSelectedDate();
                }
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "${_focusedMonth.year}.${_focusedMonth.month.toString().padLeft(2, '0')}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        "일",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text("월", style: TextStyle(color: Colors.grey)),
                      Text("화", style: TextStyle(color: Colors.grey)),
                      Text("수", style: TextStyle(color: Colors.grey)),
                      Text("목", style: TextStyle(color: Colors.grey)),
                      Text("금", style: TextStyle(color: Colors.grey)),
                      Text(
                        "토",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CalendarGrid(
                    focusedMonth: _focusedMonth,
                    selectedDate: _selectedDate,
                    onDateSelected: _onDateSelected,
                    primaryColor: primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        size: 20,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "${_selectedDate.month}월 ${_selectedDate.day}일 메뉴",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MealTabs(
                  selected: _selectedType,
                  onSelect: (t) => setState(() => _selectedType = t),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  _ErrorCard(message: _error!)
                else
                  _MealDetailCard(
                    status: _statusFor(
                      _selectedType,
                      DateTime.now(),
                      _selectedDate,
                    ),
                    type: _selectedType,
                    items: _meals[_selectedType.stdKey] ?? [],
                    isToday: isToday,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<Color>(
      valueListenable: themeColor,
      builder: (context, currentColor, child) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: currentColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    "설정",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  background: Container(color: currentColor),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "앱 테마",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(10),
                          child: ValueListenableBuilder<ThemeMode>(
                            valueListenable: themeModeNotifier,
                            builder: (context, mode, _) {
                              return Row(
                                children: [
                                  _ThemeOption(
                                    label: "라이트",
                                    icon: Icons.light_mode,
                                    selected: mode == ThemeMode.light,
                                    onTap: () => themeModeNotifier.value =
                                        ThemeMode.light,
                                  ),
                                  _ThemeOption(
                                    label: "다크",
                                    icon: Icons.dark_mode,
                                    selected: mode == ThemeMode.dark,
                                    onTap: () => themeModeNotifier.value =
                                        ThemeMode.dark,
                                  ),
                                  _ThemeOption(
                                    label: "시스템",
                                    icon: Icons.settings_brightness,
                                    selected: mode == ThemeMode.system,
                                    onTap: () => themeModeNotifier.value =
                                        ThemeMode.system,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Text(
                          "테마 색상",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: kColorPalette
                                .map(
                                  (color) => _ColorPickerItem(
                                    color: color,
                                    isSelected:
                                        color.value == currentColor.value,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Text(
                          "앱 정보",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.restaurant,
                                size: 48,
                                color: currentColor.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "KNUE Meal",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "버전 2.5.1 (UI Fix)",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : Colors.grey,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI 개선된 위젯들
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final bool alarmOn;
  final VoidCallback onToggleAlarm;
  final DateTime date;
  final bool isToday;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final MealSource source;
  final ValueChanged<MealSource>? onSourceChanged;

  const _Header({
    required this.alarmOn,
    required this.onToggleAlarm,
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.source,
    required this.onSourceChanged,
  });

  void _showCafeteriaInfo(BuildContext context) {
    final isDorm = source == MealSource.a;
    final location = isDorm ? "관리동 1층" : "학생회관 1층";
    final price = isDorm ? "의무입사생 무료" : "5,000원 (일반)";
    final operation = isDorm ? "연중무휴" : "주말/공휴일 휴무";
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 40,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "식당 운영 정보",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.place, "위치", location),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.attach_money, "가격", price),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.access_time, "운영", operation),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "닫기",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Theme.of(context).primaryColor가 이제 seedColor와 정확히 일치함
    final color = theme.colorScheme.primary;

    const wd = ["", "월", "화", "수", "목", "금", "토", "일"];
    final weekdayStr = "${wd[date.weekday]}요일";
    final fullDateStr =
        "${date.year}년 ${date.month.toString().padLeft(2, '0')}월 ${date.day.toString().padLeft(2, '0')}일";

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 8),
            color: color.withOpacity(0.4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 10,
        20,
        24,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      "KNUE 청람밥상",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showCafeteriaInfo(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleAlarm,
                icon: Icon(
                  alarmOn
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  color: Colors.white.withOpacity(alarmOn ? 1.0 : 0.7),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildSegmentBtn("기숙사 식당", MealSource.a),
                _buildSegmentBtn("학생회관 식당", MealSource.b),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              Column(
                children: [
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "오늘의 식단",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    weekdayStr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fullDateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentBtn(String title, MealSource val) {
    final isSel = source == val;
    return Expanded(
      child: GestureDetector(
        onTap: onSourceChanged == null ? null : () => onSourceChanged!(val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSel ? Colors.black87 : Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _MealDetailCard extends StatelessWidget {
  final ServeStatus status;
  final MealType type;
  final List<String> items;
  final bool isToday;
  final VoidCallback onShare;

  const _MealDetailCard({
    super.key,
    required this.status,
    required this.type,
    required this.items,
    required this.isToday,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case ServeStatus.open:
        statusColor = const Color(0xFF2E7D32); // 진한 초록
        statusText = "식당 운영 중";
        statusIcon = Icons.soup_kitchen;
        break;
      case ServeStatus.waiting:
        statusColor = const Color(0xFF1976D2); // 파랑
        statusText = "식사 준비 중";
        statusIcon = Icons.access_time;
        break;
      case ServeStatus.closed:
        statusColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;
        statusText = "운영 종료";
        statusIcon = Icons.block;
        break;
      case ServeStatus.notToday:
        statusColor = isDark ? Colors.grey.shade600 : Colors.grey.shade500;
        statusText = "식당 운영시간 아님";
        statusIcon = Icons.calendar_today_rounded;
        break;
    }

    final bool unavailable =
        items.isEmpty ||
        items.first.contains("없음") ||
        items.first.contains("미운영");

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: isToday
            ? Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                width: 2,
              )
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: isToday
                ? Theme.of(context).primaryColor.withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isToday
                  ? Theme.of(context).primaryColor.withOpacity(0.03)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                ),
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "TODAY",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                Text(
                  type.timeRange,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: unavailable
                ? const Center(
                    child: Column(
                      children: [
                        Icon(Icons.no_meals, size: 40, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          "메뉴 정보가 없습니다.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 첫 번째 메뉴 (보통 밥/국)
                      if (items.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                items.first,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      // 나머지 메뉴들 (강조 로직 삭제)
                      if (items.length > 1)
                        ...List.generate(items.length - 1, (index) {
                          final menuIndex = index + 1;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    items[menuIndex],
                                    style: TextStyle(
                                      // [수정] 모든 메뉴 동일한 스타일 적용 (강조 삭제)
                                      fontSize: 16,
                                      fontWeight: FontWeight.normal,
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
          ),

          if (!unavailable)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: GestureDetector(
                onTap: onShare,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.transparent : Colors.grey.shade300,
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy,
                        size: 16,
                        color: isDark ? Colors.white : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "메뉴 복사하기",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MealTabs extends StatelessWidget {
  final MealType selected;
  final ValueChanged<MealType> onSelect;
  const _MealTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: MealType.values.map((t) {
            final isSel = t == selected;
            final primary = Theme.of(context).colorScheme.primary;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel
                        ? primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t.icon,
                        size: 18,
                        color: isSel ? primary : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: isSel ? primary : Colors.grey.shade400,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                  ),
                ],
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, Icons.restaurant, "오늘 식단"),
              _buildNavItem(context, 1, Icons.calendar_month_rounded, "월간 식단"),
              _buildNavItem(context, 2, Icons.settings_rounded, "환경설정"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final isSel = index == currentIndex;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSel ? primary : Colors.grey),
            if (isSel) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: daysInMonth + offset,
      itemBuilder: (context, index) {
        if (index < offset) return const SizedBox();
        final day = index - offset + 1;
        final date = DateTime(focusedMonth.year, focusedMonth.month, day);
        final isSelected = _isSameDate(date, selectedDate);
        final isToday = _isSameDate(date, DateTime.now());

        return GestureDetector(
          onTap: () => onDateSelected(date),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor
                  : (isToday
                        ? primaryColor.withOpacity(0.1)
                        : Colors.transparent),
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: primaryColor)
                  : null,
            ),
            child: Text(
              "$day",
              style: TextStyle(
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isToday
                          ? primaryColor
                          : (isDark ? Colors.white : Colors.black87)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CommonMealLayout extends StatelessWidget {
  final Widget header;
  final Widget content;

  const _CommonMealLayout({
    super.key,
    required this.header,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Logic Helpers
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
  if (res.statusCode != 200) throw Exception("서버 응답 오류 (${res.statusCode})");
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
  if (!_isSameDate(now, targetDate)) return ServeStatus.notToday;
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
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(20),
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
      "[KNUE ${src == MealSource.a ? '기숙사 식당' : '학생회관 식당'} ${date.month}/${date.day} ${type.label}]\n${(items == null || items.isEmpty) ? '메뉴 없음' : items.join(', ')}";
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) _toast(context, "메뉴가 클립보드에 복사되었습니다.");
}

enum MealSource { a, b }

enum MealType { breakfast, lunch, dinner }

enum ServeStatus { open, waiting, closed, notToday }

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

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.wb_twilight_rounded;
      case MealType.lunch:
        return Icons.wb_sunny_rounded;
      case MealType.dinner:
        return Icons.nights_stay_rounded;
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
