import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// [알람 패키지]
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// [설정 저장 패키지]
import 'package:shared_preferences/shared_preferences.dart';

// [공유 패키지]
import 'package:share_plus/share_plus.dart';

// API 주소
const String kBaseUrl = "https://knue-meal-api.onrender.com";

// 전역 상태 관리
final ValueNotifier<Color> themeColor = ValueNotifier<Color>(const Color(0xFF2563EB));
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
final ValueNotifier<MealSource> defaultSourceNotifier = ValueNotifier<MealSource>(MealSource.a);

// 20가지 색상 팔레트
const List<Color> kColorPalette = [
  Color(0xFFEF5350), Color(0xFFEC407A), Color(0xFFAB47BC), Color(0xFF7E57C2),
  Color(0xFF5C6BC0), Color(0xFF2563EB), Color(0xFF039BE5), Color(0xFF00ACC1),
  Color(0xFF00897B), Color(0xFF43A047), Color(0xFF7CB342), Color(0xFFC0CA33),
  Color(0xFFFDD835), Color(0xFFFFB300), Color(0xFFFB8C00), Color(0xFFF4511E),
  Color(0xFF6D4C41), Color(0xFF757575), Color(0xFF546E7A), Color(0xFF000000),
];

// -----------------------------------------------------------------------------
// 설정 저장 서비스
// -----------------------------------------------------------------------------
class PreferencesService {
  static const String keyThemeColor = 'theme_color';
  static const String keyThemeMode = 'theme_mode';
  static const String keyMealSource = 'meal_source';

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final int? colorValue = prefs.getInt(keyThemeColor);
    if (colorValue != null) themeColor.value = Color(colorValue);
    final int? modeIndex = prefs.getInt(keyThemeMode);
    if (modeIndex != null) themeModeNotifier.value = ThemeMode.values[modeIndex];
    final int? sourceIndex = prefs.getInt(keyMealSource);
    if (sourceIndex != null) defaultSourceNotifier.value = MealSource.values[sourceIndex];
  }

  static Future<void> saveThemeColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyThemeColor, color.value);
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyThemeMode, mode.index);
  }

  static Future<void> saveMealSource(MealSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyMealSource, source.index);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    themeColor.value = const Color(0xFF2563EB);
    themeModeNotifier.value = ThemeMode.system;
    defaultSourceNotifier.value = MealSource.a;
  }
}

