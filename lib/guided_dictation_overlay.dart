import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'guided_dictation_button.dart';
import 'guided_field_controls.dart';
import 'language_provider.dart';

class GuidedDictationExclusion extends StatelessWidget {
  const GuidedDictationExclusion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class GuidedDictationOverlay extends StatefulWidget {
  const GuidedDictationOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<GuidedDictationOverlay> createState() => _GuidedDictationOverlayState();
}

class _GuidedDictationOverlayState extends State<GuidedDictationOverlay> {
  final GlobalKey _childKey = GlobalKey();
  List<_FieldInput> _inputs = const [];
  bool _scanScheduled = false;
  bool _guidedModeEnabled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    _scheduleInputScan();
  }

  void _scheduleInputScan() {
    if (_scanScheduled) return;
    _scanScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanScheduled = false;
      if (!mounted) return;
      final inputs = _guidedModeEnabled
          ? _visibleInputs()
          : const <_FieldInput>[];
      setState(() => _inputs = inputs);
    });
  }

  List<_FieldInput> _visibleInputs() {
    final root = _childKey.currentContext;
    if (root == null) return const [];

    final inputs = <_FieldInput>[];
    void visit(Element element) {
      final editable = element.widget;
      if (editable is EditableText &&
          !editable.obscureText &&
          !editable.readOnly) {
        var hasInlineMicrophone = false;
        var isExcluded = false;
        RenderBox? inputBox;
        ScaffoldMessengerState? scaffoldMessenger;
        var trailingSpace = 0.0;
        var isOnCurrentRoute = true;
        element.visitAncestorElements((ancestor) {
          final ancestorWidget = ancestor.widget;
          if (ancestorWidget is GuidedDictationExclusion) {
            isExcluded = true;
          }
          if (ancestorWidget is InputDecorator && inputBox == null) {
            final decoration = ancestorWidget.decoration;
            hasInlineMicrophone =
                _containsMicrophoneControl(decoration.suffixIcon) ||
                _containsMicrophoneControl(decoration.suffix);
            if (decoration.suffixIcon != null || decoration.suffix != null) {
              trailingSpace = 48;
            }
            final renderObject = ancestor.renderObject;
            if (renderObject is RenderBox) inputBox = renderObject;
          }
          if (ancestorWidget is Offstage && ancestorWidget.offstage) {
            isOnCurrentRoute = false;
          }
          scaffoldMessenger ??= ScaffoldMessenger.maybeOf(ancestor);
          return true;
        });

        final route = ModalRoute.of(element);
        isOnCurrentRoute =
            isOnCurrentRoute && (route == null || route.isCurrent);
        final box = inputBox;
        if (!hasInlineMicrophone &&
            !isExcluded &&
            isOnCurrentRoute &&
            box != null &&
            box.attached &&
            box.hasSize) {
          inputs.add(
            _FieldInput(
              controller: editable.controller,
              renderBox: box,
              scaffoldMessenger: scaffoldMessenger,
              trailingSpace: trailingSpace,
            ),
          );
        }
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return inputs;
  }

  bool _containsMicrophoneControl(Widget? widget) {
    if (widget == null) return false;
    if (widget is GuidedFieldControls) return true;
    if (widget is Icon) {
      return const [
        Icons.mic,
        Icons.mic_none,
        Icons.mic_rounded,
        Icons.mic_none_rounded,
        Icons.keyboard_voice,
        Icons.keyboard_voice_rounded,
      ].any((icon) => icon == widget.icon);
    }
    if (widget is IconButton) return _containsMicrophoneControl(widget.icon);
    if (widget is Tooltip) return _containsMicrophoneControl(widget.child);
    if (widget is Padding) return _containsMicrophoneControl(widget.child);
    if (widget is Container) return _containsMicrophoneControl(widget.child);
    if (widget is DecoratedBox) return _containsMicrophoneControl(widget.child);
    if (widget is SizedBox) return _containsMicrophoneControl(widget.child);
    if (widget is Align) return _containsMicrophoneControl(widget.child);
    if (widget is Center) return _containsMicrophoneControl(widget.child);
    if (widget is ConstrainedBox) {
      return _containsMicrophoneControl(widget.child);
    }
    if (widget is Visibility) return _containsMicrophoneControl(widget.child);
    if (widget is Offstage) return _containsMicrophoneControl(widget.child);
    if (widget is Opacity) return _containsMicrophoneControl(widget.child);
    if (widget is Material) return _containsMicrophoneControl(widget.child);
    if (widget is Semantics) return _containsMicrophoneControl(widget.child);
    if (widget is Row ||
        widget is Column ||
        widget is Stack ||
        widget is Wrap) {
      final children = switch (widget) {
        Row(:final children) => children,
        Column(:final children) => children,
        Stack(:final children) => children,
        Wrap(:final children) => children,
        _ => const <Widget>[],
      };
      return children.any(_containsMicrophoneControl);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider?>();
    final guidedModeEnabled = language?.isGuidedModeEnabled == true;
    if (_guidedModeEnabled != guidedModeEnabled) {
      _guidedModeEnabled = guidedModeEnabled;
      _inputs = const [];
      _scheduleInputScan();
    } else if (_childKey.currentContext == null) {
      _scheduleInputScan();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        if (_guidedModeEnabled) _scheduleInputScan();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackBox = context.findRenderObject();
          if (stackBox is! RenderBox || !stackBox.hasSize) {
            return KeyedSubtree(key: _childKey, child: widget.child);
          }

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              KeyedSubtree(key: _childKey, child: widget.child),
              if (_guidedModeEnabled)
                ..._inputs.map((input) {
                  final fieldOrigin = input.renderBox.localToGlobal(
                    Offset.zero,
                  );
                  final localOrigin = stackBox.globalToLocal(fieldOrigin);
                  final x =
                      localOrigin.dx +
                      input.renderBox.size.width -
                      48 -
                      input.trailingSpace;
                  final y =
                      localOrigin.dy + (input.renderBox.size.height - 48) / 2;
                  if (y + 48 < 0 ||
                      y > constraints.maxHeight ||
                      x + 48 < 0 ||
                      x > constraints.maxWidth) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: x.clamp(
                      0.0,
                      (constraints.maxWidth - 48).clamp(0.0, double.infinity),
                    ),
                    top: y.clamp(
                      0.0,
                      (constraints.maxHeight - 48).clamp(0.0, double.infinity),
                    ),
                    child: Focus(
                      canRequestFocus: false,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: GuidedDictationButton(
                          controller: input.controller,
                          languageCode: language!.locale.languageCode,
                          showTooltip: false,
                          scaffoldMessenger: input.scaffoldMessenger,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _FieldInput {
  const _FieldInput({
    required this.controller,
    required this.renderBox,
    required this.scaffoldMessenger,
    required this.trailingSpace,
  });

  final TextEditingController controller;
  final RenderBox renderBox;
  final ScaffoldMessengerState? scaffoldMessenger;
  final double trailingSpace;
}
