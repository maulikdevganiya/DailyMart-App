import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/category_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/product_catalog_provider.dart';
import 'providers/promotions_provider.dart';
import 'providers/users_provider.dart';
import 'providers/address_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Authentication provider - handles login, logout, user data
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Cart provider - manages items user wants to buy
        ChangeNotifierProvider(create: (_) => CartProvider()),
        // Categories provider - shows product types (Fruits, Dairy, etc)
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        // Products provider - all products available in the store
        ChangeNotifierProvider(create: (_) => ProductCatalogProvider()),
        // Promotions provider - handles sales, discounts, and banners
        ChangeNotifierProvider(create: (_) => PromotionsProvider()),
        // Orders provider - manages past and current orders
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        // Users provider - admin can manage and block users
        ChangeNotifierProvider(create: (_) => UsersProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DailyMart',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1FA64A),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF7F8FA),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