// -----------------------------------------------------------------------------
// 알람 서비스
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
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.loadSettings();
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
                fontFamilyFallback: const ['Pretendard', 'Apple SD Gothic Neo', 'Noto Sans KR', 'sans-serif'],
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
                  bodyMedium: TextStyle(letterSpacing: -0.3, fontSize: 15, color: Colors.black87),
                  bodyLarge: TextStyle(letterSpacing: -0.3, fontSize: 16, color: Colors.black87),
                ),
              ),
              // [다크 테마]
              darkTheme: ThemeData(
                useMaterial3: true,
                fontFamilyFallback: const ['Pretendard', 'Apple SD Gothic Neo', 'Noto Sans KR', 'sans-serif'],
                colorScheme: ColorScheme.fromSeed(
                  seedColor: color,
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
                  bodyMedium: TextStyle(letterSpacing: -0.3, fontSize: 15, color: Color(0xFFEEEEEE)),
                  bodyLarge: TextStyle(letterSpacing: -0.3, fontSize: 16, color: Color(0xFFEEEEEE)),
                ),
                iconTheme: const IconThemeData(color: Colors.white70),
              ),
              home: const MealMainScreen(),
            );
          },
        );
      },
    );
  }
}

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
  MealSource _source = defaultSourceNotifier.value;
  bool _loading = false;
  String? _error;
  bool _alarmOn = false;
  Map<String, List<String>> _meals = {"breakfast": [], "lunch": [], "dinner": []};
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
    if (mounted) setState(() { _loading = true; _error = null; });
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

  void _changeDate(int deltaDays) {
    setState(() {
      _date = _date.add(Duration(days: deltaDays));
    });
    fetchMeals();
  }

  void _handleHorizontalDrag(DragEndDetails details) {
    if (details.primaryVelocity! > 0) {
      _changeDate(-1);
    } else if (details.primaryVelocity! < 0) {
      _changeDate(1);
    }
  }

  Future<void> _handleAlarmToggle() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _toast(context, "모바일 환경에서만 알람 설정이 가능합니다.");
      return;
    }
    setState(() => _alarmOn = !_alarmOn);
    if (_alarmOn) {
      await NotificationService().requestPermissions();
      _toast(context, "식사 알람이 설정되었습니다.");
    } else {
      await NotificationService().cancelAll();
      _toast(context, "알람이 해제되었습니다.");
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
                PreferencesService.saveMealSource(s);
                await fetchMeals();
              },
      ),
      content: GestureDetector(
        onHorizontalDragEnd: _handleHorizontalDrag,
        child: Column(
          children: [
            const SizedBox(height: 16),
            _MealTabs(selected: _selected, onSelect: (t) => setState(() => _selected = t)),
            const SizedBox(height: 16),
            if (_loading)
              SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)))
            else if (_error != null)
              _ErrorCard(message: _error!)
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _MealDetailCard(
                  key: ValueKey("$_date-$_selected-$_source"),
                  status: _statusFor(_selected, DateTime.now(), _date),
                  type: _selected,
                  items: _meals[_selected.stdKey] ?? [],
                  isToday: isToday,
                  onShare: () => _shareMenu(context, _date, _source, _selected, _meals[_selected.stdKey]),
                ),
              ),
          ],
        ),
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
  MealSource _source = defaultSourceNotifier.value;
  MealType _selectedType = MealType.lunch;
  bool _loading = false;
  String? _error;
  Map<String, List<String>> _meals = {"breakfast": [], "lunch": [], "dinner": []};

  @override
  void initState() {
    super.initState();
    _fetchForSelectedDate();
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
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
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _fetchMealApi(_selectedDate, _source);
      _applyMealsFromBackend(res);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = "정보 없음"; _loading = false; _meals = {"breakfast": [], "lunch": [], "dinner": []}; });
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
        title: const Text("월간 식단", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                  const Center(child: Text("기숙사 식당", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const Center(child: Text("학생회관 식당", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ];
              },
              items: [
                DropdownMenuItem(value: MealSource.a, child: Text("기숙사 식당", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                DropdownMenuItem(value: MealSource.b, child: Text("학생회관 식당", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
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
                boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.05), offset: const Offset(0, 10))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left, color: Colors.grey)),
                      Text("${_focusedMonth.year}.${_focusedMonth.month.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("일", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      Text("월", style: TextStyle(color: Colors.grey)),
                      Text("화", style: TextStyle(color: Colors.grey)),
                      Text("수", style: TextStyle(color: Colors.grey)),
                      Text("목", style: TextStyle(color: Colors.grey)),
                      Text("금", style: TextStyle(color: Colors.grey)),
                      Text("토", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CalendarGrid(
                    focusedMonth: _focusedMonth,
                    selectedDate: _selectedDate,
                    onDateSelected: _onDateSelected,
                    primaryColor: primary,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(context, isToday: true, isSelected: false, label: "오늘"),
                      const SizedBox(width: 20),
                      _buildLegendItem(context, isToday: false, isSelected: true, label: "선택됨"),
                    ],
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
                      decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.restaurant_menu, size: 20, color: primary),
                    ),
                    const SizedBox(width: 10),
                    Text("${_selectedDate.month}월 ${_selectedDate.day}일 메뉴", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                _MealTabs(selected: _selectedType, onSelect: (t) => setState(() => _selectedType = t)),
                const SizedBox(height: 16),
                if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                else if (_error != null) _ErrorCard(message: _error!)
                else _MealDetailCard(status: _statusFor(_selectedType, DateTime.now(), _selectedDate), type: _selectedType, items: _meals[_selectedType.stdKey] ?? [], isToday: isToday, onShare: () => _shareMenu(context, _selectedDate, _source, _selectedType, _meals[_selectedType.stdKey])),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, {required bool isToday, required bool isSelected, required String label}) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            shape: BoxShape.circle,
            border: (isToday && !isSelected) ? Border.all(color: primary, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
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
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: currentColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text("설정", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                        _buildSectionTitle("앱 테마"),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                          padding: const EdgeInsets.all(10),
                          child: ValueListenableBuilder<ThemeMode>(
                            valueListenable: themeModeNotifier,
                            builder: (context, mode, _) {
                              return Row(
                                children: [
                                  _ThemeOption(label: "라이트", icon: Icons.light_mode, selected: mode == ThemeMode.light, onTap: () { themeModeNotifier.value = ThemeMode.light; PreferencesService.saveThemeMode(ThemeMode.light); }),
                                  _ThemeOption(label: "다크", icon: Icons.dark_mode, selected: mode == ThemeMode.dark, onTap: () { themeModeNotifier.value = ThemeMode.dark; PreferencesService.saveThemeMode(ThemeMode.dark); }),
                                  _ThemeOption(label: "시스템", icon: Icons.settings_brightness, selected: mode == ThemeMode.system, onTap: () { themeModeNotifier.value = ThemeMode.system; PreferencesService.saveThemeMode(ThemeMode.system); }),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildSectionTitle("테마 색상"),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                          padding: const EdgeInsets.all(20),
                          child: Wrap(
                            spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
                            children: kColorPalette.map((color) => _ColorPickerItem(color: color, isSelected: color.value == currentColor.value)).toList(),
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildSectionTitle("앱 정보 및 지원"),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Column(
                            children: [
                              _buildSettingTile(context, icon: Icons.info_outline, title: "버전 정보", subtitle: "3.5.0 (Stable)", onTap: () {}),
                              const Divider(height: 1, indent: 20, endIndent: 20),
                              _buildSettingTile(context, icon: Icons.email_outlined, title: "문의하기", subtitle: "버그 신고 및 기능 제안", onTap: () => _toast(context, "준비 중입니다.")),
                              const Divider(height: 1, indent: 20, endIndent: 20),
                              _buildSettingTile(context, icon: Icons.description_outlined, title: "오픈소스 라이선스", onTap: () => showLicensePage(context: context, applicationName: "KNUE Meal", applicationVersion: "3.5.0")),
                              const Divider(height: 1, indent: 20, endIndent: 20),
                              _buildSettingTile(context, icon: Icons.refresh_rounded, title: "설정 초기화", iconColor: Colors.redAccent, titleColor: Colors.redAccent, onTap: () async { await PreferencesService.clearAll(); _toast(context, "초기화되었습니다."); }),
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

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 16, left: 4), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
  }

  Widget _buildSettingTile(BuildContext context, {required IconData icon, required String title, String? subtitle, Color? iconColor, Color? titleColor, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final iconBgColor = iconColor != null ? iconColor.withOpacity(0.1) : (isDark ? Colors.grey.shade800 : primary.withOpacity(0.1));
    final effectiveIconColor = iconColor ?? (isDark ? Colors.white : primary);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: effectiveIconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: titleColor ?? (isDark ? Colors.white : Colors.black87))),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)) : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

// -----------------------------------------------------------------------------
// [신규] 버스 앱 화면
// -----------------------------------------------------------------------------
class BusAppScreen extends StatefulWidget {
  const BusAppScreen({super.key});
  @override
  State<BusAppScreen> createState() => _BusAppScreenState();
}

class _BusAppScreenState extends State<BusAppScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBus = "513";
  bool _isWeekend = false;
  int _directBusTime = 25;
  String _directBusNo = "513";
  int _tapyeonBusTime = 3;
  String _tapyeonBusNo = "502";
  final int _walkingTime = 15;

  final Map<String, Map<String, List<String>>> _busSchedules = {
    "513": {
      "weekday": ["06:20", "06:42", "07:05", "07:27", "07:50", "08:12", "08:35", "08:57", "09:20", "09:45", "10:10", "10:35", "11:00", "11:25", "11:50", "12:15", "12:40", "13:05", "13:30", "13:55", "14:20", "14:45", "15:10", "15:35", "16:00", "16:25", "16:50", "17:15", "17:40", "18:05", "18:30", "18:55", "19:20", "19:45", "20:10", "20:35", "21:00", "21:25", "21:50", "22:15"],
      "holiday": ["06:20", "06:55", "07:30", "08:05", "08:40", "09:15", "09:50", "10:25", "11:00", "11:35", "12:10", "12:45", "13:20", "13:55", "14:30", "15:05", "15:40", "16:15", "16:50", "17:25", "18:00", "18:35", "19:10", "19:45", "20:20", "20:55", "21:30", "22:05"]
    },
    "514": {
      "weekday": ["06:10", "07:40", "09:10", "10:40", "12:10", "13:40", "15:10", "16:40", "18:10", "19:40", "21:10", "22:30"],
      "holiday": ["06:10", "07:50", "09:30", "11:10", "12:50", "14:30", "16:10", "17:50", "19:30", "21:10", "22:30"]
    },
    "518": {
      "weekday": ["06:30", "07:15", "08:00", "08:45", "09:30", "10:15", "11:00", "11:45", "12:30", "13:15", "14:00", "14:45", "15:30", "16:15", "17:00", "17:45", "18:30", "19:15", "20:00", "20:45", "21:30"],
      "holiday": ["06:30", "07:30", "08:30", "09:30", "10:30", "11:30", "12:30", "13:30", "14:30", "15:30", "16:30", "17:30", "18:30", "19:30", "20:30", "21:30"]
    }
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _refreshData() {
    setState(() {
      _directBusTime = (DateTime.now().second % 30) + 5;
      _tapyeonBusTime = (DateTime.now().second % 10) + 2;
      _toast(context, "버스 정보를 업데이트했습니다.");
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("청람버스", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh))],
        bottom: TabBar(controller: _tabController, labelColor: Colors.white, unselectedLabelColor: Colors.white60, indicatorColor: Colors.white, indicatorWeight: 3, tabs: const [Tab(text: "버스 시간표"), Tab(text: "스마트 경로 추천")]),
      ),
      body: TabBarView(controller: _tabController, children: [_buildTimetableTab(isDark, primary), _buildSmartRouteTab(isDark, primary)]),
    );
  }

  Widget _buildTimetableTab(bool isDark, Color primary) {
    final List<String> timeList = _busSchedules[_selectedBus]?[_isWeekend ? "holiday" : "weekday"] ?? [];
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    int nextBusIndex = -1;
    for (int i = 0; i < timeList.length; i++) {
      final parts = timeList[i].split(":");
      final busMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (busMinutes >= currentMinutes) {
        nextBusIndex = i;
        break;
      }
    }

    return Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: ["513", "514", "518"].map((busNo) { final isSelected = _selectedBus == busNo; return GestureDetector(onTap: () => setState(() => _selectedBus = busNo), child: Container(margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? primary : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? primary : Colors.grey.withOpacity(0.5))), child: Text("$busNo번", style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold)))); }).toList()),
        const SizedBox(height: 16),
        Container(decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: _buildDayToggle("평일", !_isWeekend, () => setState(() => _isWeekend = false), isDark, primary)), Expanded(child: _buildDayToggle("휴일 (토/일/공)", _isWeekend, () => setState(() => _isWeekend = true), isDark, primary))]))
      ])),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: timeList.length, itemBuilder: (context, index) {
        final time = timeList[index];
        bool passed = false;
        if (nextBusIndex == -1) passed = true; else passed = index < nextBusIndex;
        final isNext = index == nextBusIndex;
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isNext ? primary.withOpacity(0.05) : Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: isNext ? Border.all(color: primary, width: 2) : Border.all(color: Colors.transparent), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.access_time_filled, color: isNext ? primary : (passed ? Colors.grey : (isDark ? Colors.white70 : Colors.black54)), size: 20), const SizedBox(width: 12), Text(time, style: TextStyle(fontSize: 18, fontWeight: isNext ? FontWeight.w900 : FontWeight.w600, color: passed ? Colors.grey : (isDark ? Colors.white : Colors.black87), decoration: passed ? TextDecoration.lineThrough : null))]), if (isNext) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20)), child: const Text("곧 도착", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))) else if (passed) const Text("출발함", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500))]));
      }))
    ]);
  }

  Widget _buildSmartRouteTab(bool isDark, Color primary) {
    final int directTotal = _directBusTime;
    final int tapyeonTotal = _tapyeonBusTime + _walkingTime;
    final bool isTapyeonFaster = tapyeonTotal < directTotal;
    final int timeSaved = (directTotal - tapyeonTotal).abs();
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("지금 교원대까지 가장 빠른 방법은?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 20),
      _buildRouteCard(isDark: isDark, primary: const Color(0xFF2E7D32), title: isTapyeonFaster ? "탑연삼거리 하차 + 도보" : "교원대 직행 버스", badge: "추천 경로", time: "${isTapyeonFaster ? tapyeonTotal : directTotal}분 소요", detail: isTapyeonFaster ? "버스 $_tapyeonBusTime분 대기 + 걷기 $_walkingTime분" : "버스 $_directBusTime분 대기 후 도착", busNumber: isTapyeonFaster ? _tapyeonBusNo : _directBusNo, isWinner: true, savedTime: timeSaved),
      const SizedBox(height: 16),
      _buildRouteCard(isDark: isDark, primary: Colors.grey, title: isTapyeonFaster ? "교원대 직행 버스" : "탑연삼거리 하차 + 도보", badge: "${timeSaved}분 더 걸림", time: "${isTapyeonFaster ? directTotal : tapyeonTotal}분 소요", detail: isTapyeonFaster ? "버스 $_directBusTime분 대기 필요" : "버스 $_tapyeonBusTime분 + 걷기 $_walkingTime분", busNumber: isTapyeonFaster ? _directBusNo : _tapyeonBusNo, isWinner: false, savedTime: 0),
      const SizedBox(height: 30), const Divider(), const SizedBox(height: 10),
      Text("ℹ️ 탑연삼거리 하차 시 교원대 정문까지 도보 약 15~20분이 소요됩니다. 짐이 많다면 직행 버스를 추천합니다.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
    ]));
  }

  Widget _buildRouteCard({required bool isDark, required Color primary, required String title, required String badge, required String time, required String detail, required String busNumber, required bool isWinner, required int savedTime}) {
    return Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(20), border: isWinner ? Border.all(color: primary, width: 2) : null, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: isWinner ? primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(18))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(isWinner ? Icons.check_circle : Icons.info, color: isWinner ? primary : Colors.grey, size: 20), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isWinner ? primary : (isDark ? Colors.grey : Colors.black87)))]), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isWinner ? primary : Colors.grey, borderRadius: BorderRadius.circular(12)), child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))])),
      Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(time, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 6), Text(detail, style: TextStyle(fontSize: 14, color: Colors.grey.shade500))]), Container(width: 60, height: 60, decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle), alignment: Alignment.center, child: Text(busNumber, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary)))])),
    ]));
  }

  Widget _buildDayToggle(String text, bool isSelected, VoidCallback onTap, bool isDark, Color primary) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isSelected ? Theme.of(context).cardColor : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : []), alignment: Alignment.center, child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? primary : Colors.grey))));
  }
}

