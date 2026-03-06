import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/driver.dart';
import '../providers/driver_provider.dart';
import 'driver_status_badge.dart';
import 'star_rating.dart';

/// Couleurs SHTT
class SHTTColors {
  static const primary = Color(0xFF3B82F6);
  static const textDark = Color(0xFF1F2937);
  static const textGrey = Color(0xFF6B7280);
  static const background = Color(0xFFFFFFFF);
  static const backgroundGrey = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const secondary = Color(0xFF10B981);
  static const accent = Color(0xFFF97316);
  static const critical = Color(0xFFEF4444);
}

/// Barre de filtrage et recherche
class DriverFiltersBar extends ConsumerWidget {
  const DriverFiltersBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(driverFiltersProvider);
    final hasFilters = !filters.isEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 16,
      ),
      color: SHTTColors.background,
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Barre de recherche réduite sur mobile
                  _buildSearchField(ref, isMobile: true),
                  const SizedBox(width: 12),

                  // Filtre Statut
                  _buildStatusFilter(ref, filters.status),
                  const SizedBox(width: 12),

                  // Filtre Expérience
                  _buildExperienceFilter(
                    ref,
                    filters.minExperience,
                    filters.maxExperience,
                  ),
                  const SizedBox(width: 12),

                  // Filtre Notation
                  _buildRatingFilter(ref, filters.minRating),
                  const SizedBox(width: 12),

                  // Bouton réinitialiser
                  if (hasFilters) _buildResetButton(ref),
                ],
              ),
            )
          : Row(
              children: [
                // Barre de recherche
                _buildSearchField(ref, isMobile: false),
                const SizedBox(width: 12),

                // Filtre Statut
                _buildStatusFilter(ref, filters.status),
                const SizedBox(width: 12),

                // Filtre Expérience
                _buildExperienceFilter(
                  ref,
                  filters.minExperience,
                  filters.maxExperience,
                ),
                const SizedBox(width: 12),

                // Filtre Notation
                _buildRatingFilter(ref, filters.minRating),
                const SizedBox(width: 12),

                // Bouton réinitialiser
                if (hasFilters) _buildResetButton(ref),
              ],
            ),
    );
  }

  Widget _buildResetButton(WidgetRef ref) {
    return TextButton.icon(
      onPressed: () {
        ref.read(driverFiltersProvider.notifier).state = const DriverFilters();
      },
      icon: const Icon(LucideIcons.x, size: 16),
      label: const Text('Réinitialiser'),
      style: TextButton.styleFrom(
        foregroundColor: SHTTColors.textGrey,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildSearchField(WidgetRef ref, {required bool isMobile}) {
    return Container(
      width: isMobile ? 200 : 300,
      height: 40,
      decoration: BoxDecoration(
        color: SHTTColors.backgroundGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SHTTColors.border),
      ),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Rechercher un chauffeur...',
          hintStyle: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 18,
            color: SHTTColors.textGrey,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (value) {
          // Debouncing handled by provider
          Future.delayed(const Duration(milliseconds: 300), () {
            ref.read(driverFiltersProvider.notifier).state = ref
                .read(driverFiltersProvider)
                .copyWith(searchQuery: value);
          });
        },
      ),
    );
  }

  Widget _buildStatusFilter(WidgetRef ref, DriverStatus? currentStatus) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: SHTTColors.backgroundGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SHTTColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DriverStatus?>(
          value: currentStatus,
          hint: Row(
            children: [
              const Icon(
                LucideIcons.filter,
                size: 16,
                color: SHTTColors.textGrey,
              ),
              const SizedBox(width: 8),
              Text(
                'Statut',
                style: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
              ),
            ],
          ),
          icon: const Icon(Icons.arrow_drop_down, color: SHTTColors.textGrey),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Tous les statuts'),
            ),
            ...DriverStatus.values.map(
              (status) => DropdownMenuItem(
                value: status,
                child: Row(
                  children: [
                    DriverStatusBadge(status: status, size: 'small'),
                    const SizedBox(width: 8),
                    Text(status.display),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) {
            ref.read(driverFiltersProvider.notifier).state = ref
                .read(driverFiltersProvider)
                .copyWith(status: value);
          },
        ),
      ),
    );
  }

  Widget _buildExperienceFilter(WidgetRef ref, int? minExp, int? maxExp) {
    String displayText = 'Expérience';
    if (minExp != null && maxExp != null) {
      displayText = '$minExp-$maxExp ans';
    } else if (minExp != null) {
      displayText = '> $minExp ans';
    } else if (maxExp != null) {
      displayText = '< $maxExp ans';
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: SHTTColors.backgroundGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SHTTColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _getExperienceValue(minExp, maxExp),
          hint: Row(
            children: [
              const Icon(
                LucideIcons.clock,
                size: 16,
                color: SHTTColors.textGrey,
              ),
              const SizedBox(width: 8),
              Text(
                displayText,
                style: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
              ),
            ],
          ),
          icon: const Icon(Icons.arrow_drop_down, color: SHTTColors.textGrey),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Toute expérience')),
            DropdownMenuItem(value: '<1', child: Text('< 1 an')),
            DropdownMenuItem(value: '1-3', child: Text('1-3 ans')),
            DropdownMenuItem(value: '3-5', child: Text('3-5 ans')),
            DropdownMenuItem(value: '>5', child: Text('> 5 ans')),
          ],
          onChanged: (value) {
            int? min, max;
            switch (value) {
              case '<1':
                max = 0;
                break;
              case '1-3':
                min = 1;
                max = 3;
                break;
              case '3-5':
                min = 3;
                max = 5;
                break;
              case '>5':
                min = 5;
                break;
            }
            ref.read(driverFiltersProvider.notifier).state = ref
                .read(driverFiltersProvider)
                .copyWith(minExperience: min, maxExperience: max);
          },
        ),
      ),
    );
  }

  String? _getExperienceValue(int? min, int? max) {
    if (min == null && max == null) return 'all';
    if (max == 0) return '<1';
    if (min == 1 && max == 3) return '1-3';
    if (min == 3 && max == 5) return '3-5';
    if (min == 5 && max == null) return '>5';
    return 'all';
  }

  Widget _buildRatingFilter(WidgetRef ref, double? currentRating) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: SHTTColors.backgroundGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SHTTColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double?>(
          value: currentRating,
          hint: Row(
            children: [
              const Icon(
                LucideIcons.star,
                size: 16,
                color: SHTTColors.textGrey,
              ),
              const SizedBox(width: 8),
              Text(
                'Notation',
                style: TextStyle(fontSize: 14, color: SHTTColors.textGrey),
              ),
            ],
          ),
          icon: const Icon(Icons.arrow_drop_down, color: SHTTColors.textGrey),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Toutes les notations'),
            ),
            ...[5.0, 4.0, 3.0, 2.0, 1.0].map(
              (rating) => DropdownMenuItem(
                value: rating,
                child: Row(
                  children: [
                    StarRating(rating: rating, size: 16, showCount: false),
                    const SizedBox(width: 8),
                    Text('$rating+'),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) {
            ref.read(driverFiltersProvider.notifier).state = ref
                .read(driverFiltersProvider)
                .copyWith(minRating: value);
          },
        ),
      ),
    );
  }
}
