import 'package:flutter/material.dart';
import 'package:wash_and_dry/screens/customer/customer_home_screen.dart';
import 'package:wash_and_dry/screens/customer/orders/customer_orderslist_screen.dart';
import 'package:wash_and_dry/screens/customer/customer_profile_screen.dart';
import 'package:wash_and_dry/screens/customer/wallet/customer_wallet_screen.dart';


class MainShellCustomer extends StatefulWidget {
  final int initialIndex;

  const MainShellCustomer({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainShellCustomer> createState() => _MainShellState();
}

class _MainShellState extends State<MainShellCustomer> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }
  final _pages = const [
    HomeScreen(),
    OrdersListScreen(),
    WalletCustomerScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = const Color(0xFF7A7A7A);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    Widget item({
      required int index,
      required String iconNormal,
      required String iconActive,
      required String label,
    }) {
      final isActive = currentIndex == index;

      return Expanded(
        child: InkWell(
          onTap: () => onChanged(index),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  scale: isActive ? 1.12 : 1.0,
                  child: Image.asset(
                    isActive ? iconActive : iconNormal,
                    width: 32,
                    height: 32,

                    color: isActive ? null : inactive,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isActive ? const Color(0xFF0593FF) : inactive,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 88 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, -2),
            color: Colors.black.withOpacity(0.10),
          ),
        ],
      ),
      child: Row(
        children: [
          item(
            index: 0,
            iconNormal: 'assets/icons/home.png',
            iconActive: 'assets/icons/homed.png',
            label: 'หน้าหลัก',
          ),
          item(
            index: 1,
            iconNormal: 'assets/icons/history.png',
            iconActive: 'assets/icons/histored.png',
            label: 'รายการ',
          ),
          item(
            index: 2,
            iconNormal: 'assets/icons/wallet.png',
            iconActive: 'assets/icons/walleted.png',
            label: 'วอลเล็ต',
          ),
          item(
            index: 3,
            iconNormal: 'assets/icons/profile.png',
            iconActive: 'assets/icons/profiled.png',
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