// -----------------------------------------------------------------------------
// 공통 위젯들
// -----------------------------------------------------------------------------

class _MealDetailCard extends StatefulWidget {
  final ServeStatus status; final MealType type; final List<String> items; final bool isToday; final VoidCallback onShare;
  const _MealDetailCard({super.key, required this.status, required this.type, required this.items, required this.isToday, required this.onShare});
  @override
  State<_MealDetailCard> createState() => _MealDetailCardState();
}

class _MealDetailCardState extends State<_MealDetailCard> {
  int? _selectedIndex;
  @override
  void didUpdateWidget(covariant _MealDetailCard oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.items != widget.items) _selectedIndex = null; }

  String _getTimeLeft() {
    if (!widget.isToday) return "";
    final now = DateTime.now();
    final times = widget.type.timeRange.split("~")[1].trim().split(":");
    final end = DateTime(now.year, now.month, now.day, int.parse(times[0]), int.parse(times[1]));
    if (now.isAfter(end)) return "마감됨";
    final diff = end.difference(now);
    if (diff.inMinutes < 60) return "마감 ${diff.inMinutes}분 전";
    return "마감 ${diff.inHours}시간 전";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    Color statusColor; String statusText; IconData statusIcon;
    switch (widget.status) {
      case ServeStatus.open: statusColor = const Color(0xFF2E7D32); statusText = "식당 운영 중"; statusIcon = Icons.soup_kitchen; break;
      case ServeStatus.waiting: statusColor = const Color(0xFF1976D2); statusText = "식사 준비 중"; statusIcon = Icons.access_time; break;
      case ServeStatus.closed: statusColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600; statusText = "운영 종료"; statusIcon = Icons.block; break;
      case ServeStatus.notToday: statusColor = isDark ? Colors.grey.shade600 : Colors.grey.shade500; statusText = "식당 운영시간 아님"; statusIcon = Icons.calendar_today_rounded; break;
    }
    final bool unavailable = widget.items.isEmpty || widget.items.first.contains("없음") || widget.items.first.contains("미운영");
    final String timeLeft = _getTimeLeft();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: widget.isToday ? Border.all(color: primary.withOpacity(0.5), width: 2) : Border.all(color: Colors.transparent), boxShadow: [BoxShadow(color: widget.isToday ? primary.withOpacity(0.15) : Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), decoration: BoxDecoration(color: widget.isToday ? primary.withOpacity(0.03) : Colors.transparent, border: Border(bottom: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))), child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(statusIcon, size: 16, color: statusColor), const SizedBox(width: 6), Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13))])), if (widget.status == ServeStatus.open && timeLeft.isNotEmpty) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(timeLeft, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)))], const Spacer(), if (widget.isToday) Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)), child: const Text("TODAY", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))), Text(widget.type.timeRange, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13))])),
        Padding(padding: const EdgeInsets.all(24), child: unavailable ? const Center(child: Column(children: [Icon(Icons.no_meals, size: 40, color: Colors.grey), SizedBox(height: 10), Text("메뉴 정보가 없습니다.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))])) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(widget.items.length, (index) { final isSelected = _selectedIndex == index; final textColor = isDark ? Colors.white : Colors.black87; final bulletColor = isSelected ? primary : Colors.grey.shade400; return GestureDetector(onTap: () => setState(() => _selectedIndex = index), behavior: HitTestBehavior.opaque, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(margin: const EdgeInsets.only(top: 8), width: 6, height: 6, decoration: BoxDecoration(color: bulletColor, shape: BoxShape.circle, boxShadow: (isDark && isSelected) ? [BoxShadow(color: primary.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)] : [])), const SizedBox(width: 14), Expanded(child: Text(widget.items[index], style: TextStyle(fontSize: 17, fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal, color: textColor, height: 1.4)))]))); }))),
        if (!unavailable) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFFF8F9FA), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [FilledButton.icon(onPressed: widget.onShare, icon: const Icon(Icons.share, size: 16), label: const Text("공유하기"), style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))])),
      ]),
    );
  }
}

