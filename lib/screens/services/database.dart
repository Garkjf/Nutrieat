import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'nutrient_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtime = FirebaseDatabase.instance;

  // 1. USER PROFILE METHODS (Firebase Database)

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final snapshot = await _realtime.ref("users/$uid").get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception("Failed to get user profile: $e");
    }
  }

  Future<bool> verifySecurityAnswer(String uid, String answer) async {
    final profile = await getUserProfile(uid);
    if (profile == null) return false;
    return profile['securityAnswer'] == answer.trim().toLowerCase();
  }

Future<void> updateUsername(String uid, String newName) async {
  try {
    await _realtime.ref("users/$uid").update({
      'username': newName,
    });
  } catch (e) {
    throw Exception("Failed to update username: $e");
  }
}
  // 2. USER PREFERENCES & GOALS (Cloud Firestore)
  // Records personal data like allergies and weight goals per user
  Future<void> updateUserPreferences(String uid, Map<String, dynamic> prefs) async {
    try {
      // Stores preferences in a specific 'profile' sub-collection
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('preferences')
          .set(prefs, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to save preferences: $e");
    }
  }

  /// Retrieves a user's specific dietary and goal settings
  Future<Map<String, dynamic>?> getUserPreferences(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('preferences')
          .get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }
  // 3. FOOD ENTRY METHODS (Cloud Firestore)

  CollectionReference<Map<String, dynamic>> _userFoodCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('food_entries');
  }

  /// Stream of food entries for real-time history updates
  Stream<List<FoodEntry>> foodEntriesStream(String uid) {
    return _userFoodCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FoodEntry.fromDoc(doc)).toList();
    });
  }

  /// Adds a new food entry to the database
  Future<void> addFoodEntry(String uid, Map<String, dynamic> entryData) async {
    try {
      entryData['createdAt'] = FieldValue.serverTimestamp();
      await _userFoodCollection(uid).add(entryData);
    } catch (e) {
      throw Exception("Failed to add food: $e");
    }
  }

  /// Deletes a specific log entry
  Future<void> deleteFoodEntry(String uid, String entryId) async {
    try {
      await _userFoodCollection(uid).doc(entryId).delete();
    } catch (e) {
      throw Exception("Failed to delete food: $e");
    }
  }

  Future<void> resetFoodEntries(String uid) async {
    try {
      final snapshot = await _userFoodCollection(uid).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw Exception("Failed to reset data: $e");
    }
  }
}