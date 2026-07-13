import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:nutrieat/main.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _answerController = TextEditingController();

  String _selectedQuestion = "What is your pet's name?";
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final RegExp _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&.#\-_])[A-Za-z\d@$!%*?&.#\-_]{6,}$',
  );

  String _hashSecurityAnswer(String answer) {
    final normalized = answer.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final confirmEmail = _confirmEmailController.text.trim();

      if (email != confirmEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and confirm email must match')),
        );
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user!;
        final hashedAnswer = _hashSecurityAnswer(_answerController.text);

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': _usernameController.text.trim(),
          'email': user.email?.trim().toLowerCase(),
          'securityQuestion': _selectedQuestion,
          'securityAnswerHash': hashedAnswer,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainWrapper(user: user)),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Registration failed';
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'The account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is not valid.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D6A4F),
                ),
              ),
              const Text("Join Nutrieat", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              _buildInputField(
                controller: _usernameController,
                label: 'Username',
                prefixIcon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.email,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter email';
                  }
                  if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}").hasMatch(value.trim())) {
                    return 'Enter valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _confirmEmailController,
                label: 'Confirm Email',
                prefixIcon: Icons.email_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Confirm email';
                  }
                  if (value.trim() != _emailController.text.trim()) {
                    return 'Email addresses do not match';
                  }
                  return null;
                },
                obscureText: false,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _passwordController,
                label: 'Password',
                prefixIcon: Icons.lock,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter password';
                  }
                  if (!_passwordRegex.hasMatch(value)) {
                    return 'Min 6 chars, include upper, lower, number, symbol';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedQuestion,
                items: const [
                  DropdownMenuItem(
                    value: "What is your pet's name?",
                    child: Text("What is your pet's name?"),
                  ),
                  DropdownMenuItem(
                    value: "What is your favourite color?",
                    child: Text("What is your favourite color?"),
                  ),
                  DropdownMenuItem(
                    value: "What city were you born in?",
                    child: Text("What city were you born in?"),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _selectedQuestion = v ?? _selectedQuestion),
                decoration: InputDecoration(
                  labelText: "Security Question",
                  prefixIcon: const Icon(Icons.question_mark_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _answerController,
                label: "Security Answer",
                prefixIcon: Icons.help_outline,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter your answer' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Create Account",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}