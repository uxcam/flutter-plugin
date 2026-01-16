
import 'package:flutter/material.dart';

import 'occlude_render_box.dart';
import 'occlusion_models.dart';
import 'occlusion_registry.dart';

export 'occlusion_models.dart' show OcclusionType;

class OccludeWrapper extends SingleChildRenderObjectWidget {

  const OccludeWrapper({
    super.key,
    required super.child,
  });

  final bool enabled = true;
  final OcclusionType type = OcclusionType.overlay;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return OccludeRenderBox(
      enabled: enabled,
      type: type,
      registry: OcclusionRegistry.instance,
    )..updateContext(context);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant OccludeRenderBox renderObject,
  ) {
    renderObject
      ..updateContext(context)
      ..enabled = enabled
      ..type = type;
  }
}