class _ColorPickerItem extends StatelessWidget {
  final Color color; final bool isSelected;
  const _ColorPickerItem({required this.color, required this.isSelected});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () { themeColor.value = color; PreferencesService.saveThemeColor(color); }, child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 48, height: 48, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.white, width: 3) : null, boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)] : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]), child: isSelected ? const Icon(Icons.check, color: Colors.white) : null));
  }
}

class _ThemeOption extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final VoidCallback onTap;
  const _ThemeOption({required this.label, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = selected ? (isDark ? Colors.white.withOpacity(0.15) : color.withOpacity(0.1)) : Colors.transparent;
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)), child: Column(children: [Icon(icon, color: selected ? color : Colors.grey), const SizedBox(height: 5), Text(label, style: TextStyle(color: selected ? color : Colors.grey, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 12))]))));
  }
}

class _AppSwitchOption extends StatelessWidget {
  final IconData icon; final String label; final bool isSelected; final VoidCallback onTap;
  const _AppSwitchOption({required this.icon, required this.label, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isSelected ? (isDark ? color.withOpacity(0.3) : color.withOpacity(0.1)) : Colors.transparent;
    Color contentColor; if (isSelected) contentColor = isDark ? Colors.white : color; else contentColor = isDark ? Colors.grey.shade400 : Colors.grey;
    final borderColor = isSelected ? (isDark ? Colors.white30 : color) : (isDark ? Colors.grey.shade800 : Colors.grey.withOpacity(0.3));
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: isSelected ? 2 : 1)), child: Row(children: [Icon(icon, color: contentColor, size: 28), const SizedBox(width: 16), Text(label, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal, color: contentColor)), const Spacer(), if (isSelected) Icon(Icons.check_circle, color: contentColor)])));
  }
}

