import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';

import '../providers/promotions_provider.dart';

/// Shows promotional banners that slide automatically on the home screen
/// Each banner comes from Firebase and updates in real-time
class BannerSlider extends StatelessWidget {
  const BannerSlider({super.key});

  @override
  Widget build(BuildContext context) {
    // Get active promotions from provider
    final List<dynamic> banners = context
        .watch<PromotionsProvider>()
        .activePromotions;

    // If no promotions, don't show anything
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 160,
          autoPlay: true, // Auto slide
          viewportFraction: 0.92, // 92% of screen width
          enlargeCenterPage: true, // Make middle one bigger
        ),
        // Create a banner widget for each promotion
        items: banners.map((promotion) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image.network(
                    promotion.imageUrl,
                    fit: BoxFit.cover,
                    cacheHeight: 300,
                    cacheWidth: 500,
                    errorBuilder: (context, error, stackTrace) {
                      // If image fails to load, show placeholder
                      return Container(
                        color: Colors.green.shade100,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.local_grocery_store,
                          color: Colors.green,
                          size: 40,
                        ),
                      );
                    },
                  ),
                  // Dark gradient at bottom so text is readable
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Banner text at bottom
                  Positioned(
                    left: 14,
                    bottom: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          promotion.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Description with discount
                        Text(
                          'Save ${promotion.discount}% - ${promotion.description}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
