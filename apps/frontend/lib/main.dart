import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hiway_app/core/config/app_config.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import 'package:hiway_app/pages/auth/auth_wrapper.dart';
import 'package:hiway_app/pages/auth/email_verification_page.dart';
import 'package:hiway_app/pages/auth/login_page.dart';
import 'package:hiway_app/pages/auth/signup_page.dart';
import 'package:hiway_app/pages/auth/profile_setup_page.dart';
import 'package:hiway_app/pages/employer/dashboard.dart';
import 'package:hiway_app/pages/home/home_page.dart';
import 'package:hiway_app/pages/job_seeker/dashboard.dart';
import 'package:hiway_app/pages/splash/splash_screen.dart' as splash;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _configureSystemUI();

  await dotenv.load(fileName: ".env");
  await SupabaseConfig.initialize();

  runApp(const MyApp());
}

Future<void> _configureSystemUI() async {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF352DC3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      home: const splash.SplashScreen(),
      routes: {
        AppConstants.loginRoute: (context) => const LoginPage(),
        AppConstants.registerRoute: (context) => const SignupPage(),
        AppConstants.homeRoute: (context) => const HomePage(),
        AppConstants.jobSeekerDashboardRoute: (context) =>
            const JobSeekerDashboard(),
        AppConstants.employerDashboardRoute: (context) =>
            const EmployerDashboard(),
        '/auth': (context) => const AuthWrapper(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppConstants.profileSetupRoute) {
          final args = settings.arguments as Map<String, dynamic>?;
          final email = args?['email'] as String? ?? '';
          return MaterialPageRoute(
            builder: (context) => ProfileSetupPage(email: email),
          );
        }
        if (settings.name == AppConstants.emailVerificationRoute) {
          final args = settings.arguments as Map<String, dynamic>?;
          final email = args?['email'] as String? ?? '';
          return MaterialPageRoute(
            builder: (context) => EmailVerificationPage(email: email),
          );
        }
        return null;
      },
    );
  }
}