class _Header extends StatelessWidget {
  final bool alarmOn; final VoidCallback onToggleAlarm; final DateTime date; final bool isToday; final VoidCallback? onPrev; final VoidCallback? onNext; final MealSource source; final ValueChanged<MealSource>? onSourceChanged;
  const _Header({required this.alarmOn, required this.onToggleAlarm, required this.date, required this.isToday, required this.onPrev, required this.onNext, required this.source, required this.onSourceChanged});

  void _showCafeteriaInfo(BuildContext context) {
    final isDorm = source == MealSource.a; final location = isDorm ? "관리동 1층" : "학생회관 1층"; final price = isDorm ? "의무입사생 무료" : "5,000원 (일반)"; final operation = isDorm ? "연중무휴" : "주말/공휴일 휴무"; final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(context: context, builder: (context) => Dialog(backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.storefront_rounded, size: 40, color: Theme.of(context).primaryColor)), const SizedBox(height: 16), const Text("식당 운영 정보", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), _buildInfoRow(Icons.place, "위치", location), const SizedBox(height: 12), _buildInfoRow(Icons.attach_money, "가격", price), const SizedBox(height: 12), _buildInfoRow(Icons.access_time, "운영", operation), const SizedBox(height: 24), GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text("닫기", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 16))))]))));
  }

  void _showAppSwitchDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => Dialog(backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("앱 바로가기", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), _AppSwitchOption(icon: Icons.restaurant_menu, label: "청람밥상 (식단)", isSelected: true, onTap: () => Navigator.pop(context)), const SizedBox(height: 12), _AppSwitchOption(icon: Icons.directions_bus, label: "청람버스 (버스)", isSelected: false, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const BusAppScreen())); })]))));
  }

  Widget _buildInfoRow(IconData icon, String label, String text) { return Row(children: [Icon(icon, size: 20, color: Colors.grey), const SizedBox(width: 12), Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)))]); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); final color = theme.colorScheme.primary; const wd = ["", "월", "화", "수", "목", "금", "토", "일"];
    return Container(decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)), boxShadow: [BoxShadow(blurRadius: 20, offset: const Offset(0, 8), color: color.withOpacity(0.4))]), padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 24), child: Column(children: [Row(children: [GestureDetector(onTap: () => _showAppSwitchDialog(context), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.menu, color: Colors.white, size: 20))), const SizedBox(width: 10), Expanded(child: Row(children: [const Text("KNUE 청람밥상", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(width: 4), Material(color: Colors.transparent, child: InkWell(onTap: () => _showCafeteriaInfo(context), borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(6.0), child: Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.7), size: 20))))])), IconButton(onPressed: onToggleAlarm, icon: Icon(alarmOn ? Icons.notifications_active : Icons.notifications_none, color: Colors.white.withOpacity(alarmOn ? 1.0 : 0.7)), style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)))]), const SizedBox(height: 20), Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Row(children: [_buildSegmentBtn("기숙사 식당", MealSource.a), _buildSegmentBtn("학생회관 식당", MealSource.b)])), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28)), Column(children: [if (isToday) Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Text("오늘의 식단", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))), Text("${wd[date.weekday]}요일", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text("${date.year}년 ${date.month.toString().padLeft(2, '0')}월 ${date.day.toString().padLeft(2, '0')}일", style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))]), IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28))])]));
  }
  Widget _buildSegmentBtn(String title, MealSource val) { final isSel = source == val; return Expanded(child: GestureDetector(onTap: onSourceChanged == null ? null : () => onSourceChanged!(val), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isSel ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: isSel ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : []), alignment: Alignment.center, child: Text(title, style: TextStyle(color: isSel ? Colors.black87 : Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 14))))); }
}

