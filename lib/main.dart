import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      
    },
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IotProvider()),
      ],
      child: const PuffGuardApp(),
    ),
  );
}

class PuffGuardApp extends StatelessWidget {
  const PuffGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PuffGuard IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      home: const DashboardScreen(),
    );
  }
}

class IotProvider extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool get isConnected => _isConnected;
  double _humidity = 0.0;
  int _smoke = 0;
  String _fanStatus = "off";
  double get humidity => _humidity;
  int get smoke => _smoke;
  String get fanStatus => _fanStatus;
  bool _hasNotifiedForCurrentEvent = false;
  static const int dangerThreshold = 1000;
  final String _wsUrl = 'ws:
  IotProvider() {
    _connectWebSocket();
  }
  void _connectWebSocket() async {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      await _channel!.ready;
      _isConnected = true;
      _isConnecting = false;
      notifyListeners();
      _channel!.stream.listen(
        (message) => _handleIncomingData(message),
        onDone: () {
          debugPrint("WebSocket closed");
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint("WebSocket error: $error");
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint("WebSocket connection failed: $e");
      _isConnecting = false;
      _handleDisconnect();
    }
  }
  void _handleIncomingData(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data.containsKey('humidity')) _humidity = (data['humidity'] as num).toDouble();
      if (data.containsKey('smoke')) {
        _smoke = (data['smoke'] as num).toInt();
        _checkSmokeLevelAndNotify();
      }
      if (data.containsKey('fan_status')) _fanStatus = data['fan_status'].toString();
      notifyListeners();
    } catch (e) {
      debugPrint("Error parsing data: $e");
    }
  }
  void _checkSmokeLevelAndNotify() {
    if (_smoke > dangerThreshold) {
      if (!_hasNotifiedForCurrentEvent) {
        _hasNotifiedForCurrentEvent = true;
        _showLocalNotification();
      }
    } else {
      _hasNotifiedForCurrentEvent = false;
    }
  }
  Future<void> _showLocalNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'puffguard_alerts_channel',
      'PuffGuard Alerts',
      channelDescription: 'High priority alerts for smoke detection',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: Color(0xFFEF5350),
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'PuffGuard Alert!',
      body: 'Smoke detected! Exhaust fan activated.',
      notificationDetails: platformChannelSpecifics,
    );
  }
  void _handleDisconnect() {
    if (_isConnected) {
      _isConnected = false;
      notifyListeners();
    }
    _isConnecting = false;
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) _connectWebSocket();
    });
  }
  void toggleFan() {
    if (_isConnected && _channel != null) {
      final command = jsonEncode({"command": "toggle_fan"});
      _channel!.sink.add(command);
    }
  }
  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ConnectionStatusHeader(),
              const SizedBox(height: 24),
              const PulsingWarningBanner(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: SmokeCard()),
                          SizedBox(width: 24),
                          Expanded(child: HumidityCard()),
                        ],
                      );
                    } else {
                      return ListView(
                        children: const [
                          SmokeCard(),
                          SizedBox(height: 24),
                          HumidityCard(),
                        ],
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              const FanControlButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionStatusHeader extends StatelessWidget {
  const ConnectionStatusHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final isConnected = context.select((IotProvider p) => p.isConnected);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.greenAccent[400] : Colors.redAccent,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isConnected ? "Connected to ESP32" : "Connecting...",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}

class PulsingWarningBanner extends StatefulWidget {
  const PulsingWarningBanner({super.key});
  @override
  State<PulsingWarningBanner> createState() => _PulsingWarningBannerState();
}

class _PulsingWarningBannerState extends State<PulsingWarningBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final smokeLevel = context.select((IotProvider p) => p.smoke);
    if (smokeLevel <= IotProvider.dangerThreshold) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF5350).withOpacity(0.6),
                    blurRadius: 20 * _animation.value,
                    spreadRadius: 4 * _animation.value,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning_rounded, color: Colors.white, size: 32),
                  SizedBox(width: 16),
                  Text("⚠️ SMOKE DETECTED", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SmokeCard extends StatelessWidget {
  const SmokeCard({super.key});
  @override
  Widget build(BuildContext context) {
    final smokeLevel = context.select((IotProvider p) => p.smoke);
    Color cardColor;
    String statusText;
    Color textColor = Colors.white;
    if (smokeLevel <= 500) {
      cardColor = const Color(0xFF66BB6A);
      statusText = "Good";
    } else if (smokeLevel <= IotProvider.dangerThreshold) {
      cardColor = const Color(0xFFFFA726);
      statusText = "Warning";
    } else {
      cardColor = const Color(0xFFEF5350);
      statusText = "Danger";
    }
    final isDanger = smokeLevel > IotProvider.dangerThreshold;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: cardColor.withOpacity(isDanger ? 0.7 : 0.4), blurRadius: isDanger ? 30 : 20, offset: const Offset(0, 8), spreadRadius: isDanger ? 4 : 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Air Quality", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.9))),
              Icon(isDanger ? Icons.warning_amber_rounded : Icons.air, color: textColor, size: 28),
            ],
          ),
          const SizedBox(height: 24),
          Text(smokeLevel.toString(), style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: textColor, height: 1.0)),
          const SizedBox(height: 8),
          Text("Smoke Level • $statusText", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.9))),
        ],
      ),
    );
  }
}

class HumidityCard extends StatelessWidget {
  const HumidityCard({super.key});
  @override
  Widget build(BuildContext context) {
    final humidity = context.select((IotProvider p) => p.humidity);
    const cardColor = Color(0xFF42A5F5);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Humidity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
              Icon(Icons.water_drop_rounded, color: cardColor, size: 28),
            ],
          ),
          const SizedBox(height: 24),
          Text("${humidity.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: cardColor, height: 1.0)),
          const SizedBox(height: 8),
          const Text("Relative Humidity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
        ],
      ),
    );
  }
}

class FanControlButton extends StatelessWidget {
  const FanControlButton({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IotProvider>();
    final isFanOn = provider.fanStatus.toLowerCase() == "on";
    final isConnected = provider.isConnected;
    final buttonColor = !isConnected ? Colors.grey[300] : (isFanOn ? const Color(0xFFEF5350) : const Color(0xFF7E57C2));
    final textColor = !isConnected ? Colors.grey[600] : Colors.white;
    return GestureDetector(
      onTap: isConnected ? () => provider.toggleFan() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: isConnected ? [BoxShadow(color: buttonColor!.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))] : [],
        ),
        child: Center(
          child: Text(isFanOn ? "TURN FAN OFF" : "TURN FAN ON", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 1.5)),
        ),
      ),
    );
  }
}
