import 'services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hisse_page.dart';
import 'login_page.dart';

// StatelessWidget yerine StatefulWidget kullanıyoruz
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();
    @override
  void initState() {
    super.initState();
    // Bildirim izinlerini iste ve token'ı al
    FcmService.init(); 
    
    _waitAndNavigate();
  }
    // Sayfa açılır açılmaz zamanlayıcıyı başlatıyoruz
    _waitAndNavigate();
  }

  // 3 saniye bekleyip hisse uygulamasına götüren fonksiyon
  Future<void> _waitAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MyHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Giriş yapmış kullanıcının mailini alalım
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Ana Sayfa',
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Hoşgeldiniz!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Giriş yapan kullanıcı:\n${user?.email}'),
            const SizedBox(height: 30),
            // Beklediğimizi göstermek için dönen bir çember ekledim
            const CircularProgressIndicator(), 
            const SizedBox(height: 10),
            const Text('Uygulamaya yönlendiriliyorsunuz...'),
          ],
        ),
      ),
    );
  }
}