class _MealTabs extends StatelessWidget {
  final MealType selected; final ValueChanged<MealType> onSelect;
  const _MealTabs({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), child: Row(children: MealType.values.map((t) { final isSel = t == selected; final primary = Theme.of(context).colorScheme.primary; return Expanded(child: GestureDetector(onTap: () => onSelect(t), child: AnimatedContainer(duration: const Duration(milliseconds: 250), curve: Curves.easeOut, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSel ? primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(t.icon, size: 18, color: isSel ? primary : Colors.grey.shade400), const SizedBox(width: 6), Text(t.label, style: TextStyle(color: isSel ? primary : Colors.grey.shade400, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, fontSize: 15))])))); }).toList())));
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex; final ValueChanged<int> onTap;
  const _BottomNavBar({required this.currentIndex, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]), child: SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildNavItem(context, 0, Icons.restaurant, "오늘 식단"), _buildNavItem(context, 1, Icons.calendar_month_rounded, "월간 식단"), _buildNavItem(context, 2, Icons.settings_rounded, "환경설정")]))));
  }
  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSel = index == currentIndex; final primary = Theme.of(context).colorScheme.primary;
    return InkWell(onTap: () => onTap(index), borderRadius: BorderRadius.circular(20), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: isSel ? primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon, color: isSel ? primary : Colors.grey), if (isSel) ...[const SizedBox(width: 8), Text(label, style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 14))]])));
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFECACA))), child: Column(children: [const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]));
}

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth; final DateTime selectedDate; final ValueChanged<DateTime> onDateSelected; final Color primaryColor;
  const _CalendarGrid({required this.focusedMonth, required this.selectedDate, required this.onDateSelected, required this.primaryColor});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final firstDayWeekday = DateTime(focusedMonth.year, focusedMonth.month, 1).weekday;
    final offset = firstDayWeekday % 7;
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 10, crossAxisSpacing: 10), itemCount: daysInMonth + offset, itemBuilder: (context, index) {
      if (index < offset) return const SizedBox();
      final day = index - offset + 1;
      final date = DateTime(focusedMonth.year, focusedMonth.month, day);
      final isSelected = _isSameDate(date, selectedDate);
      final isToday = _isSameDate(date, DateTime.now());
      return GestureDetector(onTap: () => onDateSelected(date), child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: isSelected ? primaryColor : Colors.transparent, shape: BoxShape.circle, border: (isToday && !isSelected) ? Border.all(color: primaryColor, width: 2) : null), child: Text("$day", style: TextStyle(fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87)))));
    });
  }
}

