import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shopping_list/data/categories.dart';
import 'package:shopping_list/models/grocery_item.dart';
import 'package:shopping_list/widgets/new_item.dart';

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  List<GroceryItem> _groceryItems = [];
  var _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() async {
    final url = Uri.https(
      'flutter-prep-40209-default-rtdb.firebaseio.com',
      'shopping-list.json',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode >= 400) {
        setState(() {
          _error = 'Failed to fetch data. Please try again later.';
        });
        return;
      }

      if (response.body == 'null') {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      if (response.body == 'null') {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> listData = jsonDecode(response.body);
      final List<GroceryItem> loadItems = [];

      for (final item in listData.entries) {
        final category = categories.entries
            .firstWhere(
              (catItem) => catItem.value.title == item.value['category'],
            )
            .value;

        loadItems.add(
          GroceryItem(
            id: item.key,
            name: item.value['name'],
            quantity: item.value['quantity'],
            category: category,
          ),
        );
      }

      setState(() {
        _groceryItems = loadItems;
        _isLoading = false;
      });
    } catch (err) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  void _addItem() async {
    final newItem = await Navigator.of(
      context,
    ).push<GroceryItem>(MaterialPageRoute(builder: (ctx) => const NewItem()));

    if (newItem == null) return;

    setState(() {
      _groceryItems.add(newItem);
    });
  }

  void _removeItem(GroceryItem item) {
    final index = _groceryItems.indexOf(item);

    setState(() {
      _groceryItems.removeAt(index); // 👈 Remove temporarily
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} removed'),
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _groceryItems.insert(index, item); // 👈 Re-insert if undone
            });
          },
        ),
      ),
    );

    // 👇 Delay deletion from server
    Future.delayed(const Duration(seconds: 3)).then((_) async {
      if (!_groceryItems.contains(item)) {
        final url = Uri.https(
          'flutter-prep-40209-default-rtdb.firebaseio.com',
          'shopping-list/${item.id}.json',
        );
        final response = await http.delete(url);
        if (response.statusCode >= 400) {
          // Reinsert item if deletion failed
          setState(() {
            _groceryItems.insert(index, item);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete item from server')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent;

    if (_error != null) {
      mainContent = Center(child: Text(_error!));
    } else if (_isLoading) {
      mainContent = const Center(child: CircularProgressIndicator());
    } else if (_groceryItems.isEmpty) {
      mainContent = const Center(child: Text('No items found. Add new item!'));
    } else {
      mainContent = ListView.builder(
        itemCount: _groceryItems.length,
        itemBuilder: (context, index) {
          final groceryItem = _groceryItems[index];
          return Dismissible(
            background: Container(color: Colors.redAccent),
            key: ValueKey(groceryItem.id),
            onDismissed: (direction) => _removeItem(groceryItem),
            child: ListTile(
              leading: Container(
                width: 10,
                height: 10,
                color: groceryItem.category.color,
              ),
              title: Text(groceryItem.name),
              trailing: Text(groceryItem.quantity.toString()),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groceries'),
        actions: [IconButton(onPressed: _addItem, icon: const Icon(Icons.add))],
      ),
      body: mainContent,
    );
  }
}
