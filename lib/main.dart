import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const VoicingApp());
}

class VoicingApp extends StatelessWidget {
  const VoicingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voicing - ระบบจัดการและแจ้งเตือนกำหนดการ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3D5E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F6FC),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F3D5E).withOpacity(0.15),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Transform.translate(
                    offset: const Offset(0, 17),
                    child: Transform.scale(
                      scale: 1.74,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const CircleAvatar(
                            backgroundColor: Color(0xFF0F3D5E),
                            child: Icon(Icons.notifications_active,
                                size: 80, color: Colors.amber),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Voicing',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3D5E),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ระบบแจ้งเตือนกำหนดการด้วยเสียงพูดอัจฉริยะ',
                style: TextStyle(fontSize: 14, color: Colors.blueGrey),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _timer;

  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> historyLogs = [];
  String _selectedFilter = 'ทั้งหมด';
  String _searchQuery = '';
  bool _isSoundEnabled = true;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initTts();
    _loadData();
    _startDeadlineChecker();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('saved_assignments_v3');
    final String? savedHistory = prefs.getString('saved_history_logs_v1');

    setState(() {
      _isSoundEnabled = prefs.getBool('sound_enabled') ?? true;
      if (savedData != null) {
        final List<dynamic> decodedList = jsonDecode(savedData);
        assignments = decodedList.map((item) {
          return {
            'id':
                item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'title': item['title'],
            'description': item['description'] ?? '',
            'priority': item['priority'] ?? 'ปกติ',
            'dueDateTime': DateTime.parse(item['dueDateTime']),
            'status': item['status'],
            'alarmStopped': item['alarmStopped'] ?? false,
            'lastNotifiedAt': item['lastNotifiedAt'],
          };
        }).toList();
      }
      if (savedHistory != null) {
        final List<dynamic> decodedHistory = jsonDecode(savedHistory);
        historyLogs = decodedHistory
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encodableList = assignments.map((item) {
      return {
        'id': item['id'],
        'title': item['title'],
        'description': item['description'],
        'priority': item['priority'],
        'dueDateTime': (item['dueDateTime'] as DateTime).toIso8601String(),
        'status': item['status'],
        'alarmStopped': item['alarmStopped'] ?? false,
        'lastNotifiedAt': item['lastNotifiedAt'],
      };
    }).toList();
    await prefs.setString('saved_assignments_v3', jsonEncode(encodableList));
    await prefs.setString('saved_history_logs_v1', jsonEncode(historyLogs));
  }

  void _addHistoryLog(String actionType, String title, String detail) {
    historyLogs.insert(0, {
      'actionType': actionType,
      'title': title,
      'detail': detail,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('th-TH');
    await _flutterTts.setSpeechRate(0.55);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.05);
  }

  Future<void> _speakMessage(String text) async {
    await _flutterTts.stop();
    if (!_isSoundEnabled) return;
    await Future.delayed(const Duration(milliseconds: 300));
    await _flutterTts.speak(text);
  }

  String _buildThaiSpokenDateTime(DateTime dt) {
    const List<String> thaiDays = [
      '',
      'หนึ่ง',
      'สอง',
      'สาม',
      'สี่',
      'ห้า',
      'หก',
      'เจ็ด',
      'แปด',
      'เก้า',
      'สิบ',
      'สิบเอ็ด',
      'สิบสอง',
      'สิบสาม',
      'สิบสี่',
      'สิบห้า',
      'สิบหก',
      'สิบเจ็ด',
      'สิบแปด',
      'สิบเก้า',
      'ยี่สิบ',
      'ยี่สิบเอ็ด',
      'ยี่สิบสอง',
      'ยี่สิบสาม',
      'ยี่สิบสี่',
      'ยี่สิบห้า',
      'ยี่สิบหก',
      'ยี่สิบเจ็ด',
      'ยี่สิบแปด',
      'ยี่สิบเก้า',
      'สามสิบ',
      'สามสิบเอ็ด'
    ];
    const List<String> thaiMonths = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    final dayText = thaiDays[dt.day];
    final month = thaiMonths[dt.month];
    final hour = dt.hour;
    final minute = dt.minute;
    final minuteText = minute == 0 ? 'ตรง' : '$minute นาที';
    return 'วันที่ $dayText $month, เวลา $hour นาฬิกา $minuteText';
  }

  String _buildThaiDisplayDateTime(DateTime dt) {
    const List<String> thaiMonths = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    final month = thaiMonths[dt.month];
    final minuteText = dt.minute == 0 ? 'ตรง' : '${dt.minute} นาที';
    return 'วันที่ ${dt.day} $month, เวลา ${dt.hour} นาฬิกา $minuteText';
  }

  void _startDeadlineChecker() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      bool needsSave = false;

      for (int i = 0; i < assignments.length; i++) {
        final item = assignments[i];
        final DateTime due = item['dueDateTime'];
        final bool isDone = item['status'] == 'ส่งแล้ว';
        final bool isStopped = item['alarmStopped'] == true;

        if (!isDone &&
            !isStopped &&
            (now.isAfter(due) || now.isAtSameMomentAs(due))) {
          final String? lastNotifiedStr = item['lastNotifiedAt'];

          if (lastNotifiedStr == null) {
            assignments[i]['lastNotifiedAt'] = now.toIso8601String();
            needsSave = true;
            _triggerAlarm(i, isRepeat: false);
          } else {
            final DateTime lastNotified = DateTime.parse(lastNotifiedStr);
            if (now.difference(lastNotified).inMinutes >= 5) {
              assignments[i]['lastNotifiedAt'] = now.toIso8601String();
              needsSave = true;
              _triggerAlarm(i, isRepeat: true);
            }
          }
        }
      }

      if (needsSave && mounted) {
        setState(() {});
        _saveData();
      } else if (now.second == 0 && mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _triggerAlarm(int index, {required bool isRepeat}) async {
    final title = assignments[index]['title'];
    final DateTime due = assignments[index]['dueDateTime'];
    final spokenDateTime = _buildThaiSpokenDateTime(due);
    final displayDateTime = _buildThaiDisplayDateTime(due);
    final spokenMessage = 'แจ้งเตือนกำหนดการ $title $spokenDateTime';
    final displayMessage = 'แจ้งเตือนกำหนดการ $title $displayDateTime';

    _addHistoryLog(
      'alarm',
      title,
      isRepeat
          ? 'แจ้งเตือนซ้ำรอบ 5 นาที ($displayDateTime)'
          : 'แจ้งเตือนเมื่อถึงกำหนด ($displayDateTime)',
    );
    await _saveData();
    await _speakMessage(spokenMessage);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'deadline_alarm_channel',
      'แจ้งเตือนถึงกำหนดส่งงาน',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      index + 100,
      isRepeat ? 'แจ้งเตือนซ้ำ (ทุก 5 นาที) ⏰' : 'ถึงกำหนดการแล้ว! ⏰',
      displayMessage,
      platformDetails,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.amberAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayMessage,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'หยุดเตือน',
            textColor: Colors.amberAccent,
            onPressed: () => _stopAlarm(assignments[index]['id']),
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }

  Future<void> _stopAlarm(String id) async {
    final index = assignments.indexWhere((element) => element['id'] == id);
    if (index == -1) return;

    final title = assignments[index]['title'];
    await _flutterTts.stop();
    setState(() {
      assignments[index]['alarmStopped'] = true;
      _addHistoryLog('stop', title, 'กดหยุดการแจ้งเตือนซ้ำทุก 5 นาที');
    });
    await _saveData();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('ปิดเสียงแจ้งเตือนซ้ำสำหรับ "$title" แล้ว'),
          backgroundColor: Colors.blueGrey.shade700,
        ),
      );
    }
  }

  Future<void> _submitAssignment(String id) async {
    final index = assignments.indexWhere((element) => element['id'] == id);
    if (index == -1) return;

    final title = assignments[index]['title'];
    await _flutterTts.stop();
    setState(() {
      assignments[index]['status'] = 'ส่งแล้ว';
      assignments[index]['alarmStopped'] = true;
      _addHistoryLog('submit', title, 'กดส่งเรียบร้อยแล้ว');
    });
    await _saveData();
    await _speakMessage('ส่ง $title เรียบร้อยแล้ว');

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('บันทึก "$title" เรียบร้อยแล้ว!')),
            ],
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _deleteAssignment(String id) async {
    final index = assignments.indexWhere((element) => element['id'] == id);
    if (index == -1) return;

    final title = assignments[index]['title'];
    setState(() {
      _addHistoryLog('delete', title, 'ลบรายการออกจากหน้าหลัก');
      assignments.removeAt(index);
    });
    await _saveData();
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year + 543;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year • $hour:$minute น.';
  }

  String _getCountdownText(DateTime due, bool isDone, bool isAlarming) {
    if (isDone) return 'ดำเนินการเสร็จสิ้น';
    if (isAlarming) return 'กำลังแจ้งเตือนทุก 5 นาที...';
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) return 'ถึงกำหนดแล้ว (หยุดเตือนชั่วคราว)';
    if (diff.inDays > 0)
      return 'เหลือเวลาอีก ${diff.inDays} วัน ${diff.inHours % 24} ชม.';
    if (diff.inHours > 0)
      return 'เหลือเวลาอีก ${diff.inHours} ชม. ${diff.inMinutes % 60} นาที';
    if (diff.inMinutes > 0) return 'เหลือเวลาอีก ${diff.inMinutes} นาที';
    return 'ถึงกำหนดในไม่กี่วินาที!';
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'ด่วนมาก':
        return Colors.red.shade600;
      case 'ทั่วไป':
        return Colors.teal.shade600;
      default:
        return const Color(0xFF0F3D5E);
    }
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history_rounded,
                            color: Color(0xFF0F3D5E), size: 26),
                        SizedBox(width: 10),
                        Text('ประวัติการตั้งกำหนดการ',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (historyLogs.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep,
                            color: Colors.redAccent, size: 18),
                        label: const Text('ล้างประวัติ',
                            style: TextStyle(color: Colors.redAccent)),
                        onPressed: () async {
                          setState(() => historyLogs.clear());
                          setModalState(() {});
                          await _saveData();
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: historyLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off,
                                size: 65, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('ยังไม่มีประวัติการทำรายการ',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold)),
                            const Text(
                                'เมื่อคุณเพิ่ม แก้ไข หรือกดส่ง ระบบจะบันทึกไว้ที่นี่',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: historyLogs.length,
                        itemBuilder: (context, index) {
                          final log = historyLogs[index];
                          final actionType = log['actionType'];
                          final time = DateTime.parse(log['timestamp']);

                          IconData icon;
                          Color color;
                          String badgeText;

                          switch (actionType) {
                            case 'create':
                              icon = Icons.add_circle;
                              color = Colors.blue.shade700;
                              badgeText = 'ตั้งกำหนดการ';
                              break;
                            case 'edit':
                              icon = Icons.edit_note;
                              color = Colors.orange.shade700;
                              badgeText = 'แก้ไขข้อมูล';
                              break;
                            case 'submit':
                              icon = Icons.check_circle;
                              color = Colors.green.shade700;
                              badgeText = 'ส่งแล้ว';
                              break;
                            case 'alarm':
                              icon = Icons.volume_up;
                              color = Colors.purple.shade700;
                              badgeText = 'แจ้งเตือนเสียงพูด';
                              break;
                            case 'stop':
                              icon = Icons.notifications_off;
                              color = Colors.blueGrey.shade700;
                              badgeText = 'หยุดการเตือน';
                              break;
                            default:
                              icon = Icons.delete;
                              color = Colors.red.shade700;
                              badgeText = 'ลบรายการ';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: color.withOpacity(0.12),
                                  child: Icon(icon, color: color, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: color.withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6)),
                                            child: Text(badgeText,
                                                style: TextStyle(
                                                    color: color,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                          Text(_formatDateTime(time),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(log['title'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(log['detail'],
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignmentDialog({Map<String, dynamic>? existingItem}) {
    final isEditing = existingItem != null;
    _titleController.text = isEditing ? existingItem['title'] : '';
    _descController.text = isEditing ? existingItem['description'] : '';
    String selectedPriority = isEditing ? existingItem['priority'] : 'ปกติ';
    DateTime selectedDate =
        isEditing ? existingItem['dueDateTime'] : DateTime.now();
    TimeOfDay selectedTime = isEditing
        ? TimeOfDay.fromDateTime(existingItem['dueDateTime'])
        : TimeOfDay.fromDateTime(
            DateTime.now().add(const Duration(minutes: 1)));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_calendar : Icons.add_alarm,
                  color: const Color(0xFF0F3D5E)),
              const SizedBox(width: 10),
              Text(isEditing ? 'แก้ไขกำหนดการ' : 'สร้างกำหนดการใหม่',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อกำหนดการ *',
                    prefixIcon: const Icon(Icons.assignment),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'รายละเอียดเพิ่มเติม (ถ้ามี)',
                    prefixIcon: const Icon(Icons.notes),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('ระดับความสำคัญ:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['ทั่วไป', 'ปกติ', 'ด่วนมาก'].map((level) {
                    final isSelected = selectedPriority == level;
                    return ChoiceChip(
                      label: Text(level),
                      selected: isSelected,
                      selectedColor: _getPriorityColor(level).withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? _getPriorityColor(level)
                            : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setDialogState(() => selectedPriority = level);
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child:
                          Icon(Icons.calendar_month, color: Color(0xFF0F3D5E))),
                  title: const Text('วันที่แจ้งเตือน',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year + 543}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime(2035),
                      );
                      if (pickedDate != null)
                        setDialogState(() => selectedDate = pickedDate);
                    },
                    child: const Text('เปลี่ยนวัน'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(Icons.access_time_filled,
                          color: Color(0xFF0F3D5E))),
                  title: const Text('เวลาแจ้งเตือน',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')} น.',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                          context: context, initialTime: selectedTime);
                      if (pickedTime != null)
                        setDialogState(() => selectedTime = pickedTime);
                    },
                    child: const Text('เปลี่ยนเวลา'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3D5E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save, color: Colors.white, size: 18),
              label: Text(isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มกำหนดการ',
                  style: const TextStyle(color: Colors.white)),
              onPressed: () async {
                if (_titleController.text.isNotEmpty) {
                  final combinedDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  final titleText = _titleController.text;

                  setState(() {
                    if (isEditing) {
                      final idx = assignments
                          .indexWhere((e) => e['id'] == existingItem['id']);
                      if (idx != -1) {
                        assignments[idx] = {
                          ...assignments[idx],
                          'title': titleText,
                          'description': _descController.text,
                          'priority': selectedPriority,
                          'dueDateTime': combinedDateTime,
                          'alarmStopped': false,
                          'lastNotifiedAt':
                              combinedDateTime.isAfter(DateTime.now())
                                  ? null
                                  : assignments[idx]['lastNotifiedAt'],
                        };
                        _addHistoryLog('edit', titleText,
                            'อัปเดตกำหนดการเป็น ${_formatDateTime(combinedDateTime)}');
                      }
                    } else {
                      assignments.add({
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                        'title': titleText,
                        'description': _descController.text,
                        'priority': selectedPriority,
                        'dueDateTime': combinedDateTime,
                        'status': 'รอดำเนินการ',
                        'alarmStopped': false,
                        'lastNotifiedAt': null,
                      });
                      _addHistoryLog('create', titleText,
                          'ตั้งกำหนดการวันที่ ${_formatDateTime(combinedDateTime)}');
                    }
                  });
                  await _saveData();
                  _titleController.clear();
                  _descController.clear();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = assignments.length;
    final pendingCount =
        assignments.where((e) => e['status'] != 'ส่งแล้ว').length;
    final doneCount = assignments.where((e) => e['status'] == 'ส่งแล้ว').length;

    final filteredList = assignments.where((item) {
      final matchesSearch = item['title']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item['description']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      if (_selectedFilter == 'รอดำเนินการ') return item['status'] != 'ส่งแล้ว';
      if (_selectedFilter == 'ส่งแล้ว') return item['status'] == 'ส่งแล้ว';
      return true;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 45, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2A43), Color(0xFF156585)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipOval(
                          child: Transform.translate(
                            offset: const Offset(0, 3.4),
                            child: Transform.scale(
                              scale: 1.74,
                              child: Image.asset(
                                'assets/logo.png',
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const CircleAvatar(
                                  backgroundColor: Colors.amber,
                                  child: Icon(Icons.notifications,
                                      color: Color(0xFF0A2A43)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Voicing',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            Text('แจ้งเตือนกำหนดการ',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            icon: const Icon(Icons.history_rounded,
                                color: Colors.white),
                            tooltip: 'ประวัติการตั้งกำหนดการ',
                            onPressed: _showHistoryModal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _isSoundEnabled
                                ? Colors.white24
                                : Colors.redAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isSoundEnabled
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              color: Colors.white,
                            ),
                            tooltip: _isSoundEnabled
                                ? 'เปิดเสียงอยู่ (กดเพื่อปิดเสียง)'
                                : 'ปิดเสียงอยู่ (กดเพื่อเปิดเสียง)',
                            onPressed: () async {
                              setState(() {
                                _isSoundEnabled = !_isSoundEnabled;
                              });
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                  'sound_enabled', _isSoundEnabled);
                              if (!_isSoundEnabled) {
                                await _flutterTts.stop();
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    content: Text(_isSoundEnabled
                                        ? '🔊 เปิดเสียงแจ้งเตือนแล้ว'
                                        : '🔇 ปิดเสียงแจ้งเตือนแล้ว'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _buildStatCard('ทั้งหมด', totalCount,
                        Icons.folder_copy_rounded, Colors.white),
                    const SizedBox(width: 10),
                    _buildStatCard('ค้างส่ง', pendingCount,
                        Icons.pending_actions_rounded, Colors.amberAccent),
                    const SizedBox(width: 10),
                    _buildStatCard('ส่งแล้ว', doneCount, Icons.task_alt_rounded,
                        Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อกำหนดการ หรือรายละเอียด...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['ทั้งหมด', 'รอดำเนินการ', 'ส่งแล้ว'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        selectedColor: const Color(0xFF156585),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none),
                        onSelected: (val) =>
                            setState(() => _selectedFilter = filter),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined,
                            size: 70, color: Colors.teal.shade200),
                        const SizedBox(height: 12),
                        Text(
                          assignments.isEmpty
                              ? 'ยังไม่มีรายการกำหนดการ'
                              : 'ไม่พบรายการที่ค้นหา',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                            'กดปุ่ม "+ เพิ่มกำหนดการ" ด้านล่างเพื่อสร้างรายการใหม่',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 85),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final isDone = item['status'] == 'ส่งแล้ว';
                      final isStopped = item['alarmStopped'] == true;
                      final DateTime due = item['dueDateTime'];
                      final isDuePassed = DateTime.now().isAfter(due) ||
                          DateTime.now().isAtSameMomentAs(due);
                      final isAlarming = !isDone && !isStopped && isDuePassed;
                      final priorityColor = _getPriorityColor(item['priority']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isAlarming
                              ? Border.all(color: Colors.redAccent, width: 1.5)
                              : null,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                  left: BorderSide(
                                      color: isDone
                                          ? Colors.green
                                          : (isAlarming
                                              ? Colors.red
                                              : priorityColor),
                                      width: 6)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (isDone
                                                  ? Colors.green
                                                  : (isAlarming
                                                      ? Colors.red
                                                      : priorityColor))
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isDone
                                              ? 'ส่งแล้ว'
                                              : (isAlarming
                                                  ? 'กำลังเตือนซ้ำ'
                                                  : item['priority']),
                                          style: TextStyle(
                                            color: isDone
                                                ? Colors.green
                                                : (isAlarming
                                                    ? Colors.red
                                                    : priorityColor),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getCountdownText(
                                              due, isDone, isAlarming),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDone
                                                ? Colors.green
                                                : (isAlarming
                                                    ? Colors.red
                                                    : Colors.orange.shade800),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 20, color: Colors.blueGrey),
                                        tooltip: 'แก้ไข',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _showAssignmentDialog(
                                            existingItem: item),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20, color: Colors.redAccent),
                                        tooltip: 'ลบ',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _deleteAssignment(item['id']),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['title'],
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color:
                                          isDone ? Colors.grey : Colors.black87,
                                    ),
                                  ),
                                  if (item['description']
                                      .toString()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(item['description'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54)),
                                  ],
                                  const Divider(height: 18),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.event_available,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(_formatDateTime(due),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          if (isAlarming) ...[
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    Colors.red.shade700,
                                                side: BorderSide(
                                                    color: Colors.red.shade300),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              icon: const Icon(
                                                  Icons
                                                      .notifications_off_outlined,
                                                  size: 16),
                                              label: const Text('หยุดเตือน',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              onPressed: () =>
                                                  _stopAlarm(item['id']),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          isDone
                                              ? const Row(
                                                  children: [
                                                    Icon(Icons.verified,
                                                        color: Colors.green,
                                                        size: 18),
                                                    SizedBox(width: 4),
                                                    Text('ส่งเรียบร้อย',
                                                        style: TextStyle(
                                                            color: Colors.green,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13)),
                                                  ],
                                                )
                                              : ElevatedButton.icon(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF0F3D5E),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 14,
                                                        vertical: 8),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10)),
                                                  ),
                                                  icon: const Icon(
                                                      Icons.send_rounded,
                                                      size: 16,
                                                      color: Colors.white),
                                                  label: const Text('กดส่ง',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13)),
                                                  onPressed: () =>
                                                      _submitAssignment(
                                                          item['id']),
                                                ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignmentDialog(),
        backgroundColor: const Color(0xFF0F3D5E),
        elevation: 4,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text('เพิ่มกำหนดการ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