class _CommonMealLayout extends StatelessWidget {
  final Widget header; final Widget content;
  const _CommonMealLayout({super.key, required this.header, required this.content});
  @override
  Widget build(BuildContext context) { return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: Column(children: [header, Expanded(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.only(bottom: 40), child: content))])); }
}

Future<dynamic> _fetchMealApi(DateTime date, MealSource source) async {
  late Uri uri;
  if (source == MealSource.a) uri = Uri.parse("$kBaseUrl/meals-a?y=${date.year}&m=${date.month}&d=${date.day}");
  else uri = Uri.parse("$kBaseUrl/meals-b?day=${_weekdayToDayParam(date)}");
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) throw Exception("서버 응답 오류 (${res.statusCode})");
  return jsonDecode(utf8.decode(res.bodyBytes));
}

String _weekdayToDayParam(DateTime d) {
  switch (d.weekday) { case 1: return "mon"; case 2: return "tue"; case 3: return "wed"; case 4: return "thu"; case 5: return "fri"; case 6: return "sat"; default: return "sun"; }
}

List<String> _asStringList(dynamic v) => (v is List) ? v.map((e) => e.toString()).toList() : [];
bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

ServeStatus _statusFor(MealType type, DateTime now, DateTime targetDate) {
  if (!_isSameDate(now, targetDate)) return ServeStatus.notToday;
  final range = type.timeRange.split("~").map((e) => e.trim()).toList();
  final start = DateTime(now.year, now.month, now.day, int.parse(range[0].split(":")[0]), int.parse(range[0].split(":")[1]));
  final end = DateTime(now.year, now.month, now.day, int.parse(range[1].split(":")[0]), int.parse(range[1].split(":")[1]));
  if (now.isBefore(start)) return ServeStatus.waiting;
  if (now.isAfter(end)) return ServeStatus.closed;
  return ServeStatus.open;
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(20)));
}

