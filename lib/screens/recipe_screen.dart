
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/recipe_model.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  final Color primaryGreen = const Color(0xFF2D6A4F);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  Future<List<RecipeRecommendation>> _fetchFeaturedRecipes() async {
    try {
      final uri = Uri.http('10.130.202.37:5000', '/get_all_recipes');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) => RecipeRecommendation.fromJson(item)).toList();
      } else {
        throw Exception("Failed to load recipes");
      }
    } catch (e) {
      debugPrint("API Error: $e");
      return [];
    }
  }

  Future<void> _deleteRecipe(String foodName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .doc(foodName)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$foodName removed from Cookbook")),
      );
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }
  
  Future<void> _saveRecipe(RecipeRecommendation recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_recipes')
          .doc(recipe.food)
          .set({
        'food': recipe.food,
        'ingredients': recipe.ingredients,
        'directions': recipe.directions,
        'total_time': recipe.totalTime,
        'rating': recipe.rating,
        'servings': recipe.servings,
        'calories': 0,
        'savedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${recipe.food} added to your Cookbook!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save recipe.")),
      );
    }
  }

  String _safeTime(String value) {
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'nan') return "Time not available";
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Recipe Hub",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search recipes...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "🔥 Featured Recipes",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<RecipeRecommendation>>(
              future: _fetchFeaturedRecipes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final featured = snapshot.data
                        ?.where((r) => r.food.toLowerCase().contains(_searchQuery))
                        .toList() ??
                    [];

                if (featured.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text("No recipes found."),
                  );
                }

                return SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: 20),
                    itemCount: featured.length,
                    itemBuilder: (context, index) {
                      return _buildFeaturedCard(featured[index]);
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "📚 My Saved Cookbook",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('saved_recipes')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final savedDocs = snapshot.data!.docs.where((doc) {
                  final name = (doc.data() as Map<String, dynamic>)['food'] ?? "";
                  return name.toString().toLowerCase().contains(_searchQuery);
                }).toList();

                if (savedDocs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text("No matching recipes found."),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  itemCount: savedDocs.length,
                  itemBuilder: (context, index) {
                    final recipe = RecipeRecommendation.fromJson(
                      savedDocs[index].data() as Map<String, dynamic>,
                    );

                    return Dismissible(
                      key: Key(recipe.food),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) => _deleteRecipe(recipe.food),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: _buildSavedListTile(recipe),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(RecipeRecommendation recipe) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(recipe: recipe),
        ),
      ),
      child: Container(
        width: 185,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: primaryGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recipe.food,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              _safeTime(recipe.totalTime),
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      Text(
                        " ${recipe.rating}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _saveRecipe(recipe),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryGreen.withOpacity(0.12),
                    child: Icon(Icons.add, color: primaryGreen, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedListTile(RecipeRecommendation recipe) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF0F3EE),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: primaryGreen.withOpacity(0.12),
          child: Icon(Icons.menu_book, color: primaryGreen),
        ),
        title: Text(
          recipe.food,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_safeTime(recipe.totalTime)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            Text(
              " ${recipe.rating}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () => _deleteRecipe(recipe.food),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(recipe: recipe),
          ),
        ),
      ),
    );
  }
}

class RecipeDetailScreen extends StatelessWidget {
  final RecipeRecommendation recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  String _safeTime(String value) {
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'nan') return "Time not available";
    return text;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2D6A4F);

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        onPressed: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;

          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('saved_recipes')
                .doc(recipe.food)
                .set({
              'food': recipe.food,
              'ingredients': recipe.ingredients,
              'directions': recipe.directions,
              'total_time': recipe.totalTime,
              'rating': recipe.rating,
              'servings': recipe.servings,
              'savedAt': FieldValue.serverTimestamp(),
            });

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("🥗 ${recipe.food} added to your Cookbook!"),
                  backgroundColor: primaryGreen,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: Could not save recipe.")),
              );
            }
          }
        },
        icon: const Icon(Icons.bookmark_add, color: Colors.white),
        label: const Text(
          "Save to Cookbook",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            backgroundColor: primaryGreen,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.food,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _detailStat(Icons.timer, _safeTime(recipe.totalTime)),
                      _detailStat(Icons.people, "${recipe.servings} Servings"),
                      _detailStat(Icons.star, "${recipe.rating} Rating"),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "🥗 Ingredients",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Text(
                    recipe.ingredients,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "👨‍🍳 Directions",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Text(
                    recipe.directions,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailStat(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2D6A4F)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
