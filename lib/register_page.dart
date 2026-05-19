import 'package:flutter/material.dart';
import 'widgets/common_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号和密码')));
      return;
    }

    setState(() => _isLoading = true);

    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => _isLoading = false);

    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('注册成功'),
        content: Text('欢迎加入！\n邀请码: ${inviteCode.isEmpty ? "未使用" : inviteCode}'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close success dialog

              if (context.mounted) {
                Navigator.of(context).pop(); // Go back to login
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const AppLogo(size: 80),
            const SizedBox(height: 40),
            const Text(
              '创建新账号',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请填写以下信息完成注册',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            CustomTextField(
              controller: _phoneController,
              label: '手机号码',
              prefixIcon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _passwordController,
              label: '设置密码',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _inviteCodeController,
              label: '邀请码 (选填)',
              prefixIcon: Icons.card_giftcard_rounded,
            ),
            const SizedBox(height: 40),
            GradientButton(
              text: '立即注册',
              onPressed: _handleRegister,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
