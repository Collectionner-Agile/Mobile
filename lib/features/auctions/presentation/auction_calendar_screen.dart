import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../application/auction_providers.dart';
import '../domain/auction_models.dart';
import 'widgets/auction_card.dart';

/// Agenda of the coming two weeks: a strip of days (a dot marks days when
/// something closes) and the auctions closing on the chosen day, by hour.
class AuctionCalendarScreen extends ConsumerStatefulWidget {
  const AuctionCalendarScreen({super.key});

  @override
  ConsumerState<AuctionCalendarScreen> createState() => _AuctionCalendarScreenState();
}

class _AuctionCalendarScreenState extends ConsumerState<AuctionCalendarScreen> {
  static const _days = 14;
  DateTime? _selected;

  static DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auctions = ref.watch(auctionsProvider);
    final locale = context.languageCode == 'en' ? 'en_US' : 'es_PE';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: AsyncSwitch(
        value: auctions,
        onRetry: () => ref.invalidate(auctionsProvider),
        data: (all) {
          final now = DateTime.now();
          final today = _day(now);
          final live = all.where((a) => a.isLive(now)).toList();
          final byDay = <DateTime, List<Auction>>{};
          for (final auction in live) {
            byDay.putIfAbsent(_day(auction.deadline!.toLocal()), () => []).add(auction);
          }
          final days = [for (var i = 0; i < _days; i++) today.add(Duration(days: i))];
          final firstBusy = days.firstWhere((day) => byDay.containsKey(day), orElse: () => today);
          final selected = _selected ?? firstBusy;
          final items = [...?byDay[selected]]..sort((a, b) => a.deadline!.compareTo(b.deadline!));
          final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

          return ListView(
            padding: EdgeInsets.only(bottom: Space.xxl + MediaQuery.paddingOf(context).bottom),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
                child: Text(
                  toBeginningOfSentenceCase(DateFormat.yMMMM(locale).format(selected)),
                  style: context.text.headlineSmall,
                ),
              ),
              SizedBox(
                height: 86 * scale,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    return _DayChip(
                      weekday: DateFormat.E(locale).format(day),
                      number: '${day.day}',
                      busy: byDay[day]?.length ?? 0,
                      today: day == today,
                      selected: day == selected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selected = day);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: Space.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: ContentWidth(
                  child: FadeSwitch(
                    child: items.isEmpty
                        ? EmptyState(
                            key: ValueKey(selected),
                            icon: AppIcons.calendarDays,
                            message: l10n.calendarEmptyDay,
                          )
                        : Column(
                            key: ValueKey(selected),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Kicker(l10n.calendarClosingThatDay(items.length)),
                              const SizedBox(height: Space.sm),
                              for (final (index, auction) in items.indexed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: Space.sm),
                                  child: Reveal(
                                    index: index,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 54,
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: Space.md),
                                            child: Text(
                                              DateFormat.Hm(locale).format(auction.deadline!.toLocal()),
                                              style: Fonts.figures(
                                                Fonts.display(context.text.titleMedium, weight: 680),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: AuctionCard(
                                            auction: auction,
                                            onTap: () => context.push(Routes.auction(auction.id)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.weekday,
    required this.number,
    required this.busy,
    required this.today,
    required this.selected,
    required this.onTap,
  });
  final String weekday;
  final String number;
  final int busy;
  final bool today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final foreground = selected ? brand.onAccent : brand.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '$weekday $number',
      excludeSemantics: true,
      child: TapScale(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.springDuration(Motion.spring)),
            curve: Motion.spring,
            width: 60,
            decoration: BoxDecoration(
              color: selected ? brand.accent : brand.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: selected ? brand.accent : (today ? brand.gold : brand.line)),
              boxShadow: selected ? brand.cardShadow : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekday.toUpperCase(),
                  maxLines: 1,
                  style: Fonts.eyebrow(context.text.labelSmall)
                      .copyWith(color: selected ? foreground.withValues(alpha: 0.8) : brand.muted, letterSpacing: 0.6),
                ),
                const SizedBox(height: 2),
                Text(
                  number,
                  style: Fonts.figures(Fonts.display(context.text.titleLarge, weight: 700)).copyWith(color: foreground),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: busy > 0 ? (selected ? brand.onAccent : brand.live) : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
