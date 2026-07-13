import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _answerController = TextEditingController();

  bool _isLoading = false;
  int _currentStep = 1;

  String? _securityQuestion;
  String? _storedAnswerHash;

  String _hashSecurityAnswer(String answer) {
    final normalized = answer.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _findUser() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final userData = snapshot.docs.first.data();

        setState(() {
          _securityQuestion = userData['securityQuestion'] as String?;
          _storedAnswerHash = userData['securityAnswerHash'] as String?;
          _currentStep = 2;
        });
      } else {
        _showSnackBar("No account found with this email.");
      }
    } catch (e) {
      _showSnackBar("Error searching for user: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyAndSend() async {
    final userAnswer = _answerController.text.trim();
    final enteredHash = _hashSecurityAnswer(userAnswer);

    if (_storedAnswerHash == null || enteredHash != _storedAnswerHash) {
      _showSnackBar("Incorrect answer. Please try again.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      _showSnackBar("Error sending reset link: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Verification Successful"),
        content: const Text("A reset link has been sent to your email."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              "Back to Login",
              style: TextStyle(color: Color(0xFF2D6A4F)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Reset Password",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D6A4F),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _currentStep == 1
                  ? "Verify your account email to continue."
                  : "Answer your security question.",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            if (_currentStep == 1) ...[
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email Address",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.email,
                    color: Color(0xFF2D6A4F),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _isLoading ? null : _findUser,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Find My Account",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],

            if (_currentStep == 2) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _securityQuestion ?? "No question found.",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D6A4F),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _answerController,
                decoration: InputDecoration(
                  labelText: "Your Answer",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.security,
                    color: Color(0xFF2D6A4F),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _isLoading ? null : _verifyAndSend,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Verify & Send Reset Link",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                    _securityQuestion = null;
                    _storedAnswerHash = null;
                    _answerController.clear();
                  });
                },
                child: const Text(
                  "Use a different email",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}