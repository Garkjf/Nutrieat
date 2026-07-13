import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

// Question Data Model
class SurveyQuestion {
  final String title;
  final String subtitle;
  List<String> options;
  final String apiKey;
  final bool isMultiSelect;

  SurveyQuestion({required this.title, required this.subtitle, required this.options, required this.apiKey, required this.isMultiSelect});
}

class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

String _getMealTypeByTime() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 11) return "Breakfast";
  if (hour >= 11 && hour < 16) return "Lunch";
  if (hour >= 16 && hour < 22) return "Dinner";
  return "Snacks";
}

class _RecommendPageState extends State<RecommendPage> with SingleTickerProviderStateMixin {
  final Color primaryGreen = const Color(0xFF2D6A4F);
  late TabController _tabController;
  final PageController _pageController = PageController();
  
  int _currentStep = 0;
  bool _isLoading = false;
  bool _showResults = false;
  List<dynamic> _recommendedMeals = [];
  final Map<String, String> _surveyAnswers = {};

  // Survey Questions
  final List<SurveyQuestion> _questions = [
  SurveyQuestion(title: "Main Goal?", subtitle: "What are we aiming for?", options: ["Muscle Gain", "Weight Loss", "General Health", "Keto"], apiKey: "goal", isMultiSelect: true),
  SurveyQuestion(title: "Allergies?", subtitle: "Select all that apply", options: ["None","Dairy", "Egg", "Gluten", "Nuts", "Soy", "Fish", "Shellfish"], apiKey: "allergies", isMultiSelect: true),
  SurveyQuestion(title: "Goal Intensity?", subtitle: "How strong should the plan be?", options: ["Maintenance", "Steady", "Aggressive"], apiKey: "intensity", isMultiSelect: false),
  SurveyQuestion(title: "Dietary Style?", subtitle: "General eating pattern", options: ["Everything", "Pescatarian", "Vegetarian", "Vegan"], apiKey: "diet_type", isMultiSelect: false),
  SurveyQuestion(title: "Halal Preference?", subtitle: "Filter haram items", options: ["Halal Only", "No Preference"], apiKey: "is_halal", isMultiSelect: false),
  SurveyQuestion(title: "Base Ingredient?", subtitle: "Main meal base", options: ["Chicken", "Beef", "Seafood", "Plant-based"], apiKey: "base", isMultiSelect: false),
  SurveyQuestion(title: "Protein Preference?", subtitle: "How protein-focused should meals be?", options: ["Standard", "High Protein", "Extra High Protein"], apiKey: "protein_pref", isMultiSelect: false),
  SurveyQuestion(title: "Nutrition Focus?", subtitle: "Which nutrition target matters most?", options: ["Balanced", "Low Sugar", "Low Carb", "High Protein", "Iron Rich", "Calcium Rich"], apiKey: "nutrition_focus", isMultiSelect: false),
  SurveyQuestion(title: "Meal Energy Size?", subtitle: "How heavy should the meal feel?", options: ["Light", "Regular", "Filling"], apiKey: "meal_size", isMultiSelect: false),
];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- LOGIC SECTION ---

  void _onAnswerSelected(String key, String value) {
    setState(() {
      _surveyAnswers[key] = value;

      // --- DYNAMIC FILTERING LOGIC ---
      if (key == "diet_type") {
        int baseIndex = _questions.indexWhere((q) => q.apiKey == "base");
        
        if (baseIndex != -1) {
          if (value == "Vegan" || value == "Vegetarian") {
            _questions[baseIndex].options = ["Plant-based"];
            
            _surveyAnswers["base"] = "Plant-based"; 
          } else if (value == "Pescatarian") {
            _questions[baseIndex].options = ["Seafood", "Plant-based"];
          } else {
            _questions[baseIndex].options = ["Chicken", "Beef", "Seafood", "Plant-based"];
          }
        }
      }
    });

    // Navigation logic (stays the same)
    if (_currentStep < _questions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _submitToAI();
    }
  }

