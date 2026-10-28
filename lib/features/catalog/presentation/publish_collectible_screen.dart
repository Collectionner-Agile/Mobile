import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/image_pipeline.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/ui.dart';
import '../../communities/application/community_providers.dart';
import '../application/catalog_providers.dart';

/// Values carried over from a recognition result, so a scanned object that is
/// not in the catalogue can be registered without retyping.
class PublishPrefill {
  const PublishPrefill({this.name, this.category, this.description, this.photoPath});
  final String? name;
  final String? category;
  final String? description;
  final String? photoPath;
}

class PublishCollectibleScreen extends ConsumerStatefulWidget {
  const PublishCollectibleScreen({super.key, this.prefill});
  final PublishPrefill? prefill;

  @override
  ConsumerState<PublishCollectibleScreen> createState() => _PublishCollectibleScreenState();
}

class _PublishCollectibleScreenState extends ConsumerState<PublishCollectibleScreen> {
  static const _maxPhotos = 5;

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.prefill?.name);
  late final _description = TextEditingController(text: widget.prefill?.description);
  final _value = TextEditingController();
  late final _category = TextEditingController(text: widget.prefill?.category);
  final _year = TextEditingController();
  final _categoryFocus = FocusNode();
  int? _communityId;
  late final List<String> _photos = [?widget.prefill?.photoPath];
  bool _busy = false;
  String? _progress;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _description, _value, _category, _year]) {
      controller.dispose();
    }
    _categoryFocus.dispose();
    super.dispose();
  }

  Future<void> _addPhotos(ImageSource source) async {
    final l10n = context.l10n;
    try {
      final picker = ImageSourcePicker();
      if (source == ImageSource.gallery) {
        final picked = await picker.pickMany(limit: _maxPhotos - _photos.length);
        setState(() => _photos.addAll(picked.map((p) => p.path).take(_maxPhotos - _photos.length)));
      } else {
        final picked = await picker.pick(ImageSource.camera);
        if (picked != null) setState(() => _photos.add(picked.path));
      }
    } on PickException {
      if (mounted) {
        showToast(
          context,
          source == ImageSource.camera ? l10n.permissionCameraDenied : l10n.permissionGalleryDenied,
          error: true,
        );
      }
    } catch (error) {
      if (mounted) showToast(context, l10n.imageUnreadable, error: true);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    final catalog = ref.read(catalogRepositoryProvider);
    try {
      final created = await catalog.create(
        name: _name.text.trim(),
        description: _description.text.trim(),
        value: Validators.parseAmount(_value.text)!,
        communityId: _communityId!,
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        eraYear: int.tryParse(_year.text.trim()),
      );
      var failed = 0;
      for (var i = 0; i < _photos.length; i++) {
        if (mounted) setState(() => _progress = '${l10n.uploadingPhoto} ${l10n.photoCount(i + 1, _photos.length)}');
        try {
          final bytes = await prepareJpeg(_photos[i]);
          await catalog.uploadPhoto(created.id, bytes);
        } catch (_) {
          failed++;
        }
      }
      ref
        ..invalidate(collectiblesProvider)
        ..invalidate(myCommunitiesProvider);
      if (!mounted) return;
      showToast(context, failed == 0 ? l10n.publishSuccess : l10n.publishPhotosFailed(failed), error: failed > 0);
      context.go(Routes.collectible(created.id));
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, l10n));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final validators = Validators(l10n);
    final communities = ref.watch(communitiesProvider);
    final categories = ref.watch(catalogCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.publishTitle)),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xxl),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.publishIntro, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                    const SizedBox(height: Space.lg),
                    Text(l10n.photos, style: context.text.labelLarge),
                    const SizedBox(height: Space.xs),
                    SizedBox(
                      height: 92 + 24 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 2.0),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var i = 0; i < _photos.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: Space.xs),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(Radii.sm),
                                    child: Image.file(
                                      File(_photos[i]),
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      cacheWidth: 276,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: IconButton.filledTonal(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: l10n.delete,
                                      iconSize: 16,
                                      onPressed: _busy ? null : () => setState(() => _photos.removeAt(i)),
                                      icon: const Icon(AppIcons.x),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_photos.length < _maxPhotos) ...[
                            _AddTile(
                              icon: AppIcons.camera,
                              label: l10n.scanCamera,
                              onTap: _busy ? null : () => _addPhotos(ImageSource.camera),
                            ),
                            const SizedBox(width: Space.xs),
                            _AddTile(
                              icon: AppIcons.images,
                              label: l10n.scanGallery,
                              onTap: _busy ? null : () => _addPhotos(ImageSource.gallery),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: 150,
                      decoration: InputDecoration(labelText: l10n.fieldName, counterText: ''),
                      validator: (value) => validators.minLength(value, 3),
                    ),
                    const SizedBox(height: Space.md),
                    TextFormField(
                      controller: _description,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 2000,
                      decoration: InputDecoration(labelText: l10n.fieldDescription, alignLabelWithHint: true),
                      validator: (value) => validators.minLength(value, 10),
                    ),
                    const SizedBox(height: Space.md),
                    TextFormField(
                      controller: _value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.fieldValue,
                        helperText: l10n.fieldValueHelp,
                        prefixText: 'S/ ',
                      ),
                      validator: validators.nonNegativeAmount,
                    ),
                    const SizedBox(height: Space.md),
                    RawAutocomplete<String>(
                      textEditingController: _category,
                      focusNode: _categoryFocus,
                      optionsBuilder: (value) =>
                          categories.where((category) => category.toLowerCase().contains(value.text.toLowerCase())),
                      fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: '${l10n.fieldCategory} · ${l10n.optional}'),
                      ),
                      optionsViewBuilder: (context, onSelected, options) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 2,
                          color: brand.surfaceRaised,
                          borderRadius: BorderRadius.circular(Radii.sm),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              children: [
                                for (final option in options)
                                  ListTile(title: Text(option), onTap: () => onSelected(option)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: InputDecoration(labelText: '${l10n.fieldYear} · ${l10n.optional}'),
                      validator: validators.optionalYear,
                    ),
                    const SizedBox(height: Space.md),
                    switch (communities) {
                      AsyncValue(:final value?) when value.isEmpty => Text(
                        l10n.noCommunitiesAvailable,
                        style: context.text.bodyMedium?.copyWith(color: brand.danger),
                      ),
                      AsyncValue(:final value?) => DropdownButtonFormField<int>(
                        initialValue: _communityId,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: l10n.fieldCommunity),
                        hint: Text(l10n.chooseCommunity),
                        items: [
                          for (final community in value)
                            DropdownMenuItem(
                              value: community.id,
                              child: Text(community.name, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (value) => setState(() => _communityId = value),
                        validator: (value) => value == null ? l10n.errRequired : null,
                      ),
                      AsyncValue(:final error?) => ErrorState(
                        error: error,
                        onRetry: () => ref.invalidate(communitiesProvider),
                      ),
                      _ => const Skeleton(height: 52, radius: Radii.sm),
                    },
                    if (_error != null) ...[
                      const SizedBox(height: Space.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: brand.danger)),
                      ),
                    ],
                    const SizedBox(height: Space.xl),
                    if (_progress != null) ...[
                      Text(_progress!, style: context.text.bodySmall?.copyWith(color: brand.muted)),
                      const SizedBox(height: Space.xs),
                    ],
                    BusyButton(label: l10n.publishSubmit, icon: AppIcons.package, busy: _busy, onPressed: _submit),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return SizedBox(
      width: 92,
      child: Material(
        color: brand.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          side: BorderSide(color: brand.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.xxs),
            // The strip height already grows with text size; scaleDown covers
            // the remaining extreme combinations instead of clipping.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: brand.muted),
                  const SizedBox(height: Space.xxs),
                  Text(
                    label,
                    style: context.text.labelSmall?.copyWith(fontFamily: null, letterSpacing: 0),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
