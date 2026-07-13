import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color primaryGreen = const Color(0xFF2D6A4F);
  final DatabaseService _db = DatabaseService();

  final String flaskBaseUrl = "http://10.130.202.37:5000";

  String selectedFilter = "All";
  String nutrientPriority = "None";
  bool _showAllRecentLogs = false;
  
  final List<String> filters = ["All", "Keto", "Halal", "Vegan", "High Protein"];
  
  List<dynamic> _aiPicks = [];
  bool _isLoadingPicks = true;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _calController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAIPicks();
  }
  
  bool _containsAny(String text, List<String> keywords) {
  final lower = text.toLowerCase();
  return keywords.any((k) => lower.contains(k));
}

bool _computeIsHalal(String name) {
  const haram = [
    'pork', 'lard', 'bacon', 'ham', 'alcohol', 'wine', 'gelatin', 'pepperoni', 'salami'
  ];
  return !_containsAny(name, haram);
}

bool _computeIsVegan(String name) {
  const landMeat = [
    'chicken', 'pork', 'beef', 'lamb', 'bacon', 'ham', 'turkey', 'duck',
    'veal', 'steak', 'sausage', 'meatball', 'burger', 'hot dog','brisket', 'ribs', 
    'prosciutto', 'pastrami','pepperoni', 'salami', 'mortadella','meat'
  ];
  const seafood = [
    'fish', 'tuna', 'salmon', 'shrimp', 'crab', 'seafood', 'prawn',
    'cod', 'lobster', 'sardine', 'anchovy', 'mackerel', 'squid','octopus', 
    'clam', 'oyster', 'mussel'
  ];
  const byproducts = [
    'egg', 'milk', 'cheese', 'cream', 'butter', 'honey', 'yogurt',
    'whey', 'casein', 'mayo', 'custard', 'flan', 'pudding'
  ];
  return !_containsAny(name, [...landMeat, ...seafood, ...byproducts]);
}

bool _computeIsKeto(double fat, double protein, double carbs, double sugar) {
  return carbs <= 10 && sugar <= 5 && fat >= protein * 0.6;
}

bool _passesSelectedFilter(Map<String, dynamic> item) {
  final name = (item['name'] ?? '').toString();
  final protein = ((item['protein'] ?? 0) as num).toDouble();
  final carbs = ((item['carbs'] ?? item['carbohydrates'] ?? 0) as num).toDouble();
  final fat = ((item['fat'] ?? 0) as num).toDouble();
  final sugar = ((item['sugar'] ?? 0) as num).toDouble();

  // Recompute from current values instead of trusting old saved flags
  final isHalal = _computeIsHalal(name);
  final isVegan = _computeIsVegan(name);
  final isKeto = _computeIsKeto(fat, protein, carbs, sugar);

  switch (selectedFilter) {
    case "Halal":
      return isHalal;
    case "Vegan":
      return isVegan;
    case "Keto":
      return isKeto;
    case "High Protein":
      return protein >= 10;
    default:
      return true;
  }
}

String _todayKey() {
  final now = DateTime.now();
  return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
}

