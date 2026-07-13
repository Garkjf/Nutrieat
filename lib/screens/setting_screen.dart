import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _isUploadingPhoto = false;

  void _openRoute(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<Map<String, dynamic>?> _getUserProfile(String? uid) async {
    if (uid == null || uid.isEmpty) return null;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<String> _saveImageLocally(File imageFile, String uid) async {
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${directory.path}/profile_images');

    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    final savedPath = '${profileDir.path}/$uid.jpg';
    final savedImage = await imageFile.copy(savedPath);
    return savedImage.path;
  }

  Future<void> _pickAndSaveProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final file = File(pickedFile.path);
      final localPath = await _saveImageLocally(file, user.uid);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoPath': localPath,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully.')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Widget _buildAvatar(String? photoPath, {double radius = 30}) {
    if (photoPath != null && photoPath.isNotEmpty) {
      final imageFile = File(photoPath);
      if (imageFile.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFD8E2DC),
          backgroundImage: FileImage(imageFile),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFD8E2DC),
      child: Icon(
        Icons.person,
        color: const Color(0xFF2D6A4F),
        size: radius + 5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B4332),
                ),
              ),
              const SizedBox(height: 25),
              FutureBuilder<Map<String, dynamic>?>(
                future: _getUserProfile(user?.uid),
                builder: (context, snapshot) {
                  final displayUsername =
                      snapshot.data?['username'] ?? 'NutriEat User';
                  final photoPath = snapshot.data?['photoPath'] as String?;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            _buildAvatar(photoPath, radius: 30),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: GestureDetector(
                                onTap: _isUploadingPhoto
                                    ? null
                                    : _pickAndSaveProfileImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D6A4F),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: _isUploadingPhoto
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayUsername,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user?.email ?? 'User Email',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap the camera icon to change photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D6A4F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _openRoute(
                            EditProfileScreen(
                              currentUsername: displayUsername,
                              currentPhotoPath: photoPath,
                            ),
                          ),
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                'General',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              _buildSettingTile(
                Icons.account_circle_outlined,
                'Account Details',
                'View profile and status',
                () => _openRoute(const AccountScreen()),
              ),
              _buildSettingTile(
                Icons.notifications_none_rounded,
                'Notifications',
                'Manage app alerts',
                () {},
                trailing: Switch(
                  activeColor: const Color(0xFF2D6A4F),
                  value: _notificationsEnabled,
                  onChanged: (v) =>
                      setState(() => _notificationsEnabled = v),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Support & Legal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              _buildSettingTile(
                Icons.help_outline_rounded,
                'Help & Support',
                'FAQs and Contact Info',
                () => _openRoute(const HelpSupportScreen()),
              ),
              _buildSettingTile(
                Icons.info_outline_rounded,
                'About NutriEat',
                'Our mission and version',
                () => _openRoute(const AboutScreen()),
              ),
              const SizedBox(height: 40),
              Center(
                child: TextButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2D6A4F)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final String currentUsername;
  final String? currentPhotoPath;

  const EditProfileScreen({
    super.key,
    required this.currentUsername,
    this.currentPhotoPath,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUsername);
    _emailController =
        TextEditingController(text: FirebaseAuth.instance.currentUser?.email);
    _photoPath = widget.currentPhotoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<String> _saveImageLocally(File imageFile, String uid) async {
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${directory.path}/profile_images');

    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    final savedPath = '${profileDir.path}/$uid.jpg';
    final savedImage = await imageFile.copy(savedPath);
    return savedImage.path;
  }

  Future<void> _pickAndSaveProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final file = File(pickedFile.path);
      final localPath = await _saveImageLocally(file, user.uid);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoPath': localPath,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _photoPath = localPath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Widget _buildAvatar() {
    if (_photoPath != null && _photoPath!.isNotEmpty) {
      final imageFile = File(_photoPath!);
      if (imageFile.existsSync()) {
        return CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFFD8E2DC),
          backgroundImage: FileImage(imageFile),
        );
      }
    }

    return const CircleAvatar(
      radius: 50,
      backgroundColor: Color(0xFFD8E2DC),
      child: Icon(Icons.person, size: 50, color: Color(0xFF2D6A4F)),
    );
  }

  Future<void> _handleUpdate() async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'username': _nameController.text.trim(),
        'photoPath': _photoPath,
      }, SetOptions(merge: true));

      if (_emailController.text.trim() != user.email) {
        await user.verifyBeforeUpdateEmail(_emailController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please check your new email for a verification link!'),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                _buildAvatar(),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndSaveProfileImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isUploadingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap the camera icon to choose a profile photo',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _isSaving ? null : _handleUpdate,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _showPasswordDialog(BuildContext context) {
    final TextEditingController currentPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Security Update'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please verify your identity to change your password.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: currentPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: confirmPassController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (newPassController.text !=
                            confirmPassController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('New passwords do not match!'),
                            ),
                          );
                          return;
                        }

                        if (newPassController.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'New password must be at least 6 characters.',
                              ),
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          final credential = EmailAuthProvider.credential(
                            email: user!.email!,
                            password: currentPassController.text.trim(),
                          );

                          await user.reauthenticateWithCredential(credential);
                          await user.updatePassword(
                            newPassController.text.trim(),
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully!'),
                              ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        } finally {
                          if (context.mounted) {
                            setDialogState(() => isLoading = false);
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String joinDate = user?.metadata.creationTime != null
        ? DateFormat.yMMMMd().format(user!.metadata.creationTime!)
        : 'N/A';

    return Scaffold(
      appBar: AppBar(title: const Text('Account Details'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoTile('User ID', user?.uid ?? 'Unknown'),
            _buildInfoTile('Email Address', user?.email ?? 'Unknown'),
            _buildInfoTile('Member Since', joinDate),
            const Divider(height: 30),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.lock_reset,
                color: Color(0xFF2D6A4F),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Update your login security'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPasswordDialog(context),
            ),
            const Spacer(),
            const Text(
              'Privacy Disclaimer',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const Text(
              'Your data is encrypted and stored securely in our Firebase Cloud. NutriEat uses secure protocols to protect your credentials.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How can we help?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text(
              'Our dedicated support team is here to ensure your NutriEat experience is seamless. Whether you are facing a technical glitch, need help understanding your recommendation meal plans, or have questions about your subscription, we are just a message away.',
              style: TextStyle(height: 1.5, fontSize: 15),
            ),
            const SizedBox(height: 30),
            _contactCard(Icons.phone, 'Call Us', '+44 020 7946 0123'),
            _contactCard(Icons.email, 'Email Support', 'abc@gmail.com'),
            _contactCard(
              Icons.chat_bubble_outline,
              'Live Chat',
              'Available 9 AM - 6 PM',
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(IconData icon, String title, String detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2D6A4F)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(detail, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About NutriEat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              size: 80,
              color: Color(0xFF2D6A4F),
            ),
            const SizedBox(height: 20),
            const Text(
              'NutriEat v1.0.2',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 25),
            const Text(
              "NutriEat is more than just a calorie tracker; it is a sophisticated recommendation-driven ecosystem designed to harmonize your relationship with food. Founded on the principle that 'one size does not fit all,' our platform utilizes a hybrid machine learning model to analyze your unique metabolic needs, dietary preferences, and fitness milestones. "
              "\n\nWe believe that healthy eating should be intuitive, not restrictive. By integrating real-time data from your logged meals with personalized recommendation optimization, we provide you with a roadmap to success that adapts as you grow. Our mission is to empower millions to take control of their health through the power of data, community, and intelligent meal planning. Thank you for making NutriEat a part of your journey toward a healthier, happier you.",
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 30),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('View Open Source Licenses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'NutriEat',
                  applicationVersion: '1.0.2',
                  applicationIcon: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: Color(0xFF2D6A4F),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            const Text(
              'Developed by the NutriEat Recommendation Team\n© 2026 NutriEat Inc. All Rights Reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}