import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class ShoppingListCard extends StatelessWidget {
  final List<ShoppingItem> items;
  final Function(ShoppingItem) onToggleItem;
  final VoidCallback onClear;

  const ShoppingListCard({
    super.key,
    required this.items,
    required this.onToggleItem,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title + Count + Clear Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.shopping_cart_outlined,
                          size: 18, color: Colors.indigo.shade700),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Smart Shopping List',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (items.isNotEmpty)
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 36, color: Colors.teal.shade300),
                      const SizedBox(height: 6),
                      const Text(
                        'All pantry supplies are optimal!',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const Text(
                        'Items with < 20% liquid are automatically pushed here.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Checkbox(
                      value: item.isBought,
                      activeColor: Colors.teal,
                      onChanged: (_) => onToggleItem(item),
                    ),
                    title: Text(
                      item.itemName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: item.isBought
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: item.isBought ? Colors.grey : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Triggered by: ${item.reason}',
                      style: TextStyle(
                        fontSize: 11,
                        color: item.isBought
                            ? Colors.grey
                            : Colors.deepOrange.shade700,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Text(
                        'LOW STOCK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
