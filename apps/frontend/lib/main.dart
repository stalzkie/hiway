import 'package:flutter/material.dart';
<<<<<<< HEAD
=======
import 'package:flutter/services.dart';
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hiway_app/core/config/app_config.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import 'package:hiway_app/pages/auth/auth_wrapper.dart';
<<<<<<< HEAD
import 'package:hiway_app/pages/auth/login_page.dart';
import 'package:hiway_app/pages/auth/signup_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
=======

import 'package:hiway_app/pages/auth/login_page.dart';
import 'package:hiway_app/pages/auth/signup_page.dart';
import 'package:hiway_app/pages/employer/dashboard.dart';
import 'package:hiway_app/pages/home/home_page.dart';
import 'package:hiway_app/pages/job_seeker/dashboard.dart';
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

<<<<<<< HEAD
=======
  await _configureSystemUI();

>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
  await dotenv.load(fileName: ".env");
  await SupabaseConfig.initialize();

  runApp(const MyApp());
}

<<<<<<< HEAD
=======
Future<void> _configureSystemUI() async {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        AppConstants.loginRoute: (context) => const LoginPage(),
        AppConstants.registerRoute: (context) => const SignupPage(),
        AppConstants.homeRoute: (context) => const HomePage(),
        AppConstants.jobSeekerDashboardRoute: (context) =>
            const JobSeekerDashboard(),
        AppConstants.employerDashboardRoute: (context) =>
            const EmployerDashboard(),
      },
    );
  }
}
<<<<<<< HEAD

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final session = snapshot.data?.session;

        if (session == null) {
          return FutureBuilder<String?>(
            future: _authService.getUserRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              final role = roleSnapshot.data;

              if (role == AppConstants.jobSeekerRole) {
                return const JobSeekerDashboard();
              } else if (role == AppConstants.employerRole) {
                return const EmployerDashboard();
              } else {
                return const HomePage();
              }
            },
          );
        }

        return const LoginPage();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
=======
>>>>>>> c5845bf80c9c99d8aa5f407f219f5f5dea90cebe
