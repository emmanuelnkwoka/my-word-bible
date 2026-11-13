import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';

/// Responsive layout rules shared by all screens.
abstract final class MwbLayout {
  static const double maxContentWidth = 720;
  static const double tabletBreakpoint = 600;

  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;

  static double gutter(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 40;
    if (w >= tabletBreakpoint) return 32;
    if (w < 360) return 16;
    return MwbSpace.gutter;
  }

  /// Horizontal padding that keeps content centred within [maxContentWidth].
  static EdgeInsets pagePadding(BuildContext context, {double top = 0, double bottom = 0}) {
    final w = MediaQuery.sizeOf(context).width;
    final g = gutter(context);
    final extra = w > maxContentWidth + g * 2 ? (w - maxContentWidth) / 2 : g;
    return EdgeInsets.fromLTRB(extra, top, extra, bottom);
  }

  static int gridColumns(BuildContext context, {double minTileWidth = 160}) {
    final w = MediaQuery.sizeOf(context).width.clamp(0, maxContentWidth).toDouble() - gutter(context) * 2;
    return (w / minTileWidth).floor().clamp(2, 4);
  }
}

/// Constrains content width on tablets and applies standard gutters.
class MwbConstrained extends StatelessWidget {
  const MwbConstrained({super.key, required this.child, this.padded = true});

  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    // heightFactor: 1 keeps this from expanding vertically (e.g. when used in
    // a Scaffold's bottomNavigationBar); it only centres horizontally.
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MwbLayout.maxContentWidth),
        child: padded
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: MwbLayout.gutter(context)),
                child: child,
              )
            : child,
      ),
    );
  }
}

/// Sliver equivalent of [MwbConstrained] with page gutters.
class MwbSliverPadding extends StatelessWidget {
  const MwbSliverPadding({super.key, required this.sliver, this.top = 0, this.bottom = 0});

  final Widget sliver;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: MwbLayout.pagePadding(context, top: top, bottom: bottom),
    sliver: sliver,
  );
}

/// A refined surface container: hairline border, no heavy shadow.
class MwbCard extends StatelessWidget {
  const MwbCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(MwbSpace.md),
    this.color,
    this.borderColor,
    this.radius = MwbRadius.xl,
    this.semanticLabel,
    this.elevated = true,
  });

  /// Soft warm shadow (reference card treatment). Off for nested cards.
  final bool elevated;

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? c.border),
    );
    final content = Padding(padding: padding, child: child);
    final material = Material(
      color: color ?? c.surfaceElevated,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: elevated
          ? DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: c.softShadow),
              child: material,
            )
          : material,
    );
  }
}

/// Thin gold rule used as an editorial divider.
class MwbRule extends StatelessWidget {
  const MwbRule({super.key, this.width = 28});
  final double width;

  @override
  Widget build(BuildContext context) =>
      Container(width: width, height: 1.5, color: context.mwb.colors.primary.withValues(alpha: 0.8));
}

/// Vertical spacing helper.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
