import 'package:flutter/material.dart';

import '../../../data/models/item_model.dart';

class ItemSlot extends StatelessWidget {
  final ItemType? item;
  final bool isSelected;
  final VoidCallback? onTap;

  const ItemSlot({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEmpty = item == null;

    Color borderColor;
    Color bgColor;
    if (isSelected) {
      borderColor = colorScheme.tertiary;
      bgColor = colorScheme.tertiaryContainer;
    } else if (!isEmpty) {
      borderColor = colorScheme.primary;
      bgColor = colorScheme.primaryContainer;
    } else {
      borderColor = colorScheme.outlineVariant;
      bgColor = colorScheme.surfaceContainerHighest;
    }

    return GestureDetector(
      onTap: isEmpty ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.tertiary.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Center(
          child: isEmpty
              ? Icon(Icons.add, size: 20, color: colorScheme.outlineVariant)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item!.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text(
                      item!.name,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