  Future<void> _saveToCookbook(Map<String, dynamic> meal) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final String foodName = (meal['food'] ?? 'Unknown Recipe').toString();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved_recipes')
        .doc(foodName)
        .set({
      'food': foodName,
      'ingredients': (meal['ingredients'] ?? '').toString(),
      'directions': (meal['directions'] ?? '').toString(),
      'total_time': (meal['total_time'] ?? '').toString(),

      'rating': ((meal['rating'] ?? 0) as num).toDouble(),
      'servings': (meal['yield'] ?? meal['servings'] ?? '').toString(),

      'calories': ((meal['calories'] ?? 0) as num).toInt(),
      'protein': ((meal['protein'] ?? 0) as num).toDouble(),
      'fat': ((meal['fat'] ?? 0) as num).toDouble(),
      'carbs': ((meal['carbs'] ?? 0) as num).toDouble(),
      'sugar': ((meal['sugar'] ?? 0) as num).toDouble(),
      'calcium': ((meal['calcium'] ?? 0) as num).toDouble(),
      'url': (meal['url'] ?? '').toString(),

      'savedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$foodName added to your Cookbook!")),
    );
  } catch (e) {
    debugPrint("Save to Cookbook Error: $e");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to save to Cookbook.")),
    );
  }
}

  Future<void> _submitToAI() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      Map<String, String> params = Map.from(_surveyAnswers);
      params['user_id'] = user?.uid ?? "unknown_user";

      final uri = Uri.http('10.130.202.37:5000', '/recommend', params);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List planData = json.decode(response.body);

        // Save history to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('meal_plan_history')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'goal': _surveyAnswers['goal'],
          'intensity': _surveyAnswers['intensity'],
          'meals': planData, 
        });

        setState(() {
          _recommendedMeals = planData;
          _showResults = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recommendation Server Offline. Check IP connection!")));
    } finally {
      setState(() => _isLoading = false);
    }
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
    'veal', 'steak', 'sausage', 'meatball', 'burger', 'hot dog'
  ];
  const seafood = [
    'fish', 'tuna', 'salmon', 'shrimp', 'crab', 'seafood', 'prawn',
    'cod', 'lobster', 'sardine', 'anchovy', 'mackerel', 'squid'
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

Future<void> _addToDiary(Map<String, dynamic> meal) async {
  final user = FirebaseAuth.instance.currentUser;
  try {
    final name = meal['food'].toString();
    final calories = ((meal['calories'] ?? meal['Caloric Value'] ?? 0) as num).toInt();
    final protein = ((meal['protein'] ?? 0) as num).toDouble();
    final carbs = ((meal['carbs'] ?? 0) as num).toDouble();
    final fat = ((meal['fat'] ?? 0) as num).toDouble();
    final sugar = ((meal['sugar'] ?? 0) as num).toDouble();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('food_entries')
        .add({
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'sugar': sugar,
      'timestamp': FieldValue.serverTimestamp(),
      'mealType': _getMealTypeByTime(),
      'is_halal': meal['is_halal'] ?? _computeIsHalal(name),
      'is_vegan': meal['is_vegan'] ?? _computeIsVegan(name),
      'is_keto': _computeIsKeto(fat, protein, carbs, sugar),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Added $name to your diary!")),
    );
  } catch (e) {
    debugPrint("Error adding to diary: $e");
  }
}
  Future<void> _updateMealRanking(int points, String mealName) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('ai_feedback')
          .add({
        'name': mealName,
        'ranking_points': points,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'ai_feedback'
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI learned your preference for $mealName!")));
    } catch (e) {
      debugPrint("Ranking Save Error: $e");
    }
  }

  // --- UI SECTION ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Recommend Meal Planner", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryGreen,
          tabs: const [
            Tab(text: "New Plan", icon: Icon(Icons.auto_awesome)),
            Tab(text: "History", icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewPlanSection(),
          _buildHistoryView(),
        ],
      ),
    );
  }

  Widget _buildNewPlanSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_showResults) return _buildResultsView();

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_currentStep + 1) / _questions.length,
          backgroundColor: Colors.green.shade50,
          color: Colors.orangeAccent,
          minHeight: 8,
        ),
        Expanded(child: _buildSurveyView()),
      ],
    );
  }

  Widget _buildSurveyView() {
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return Padding(
          padding: const EdgeInsets.all(30),
          child: SingleChildScrollView(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Question ${index + 1} of 9", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(q.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(q.subtitle, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 40),
              ...q.options.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryGreen, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => _onAnswerSelected(q.apiKey, opt),
                    child: Text(opt, style: TextStyle(color: primaryGreen, fontSize: 18, fontWeight: FontWeight.w500)),
                  ),
                ),
              )).toList(),
            ],
          ),
          )
        );
      },
    );
  }

  Widget _buildResultsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Top Recommendation Picks", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => setState(() {
                  _showResults = false;
                  _currentStep = 0;
                  _surveyAnswers.clear();
                }),
                child: Text("Restart", style: TextStyle(color: primaryGreen)),
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recommendedMeals.length,
            itemBuilder: (context, index) {
              final meal = _recommendedMeals[index];
              return _buildMealCard(meal);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('meal_plan_history')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No history found. Try a new plan!"));

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate()) : "Date Unknown";
            final List meals = data['meals'] ?? [];

            return ExpansionTile(
              title: Text("Goal: ${data['goal']}"),
              subtitle: Text(date),
              children: meals.map((m) => _buildMealCard(m, isHistory: true)).toList(),
            );
          },
        );
      },
    );
  }

  // Helper Card Component for both Results and History
  Widget _buildMealCard(Map<String, dynamic> meal, {bool isHistory = false}) {
    final double rawScore = ((meal['survey_score'] ?? 0) as num).toDouble();
    final score = (rawScore * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: primaryGreen,
              child: Text(
                "$score%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              (meal['food'] ?? 'Unknown Meal').toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${meal['calories'] ?? 0} kcal | ${meal['protein'] ?? 0}g Protein",
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "💡 ${meal['reason'] ?? 'Matches your preferences'}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.bookmark_add, size: 18),
                      label: const Text("Save to Cookbook"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side: BorderSide(color: primaryGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          _saveToCookbook(Map<String, dynamic>.from(meal)),
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.add_task, color: primaryGreen, size: 18),
                      label: const Text("Add to Diary"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryGreen,
                        side: BorderSide(color: primaryGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          _addToDiary(Map<String, dynamic>.from(meal)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isHistory)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Rank accuracy:",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 10),
                  ...List.generate(
                    5,
                    (i) => IconButton(
                      icon: const Icon(Icons.star, color: Colors.amber, size: 20),
                      onPressed: () => _updateMealRanking(
                        i + 1,
                        (meal['food'] ?? 'Unknown Meal').toString(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}