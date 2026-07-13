import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/database.dart';
import 'services/nutrient_model.dart'; 

class DailyNutrientsScreen extends StatefulWidget {
  const DailyNutrientsScreen({super.key});

  @override
  State<DailyNutrientsScreen> createState() => _DailyNutrientsScreenState();
}

class _DailyNutrientsScreenState extends State<DailyNutrientsScreen> {
  final DatabaseService _db = DatabaseService();
  final Color primaryGreen = const Color(0xFF2D6A4F);

  // --- STATE ---
  DateTime _selectedDate = DateTime.now();
  // We keep the categories in a list we can modify
  List<String> _mealCategories = ["Breakfast", "Lunch", "Dinner", "Snacks"];

  // --- LOGIC ---

  String _dateKey(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Automatically suggests a meal type based on the current hour
  String _getMealTypeByTime() {
    int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return "Breakfast";
    if (hour >= 11 && hour < 16) return "Lunch";
    if (hour >= 16 && hour < 22) return "Dinner";
    return "Snacks";
  }

  Future<void> _moveMeal(String foodId, String newCategory) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('food_entries')
        .doc(foodId)
        .update({'mealType': newCategory});
  }

  Future<void> _delete(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    await _db.deleteFoodEntry(user!.uid, id);
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    DateTime start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DateTime end = start.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Nutri Diary', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildHorizontalCalendar(),
          Expanded(
            child: StreamBuilder<List<FoodEntry>>(
              stream: _getFilteredStream(user!.uid, start, end),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final allEntries = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildDailyGoalSummary(user.uid, allEntries),
                    ..._mealCategories.map((category) {
                      final sectionItems = allEntries.where((e) => e.mealType == category).toList();
                      return _buildDropTarget(category, sectionItems);
                    }).toList(),
                    _buildAddCategoryButton(),
                    const SizedBox(height: 50),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalSummary(String uid, List<FoodEntry> entries) {
  final totalCalories = entries.fold<int>(0, (sum, e) => sum + e.calories);

  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_goals')
        .doc(_dateKey(_selectedDate))
        .snapshots(),
    builder: (context, snapshot) {
      final goal = snapshot.data?.exists == true
          ? ((snapshot.data!.data() as Map<String, dynamic>)['calorie_goal'] ?? 2500) as int
          : 2500;

      final progress = goal > 0 ? (totalCalories / goal).clamp(0.0, 1.0) : 0.0;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$totalCalories / $goal kcal",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
}

  // --- COMPONENTS ---

  Widget _buildHorizontalCalendar() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        reverse: true,
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().subtract(Duration(days: index));
          bool isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryGreen : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E').format(date), style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12)),
                  Text(date.day.toString(), style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropTarget(String category, List<FoodEntry> items) {
    return DragTarget<FoodEntry>(
      onAccept: (food) => _moveMeal(food.id, category),
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty ? primaryGreen.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      // Delete Category Button (Only if it's not a core category or if it's empty)
                      if (!["Breakfast", "Lunch", "Dinner"].contains(category))
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                          onPressed: () => setState(() => _mealCategories.remove(category)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.grey, size: 22),
                        onPressed: () => _showQuickAddSheet(category),
                      ),
                    ],
                  ),
                ],
              ),
              if (items.isEmpty) 
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text("Empty", style: TextStyle(color: Colors.black26, fontSize: 11)),
                )
              else 
                ...items.map((item) => _buildDraggableCard(item)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableCard(FoodEntry item) {
    return LongPressDraggable<FoodEntry>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.8, child: SizedBox(width: 300, child: _buildFoodCard(item))),
      ),
      childWhenDragging: Opacity(opacity: 0.2, child: _buildFoodCard(item)),
      child: _buildFoodCard(item),
    );
  }

  Widget _buildFoodCard(FoodEntry item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(item.id),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade100)),
        child: ListTile(
          title: Text(item.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${item.calories} kcal • P ${item.protein}g • C ${item.carbs}g • S ${item.sugar}g',
            style: const TextStyle(fontSize: 12),
            ),
          trailing: Text(DateFormat('hh:mm a').format(item.timestamp), style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildAddCategoryButton() {
    return OutlinedButton.icon(
      onPressed: _showAddCategoryDialog,
      icon: const Icon(Icons.add),
      label: const Text("Add Custom Meal Section"),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
    );
  }

  // --- SHEETS & DIALOGS ---

  void _showAddCategoryDialog() {
    TextEditingController _catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Section"),
        content: TextField(controller: _catController, decoration: const InputDecoration(hintText: "e.g. Pre-Workout")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (_catController.text.isNotEmpty) {
                setState(() => _mealCategories.add(_catController.text));
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  void _showQuickAddSheet(String category) {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController calCtrl = TextEditingController();
  final TextEditingController proteinCtrl = TextEditingController();
  final TextEditingController carbsCtrl = TextEditingController();
  final TextEditingController fatCtrl = TextEditingController();
  final TextEditingController sugarCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (context) {
      String selectedMealType = category.isNotEmpty ? category : _getMealTypeByTime();
      TimeOfDay selectedTime = TimeOfDay.now();

      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 25,
              right: 25,
              top: 25,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Add Food Entry",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Food Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: calCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Calories",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: proteinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Protein",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: carbsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Carbs",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fatCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Fat",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: sugarCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Sugar",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: selectedMealType,
                    items: ["Breakfast", "Lunch", "Dinner", "Snacks"]
                        .map(
                          (meal) => DropdownMenuItem(
                            value: meal,
                            child: Text(meal),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() {
                          selectedMealType = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Meal Type",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),

                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text("Time of Meal"),
                    trailing: Text(
                      selectedTime.format(context),
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (time != null) {
                        setModalState(() {
                          selectedTime = time;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null || nameCtrl.text.trim().isEmpty) return;

                      final finalDateTime = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('food_entries')
                          .add({
                        'name': nameCtrl.text.trim(),
                        'calories': int.tryParse(calCtrl.text) ?? 0,
                        'protein': double.tryParse(proteinCtrl.text) ?? 0.0,
                        'carbs': double.tryParse(carbsCtrl.text) ?? 0.0,
                        'fat': double.tryParse(fatCtrl.text) ?? 0.0,
                        'sugar': double.tryParse(sugarCtrl.text) ?? 0.0,
                        'mealType': selectedMealType,
                        'timestamp': Timestamp.fromDate(finalDateTime),
                      });

                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      "Save Entry",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  Stream<List<FoodEntry>> _getFilteredStream(String uid, DateTime start, DateTime end) {
    return FirebaseFirestore.instance
        .collection('users').doc(uid).collection('food_entries')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) => snap.docs.map((doc) => FoodEntry.fromDoc(doc)).toList());
  }
}