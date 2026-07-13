import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Attempt Firebase Login
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Optional: Bootstrap profile in Realtime DB if missing
      final user = cred.user;
      if (user != null) {
        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final snap = await docRef.get();

        if (!snap.exists) {
          await docRef.set({
            'email': user.email,
            'username': 'NutriEat User',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // NOTE: Navigation to Home happens automatically via StreamBuilder in main.dart
      
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed';
      if (e.code == 'user-not-found') errorMessage = 'No user found for that email.';
      else if (e.code == 'wrong-password') errorMessage = 'Wrong password provided.';
      else if (e.code == 'invalid-email') errorMessage = 'The email address is invalid.';
      
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Authentication Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF2D6A4F))),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2D6A4F)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.restaurant_menu, size: 80, color: Color(0xFF2D6A4F)),
                const SizedBox(height: 20),
                const Text(
                  "Welcome Back",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F)),
                  textAlign: TextAlign.center,
                ),
                const Text("Log in to your Nutrieat account", 
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration("Email", Icons.email),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(
                    "Password", 
                    Icons.lock,
                    suffix: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Password too short' : null,
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          activeColor: const Color(0xFF2D6A4F),
                          value: _rememberMe, 
                          onChanged: (v) => setState(() => _rememberMe = v!)
                        ),
                        const Text("Remember me", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (c) => const ForgotPasswordScreen())),
                      child: const Text("Forgot Password?", 
                        style: TextStyle(color: Color(0xFF2D6A4F), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Login Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _login, 
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Log In", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (c) => const RegisterScreen())),
                  child: const Text("New to Nutri-AI? Create an account", 
                    style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}