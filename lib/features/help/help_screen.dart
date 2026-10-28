import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';

typedef _Topic = ({IconData icon, String title, List<(String, String)> questions});

List<_Topic> _topics(AppLocalizations l10n) => [
  (
    icon: Icons.center_focus_weak_outlined,
    title: l10n.navScan,
    questions: [(l10n.faqScanQ1, l10n.faqScanA1), (l10n.faqScanQ2, l10n.faqScanA2)],
  ),
  (
    icon: Icons.gavel_outlined,
    title: l10n.navAuctions,
    questions: [(l10n.faqBidQ1, l10n.faqBidA1), (l10n.faqBidQ2, l10n.faqBidA2), (l10n.faqBidQ3, l10n.faqBidA3)],
  ),
  (
    icon: Icons.add_photo_alternate_outlined,
    title: l10n.quickPublish,
    questions: [(l10n.faqPublishQ1, l10n.faqPublishA1), (l10n.faqPublishQ2, l10n.faqPublishA2)],
  ),
  (
    icon: Icons.person_outline_rounded,
    title: l10n.yourAccount,
    questions: [(l10n.faqAccountQ1, l10n.faqAccountA1), (l10n.faqAccountQ2, l10n.faqAccountA2)],
  ),
];

/// Help centre: a search over plain questions grouped by topic, each opening
/// in place, and a way to the step-by-step guides.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final needle = _query.trim().toLowerCase();
    final topics = [
      for (final topic in _topics(l10n))
        (
          icon: topic.icon,
          title: topic.title,
          questions: topic.questions
              .where((q) => needle.isEmpty || '${q.$1} ${q.$2}'.toLowerCase().contains(needle))
              .toList(),
        ),
    ].where((topic) => topic.questions.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.xs,
          Space.gutter,
          Space.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.helpSubtitle, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                const SizedBox(height: Space.md),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: searchDecoration(context, l10n.helpSearch),
                ),
                const SizedBox(height: Space.lg),
                if (topics.isEmpty)
                  EmptyState(icon: Icons.help_outline_rounded, message: l10n.helpNoResults)
                else
                  for (final (index, topic) in topics.indexed) ...[
                    Reveal(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: Row(
                          children: [
                            Icon(topic.icon, size: 18, color: brand.ink),
                            const SizedBox(width: Space.xs),
                            Expanded(child: Text(topic.title, style: context.text.titleMedium)),
                          ],
                        ),
                      ),
                    ),
                    Reveal(
                      index: index,
                      child: AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, (question, answer)) in topic.questions.indexed) ...[
                              if (i > 0) Divider(height: 1, indent: Space.md, endIndent: Space.md, color: brand.line),
                              _Question(question: question, answer: answer, initiallyOpen: needle.isNotEmpty),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                  ],
                AppCard(
                  onTap: () => context.push(Routes.howItWorks),
                  color: brand.surfaceMuted,
                  child: Row(
                    children: [
                      IconBadge(Icons.lightbulb_outline_rounded, color: brand.ink, solid: true),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.howItWorksTitle, style: context.text.titleSmall),
                            Text(l10n.helpGuidesBody, style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: brand.muted, size: 20),
                    ],
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

/// A question that opens to its answer with a turning chevron.
class _Question extends StatefulWidget {
  const _Question({required this.question, required this.answer, this.initiallyOpen = false});
  final String question;
  final String answer;
  final bool initiallyOpen;

  @override
  State<_Question> createState() => _QuestionState();
}

class _QuestionState extends State<_Question> {
  late bool _open = widget.initiallyOpen;

  @override
  void didUpdateWidget(_Question oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyOpen != widget.initiallyOpen) _open = widget.initiallyOpen;
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Semantics(
      expanded: _open,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _open = !_open);
        },
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.question, style: context.text.titleSmall)),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: Motion.of(context, Motion.base),
                    curve: Motion.standard,
                    child: Icon(Icons.expand_more_rounded, size: 18, color: brand.muted),
                  ),
                ],
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.base),
                curve: Motion.enter,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Text(widget.answer, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
