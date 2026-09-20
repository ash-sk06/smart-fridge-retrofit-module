import 'package:flutter/material.dart';
import '../models/inventory_model.dart';

class ShoppingListCard extends StatelessWidget {
  final List<ShoppingItem> items;
  final Function(ShoppingItem) onToggleItem;
  final Function(ShoppingItem)? onDeleteItem;
  final VoidCallback onClear;
  final VoidCallback? onAddItem;

  const ShoppingListCard({
    super.key,
    required this.items,
    required this.onToggleItem,
    this.onDeleteItem,
    required this.onClear,
    this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title + Count + Add + Clear Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_cart_outlined,
                          size: 18, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Automated Replenishment',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                        Text(
                          '${items.where((i) => !i.isBought).length} pending items',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (onAddItem != null)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        tooltip: 'Add Custom Item',
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                        ),
                        onPressed: onAddItem,
                      ),
                    if (items.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                        tooltip: 'Clear All',
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                        ),
                        onPressed: onClear,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 36, color: Color(0xFF10B981)),
                      SizedBox(height: 8),
                      Text(
                        'All pantry supplies optimal!',
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Items dropped below threshold are automatically added here.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                    const Divider(height: 1, color: Color(0xFF1E293B)),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Checkbox(
                      value: item.isBought,
                      activeColor: const Color(0xFF10B981),
                      checkColor: Colors.black87,
                      side: const BorderSide(color: Color(0xFF475569)),
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
                        color: item.isBought
                            ? const Color(0xFF64748B)
                            : const Color(0xFFF1F5F9),
                      ),
                    ),
                    subtitle: Text(
                      'Trigger: ${item.reason}',
                      style: TextStyle(
                        fontSize: 11,
                        color: item.isBought
                            ? const Color(0xFF475569)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.isBought
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: item.isBought
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFEF4444).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            item.isBought ? 'BOUGHT' : 'LOW STOCK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: item.isBought
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        if (onDeleteItem != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            style: IconButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                            ),
                            onPressed: () => onDeleteItem!(item),
                          ),
                        ],
                      ],
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