Future<void> _setTodayCalorieGoal(String uid, int goal) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_goals')
      .doc(_todayKey())
      .set({
    'calorie_goal': goal,
    'date': _todayKey(),
    'updated_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

Future<void> _showCalorieGoalDialog(String uid, int currentGoal) async {
  final controller = TextEditingController(text: currentGoal.toString());

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Set Today's Calorie Goal"),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Calories",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () async {
            final value = int.tryParse(controller.text);
            if (value != null && value > 0) {
              await _setTodayCalorieGoal(uid, value);
              if (mounted) Navigator.pop(context);
            }
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}

  // --- API LOGIC ---

  Future<void> _fetchAIPicks() async {
    try {
      final response = await http.get(Uri.parse('$flaskBaseUrl/get_featured'));
      if (response.statusCode == 200) {
        setState(() {
          _aiPicks = json.decode(response.body);
          _isLoadingPicks = false;
        });
      }
    } catch (e) {
      debugPrint("AI Picks Error: $e");
      setState(() => _isLoadingPicks = false);
    }
  }

  Future<void> _searchDataset(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final response = await http.get(Uri.parse('$flaskBaseUrl/search_dataset?q=$query'));
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      setState(() => _isSearching = false);
    }
  }

  // --- DATABASE LOGIC ---

  Future<void> _saveFood({String? docId, Map<String, dynamic>? quickData}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = quickData != null
      ? (quickData['name'] ?? quickData['food'] ?? '').toString()
      : _nameController.text.trim();

  final calories = quickData != null
      ? ((quickData['calories'] ?? quickData['Caloric Value'] ?? 0) as num).toInt()
      : ((double.tryParse(_calController.text) ?? 0.0).round());

  final protein = quickData != null
      ? ((quickData['protein'] ?? 0.0) as num).toDouble()
      : (double.tryParse(_proteinController.text) ?? 0.0);

  final carbs = quickData != null
      ? ((quickData['carbs'] ?? quickData['carbohydrates'] ?? 0.0) as num).toDouble()
      : (double.tryParse(_carbsController.text) ?? 0.0);

  final fat = quickData != null
      ? ((quickData['fat'] ?? 0.0) as num).toDouble()
      : (double.tryParse(_fatController.text) ?? 0.0);

  final sugar = quickData != null
      ? ((quickData['sugar'] ?? 0.0) as num).toDouble()
      : (double.tryParse(_sugarController.text) ?? 0.0);

  final data = {
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'timestamp': FieldValue.serverTimestamp(),
    'is_halal': _computeIsHalal(name),
    'is_vegan': _computeIsVegan(name),
    'is_keto': _computeIsKeto(fat, protein, carbs, sugar),
  };

  if (docId == null) {
    await _db.addFoodEntry(user.uid, data);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Logged: ${data['name']}")),
    );
  } else {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('food_entries')
        .doc(docId)
        .update(data);
  }

  _clearControllers();
  if (quickData == null && mounted) Navigator.pop(context);
}
  void _clearControllers() {
    _nameController.clear(); _calController.clear();
    _proteinController.clear(); _carbsController.clear(); 
    _fatController.clear(); _sugarController.clear();
  }

  // --- UI COMPONENTS ---
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              if (user != null) _buildDailyDashboard(user.uid),
              const SizedBox(height: 25),
              
              Row(
                children: [
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 10),
                  _buildNutrientFilterMenu(),
                ],
              ),
              
              if (_searchResults.isNotEmpty) _buildSearchResultsList(),
              const SizedBox(height: 20),
              _buildFilterChips(),
              const SizedBox(height: 25),
              const Text("Food Suggestions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _isLoadingPicks ? const LinearProgressIndicator() : _buildAIPicksList(),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent Logs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (nutrientPriority != "None") 
                    Text("Sorted by $nutrientPriority", style: TextStyle(color: primaryGreen, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              if (user != null) _buildRecentLogs(user.uid),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showFoodSheet(context),
      ),
    );
  }

  Widget _buildNutrientFilterMenu() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.tune, color: primaryGreen),
        onSelected: (value) => setState(() => nutrientPriority = value),
        itemBuilder: (context) => [
          const PopupMenuItem(value: "None", child: Text("Default (Time)")),
          const PopupMenuItem(value: "Protein", child: Text("High Protein First")),
          const PopupMenuItem(value: "Carbohydrates", child: Text("Low Carbs First")),
          const PopupMenuItem(value: "Sugar", child: Text("Low Sugar First")),
        ],
      ),
    );
  }

  Widget _buildRecentLogs(String uid) {
  final query = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('food_entries')
      .orderBy('timestamp', descending: true)
      .limit(30);

  return StreamBuilder<QuerySnapshot>(
    stream: query.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return Text("Error: ${snapshot.error}");
      if (!snapshot.hasData) return const CircularProgressIndicator();

      List<QueryDocumentSnapshot> docs = List.from(snapshot.data!.docs);

      docs = docs.where((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        return _passesSelectedFilter(data);
      }).toList();

      if (nutrientPriority == "Protein") {
        docs.sort((a, b) {
          final pa = ((a.data() as Map<String, dynamic>)['protein'] ?? 0) as num;
          final pb = ((b.data() as Map<String, dynamic>)['protein'] ?? 0) as num;
          return pb.compareTo(pa);
        });
      } else if (nutrientPriority == "Carbohydrates") {
        docs.sort((a, b) {
          final ca = ((a.data() as Map<String, dynamic>)['carbs'] ?? 0) as num;
          final cb = ((b.data() as Map<String, dynamic>)['carbs'] ?? 0) as num;
          return ca.compareTo(cb);
        });
      } else if (nutrientPriority == "Sugar") {
        docs.sort((a, b) {
          final sa = ((a.data() as Map<String, dynamic>)['sugar'] ?? 0) as num;
          final sb = ((b.data() as Map<String, dynamic>)['sugar'] ?? 0) as num;
          return sa.compareTo(sb);
        });
      }

      if (docs.isEmpty) {
        return const Text("No recent logs yet.");
      }

      final visibleDocs = _showAllRecentLogs ? docs : docs.take(5).toList();
      final hasMoreThanFive = docs.length > 5;

      return Column(
        children: [
          ...visibleDocs.map(
            (doc) => _buildFoodListItem(
              doc.id,
              Map<String, dynamic>.from(doc.data() as Map<String, dynamic>),
            ),
          ),
          if (hasMoreThanFive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showAllRecentLogs = !_showAllRecentLogs;
                  });
                },
                child: Text(
                  _showAllRecentLogs ? "Show less" : "Want to see more?",
                  style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      );
    },
  );
}

  Widget _buildFoodListItem(String docId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu, color: primaryGreen, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showFoodSheet(context, docId: docId, existingData: data)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _deleteEntry(docId)),
            ],
          ),
          const Divider(),
          Wrap(
            spacing: 10,
            children: [
              _nutrientTag("🔥 ${data['calories']} kcal"),
              _nutrientTag("🥩 P: ${data['protein'] ?? 0}g"),
              _nutrientTag("🍞 C: ${data['carbs'] ?? 0}g"),
              _nutrientTag("🍭 S: ${data['sugar'] ?? 0}g"),
            ],
          )
        ],
      ),
    );
  }

  Widget _nutrientTag(String text) {
    return Text(text, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500));
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
      child: TextField(
        onChanged: (val) => _searchDataset(val),
        decoration: InputDecoration(
          hintText: "Search food database...", border: InputBorder.none, 
          icon: _isSearching ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search, size: 20)
        ),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    final filteredResults = _searchResults
      .where((item) => _passesSelectedFilter(Map<String, dynamic>.from(item)))
      .toList();

    return Container(
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredResults.length,
        itemBuilder: (context, index) {
          final item = filteredResults[index];
          return ListTile(
            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Cal: ${item['calories']} | Sugar: ${item['sugar'] ?? 0}g"),
            trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF2D6A4F)),
            onTap: () { _showFoodSheet(context, existingData: item); setState(() => _searchResults = []); },
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          bool isSelected = selectedFilter == filters[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(filters[index]), selected: isSelected, selectedColor: primaryGreen,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 12),
              onSelected: (bool selected) => setState(() => selectedFilter = filters[index]),
            ),
          );
        },
      ),
    );
  }

  

