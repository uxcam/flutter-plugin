import 'package:flutter/widgets.dart';

import 'occlude_render_box.dart';
import 'occlusion_models.dart';
import 'occlusion_registry.dart';

export 'occlusion_models.dart' show OcclusionType;

class OccludeWrapperInternal extends SingleChildRenderObjectWidget {
  const OccludeWrapperInternal({
    super.key,
    required super.child,
    this.enabled = true,
    this.type = OcclusionType.overlay,
  });

  final bool enabled;
  final OcclusionType type;

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