Future<void> _shareMenu(BuildContext context, DateTime date, MealSource src, MealType type, List<String>? items) async {
  final menuText = (items == null || items.isEmpty) ? '메뉴 없음' : items.join(', ');
  final shareText = "[KNUE ${src == MealSource.a ? '기숙사 식당' : '학생회관 식당'}]\n${date.month}월 ${date.day}일 ${type.label} 메뉴\n\n$menuText";
  await Share.share(shareText);
}

enum MealSource { a, b }
enum MealType { breakfast, lunch, dinner }
enum ServeStatus { open, waiting, closed, notToday }

extension MealTypeX on MealType {
  String get stdKey => toString().split('.').last;
  String get label { switch (this) { case MealType.breakfast: return "아침"; case MealType.lunch: return "점심"; case MealType.dinner: return "저녁"; } }
  IconData get icon { switch (this) { case MealType.breakfast: return Icons.wb_twilight_rounded; case MealType.lunch: return Icons.wb_sunny_rounded; case MealType.dinner: return Icons.nights_stay_rounded; } }
  String get timeRange { switch (this) { case MealType.breakfast: return "07:30 ~ 09:00"; case MealType.lunch: return "11:30 ~ 13:30"; case MealType.dinner: return "17:30 ~ 19:00"; } }
}