Widget _buildAIPicksList() {
  final filteredPicks = _aiPicks
      .where((item) => _passesSelectedFilter(Map<String, dynamic>.from(item)))
      .toList();

  return SizedBox(
    height: 100,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: filteredPicks.length,
      itemBuilder: (context, index) {
        final item = filteredPicks[index];
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                Text("${item['calories']} kcal", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const Spacer(),
                GestureDetector(onTap: () => _saveFood(quickData: item), child: Icon(Icons.add_circle, color: primaryGreen, size: 20)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyDashboard(String uid) {
  DateTime now = DateTime.now();
  DateTime startOfDay = DateTime(now.year, now.month, now.day);

  final goalStream = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_goals')
      .doc(_todayKey())
      .snapshots();

  final foodStream = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('food_entries')
      .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
      .snapshots();

  return StreamBuilder<DocumentSnapshot>(
    stream: goalStream,
    builder: (context, goalSnapshot) {
      final calorieGoal = goalSnapshot.data?.exists == true
          ? ((goalSnapshot.data!.data() as Map<String, dynamic>)['calorie_goal'] ?? 2500) as int
          : 2500;

      return StreamBuilder<QuerySnapshot>(
        stream: foodStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          double cal = 0;
          for (var doc in snapshot.data!.docs) {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            cal += ((data['calories'] ?? 0) as num).toDouble();
          }

          final progress = calorieGoal > 0 ? (cal / calorieGoal).clamp(0.0, 1.0) : 0.0;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Intake",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      Text(
                        "${cal.toInt()} / $calorieGoal kcal",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showCalorieGoalDialog(uid, calorieGoal),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Set today's goal"),
                      ),
                    ],
                  ),
                ),
                CircularProgressIndicator(
                  value: progress,
                  color: primaryGreen,
                  backgroundColor: Colors.white,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
  Future<void> _deleteEntry(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('food_entries').doc(id).delete();
  }

  void _showFoodSheet(BuildContext context, {String? docId, Map<String, dynamic>? existingData}) {
    if (existingData != null) {
      _nameController.text = existingData['name'].toString();
      _calController.text = existingData['calories'].toString();
      _proteinController.text = (existingData['protein'] ?? 0).toString();
      _carbsController.text = (existingData['carbs'] ?? 0).toString();
      _fatController.text = (existingData['fat'] ?? 0).toString();
      _sugarController.text = (existingData['sugar'] ?? 0).toString();
    } else { _clearControllers(); }

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(docId == null ? "Log New Food" : "Edit Log", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Food Name", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _calController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Calories")),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _proteinController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Protein"))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _carbsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Carbs"))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: _fatController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Fat"))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _sugarController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Sugar"))),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 50)),
                onPressed: () => _saveFood(docId: docId), 
                child: const Text("Save Entry", style: TextStyle(color: Colors.white))
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}