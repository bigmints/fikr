import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/note.dart';

/// Premium neural-network mind map with solid gradient nodes.
class TopicMindMap extends StatefulWidget {
  const TopicMindMap({super.key, required this.notes});
  final List<Note> notes;

  @override
  State<TopicMindMap> createState() => _TopicMindMapState();
}

class _TopicMindMapState extends State<TopicMindMap>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _expandCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _entry;
  late Animation<double> _expand;
  final TransformationController _transformCtrl = TransformationController();
  double _zoomScale = 1.0;

  final Set<String> _expanded = {};
  String? _lastToggled;

  @override
  void initState() {
    super.initState();
    _transformCtrl.addListener(_onTransform);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entry = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack);
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expand = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _transformCtrl.removeListener(_onTransform);
    _transformCtrl.dispose();
    _entryCtrl.dispose();
    _expandCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTransform() {
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    if ((scale - _zoomScale).abs() > 0.05) {
      setState(() => _zoomScale = scale);
    }
  }

  Map<String, List<Note>> get _groups {
    final g = <String, List<Note>>{};
    for (final n in widget.notes) {
      (g[n.bucket] ??= []).add(n);
    }
    return Map.fromEntries(
      g.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length)),
    );
  }

  void _toggle(String bucket) {
    setState(() {
      if (_expanded.contains(bucket)) {
        _expanded.remove(bucket);
        _lastToggled = null;
      } else {
        _expanded.add(bucket);
        _lastToggled = bucket;
      }
    });
    _expandCtrl.forward(from: 0);
  }

  // Rich gradient pairs for each bucket index
  static const _gradients = [
    [Color(0xFF6366F1), Color(0xFF818CF8)], // indigo
    [Color(0xFFEC4899), Color(0xFFF472B6)], // pink
    [Color(0xFF10B981), Color(0xFF34D399)], // emerald
    [Color(0xFFF59E0B), Color(0xFFFBBF24)], // amber
    [Color(0xFF3B82F6), Color(0xFF60A5FA)], // blue
    [Color(0xFFEF4444), Color(0xFFF87171)], // red
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)], // violet
    [Color(0xFF06B6D4), Color(0xFF22D3EE)], // cyan
  ];

  List<Color> _gradientFor(int index) {
    return _gradients[index % _gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = _groups;
    final buckets = groups.entries.toList();
    final n = buckets.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final shorter = min(screenW, screenH);

        const centerR = 22.0;
        final baseOrbit = (shorter * 0.30).clamp(100.0, 200.0);
        final maxNotes = buckets.fold<int>(0, (m, e) => max(m, e.value.length));
        final minNotes = buckets.fold<int>(
          maxNotes,
          (m, e) => min(m, e.value.length),
        );

        // Dynamic orbit per bucket: more notes → further out
        double orbitFor(int count) {
          if (maxNotes <= minNotes) return baseOrbit;
          final ratio = (count - minNotes) / (maxNotes - minNotes);
          return baseOrbit * (0.6 + ratio * 0.4); // 60%..100% of base
        }

        double bucketR(int count) {
          if (maxNotes <= 1) return 32.0;
          final ratio = count / maxNotes;
          return 24.0 + ratio * 18.0; // 24..42
        }

        final canvasW = screenW * 1.3;
        final canvasH = screenH * 1.3;
        final cx = canvasW / 2;
        final cy = canvasH / 2;
        final center = Offset(cx, cy);

        return InteractiveViewer(
          transformationController: _transformCtrl,
          constrained: false,
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.3,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(250),
          child: AnimatedBuilder(
            animation: Listenable.merge([_entry, _expand, _pulseCtrl]),
            builder: (context, _) {
              final t = _entry.value;
              final et = _expand.value;
              final pulse = _pulseCtrl.value;

              final bPos = <String, Offset>{};
              final bRad = <String, double>{};
              final lPos = <String, List<Offset>>{};

              for (int i = 0; i < n; i++) {
                // Slight organic offset per bucket
                final angleOffset = (i.isEven ? 0.08 : -0.05);
                final angle = (2 * pi * i / n) - pi / 2 + angleOffset;
                final r = bucketR(buckets[i].value.length);
                bRad[buckets[i].key] = r;
                final orbit = orbitFor(buckets[i].value.length);

                bPos[buckets[i].key] = Offset(
                  cx + orbit * cos(angle) * t,
                  cy + orbit * sin(angle) * t,
                );

                if (_expanded.contains(buckets[i].key)) {
                  final notes = buckets[i].value;
                  final lc = min(notes.length, 10);
                  final leafOrbit = r + 14.0 + lc * 5.0;
                  final expandT = _lastToggled == buckets[i].key ? et : 1.0;
                  final arc = min(pi * 1.5, lc * 0.45);
                  final startA = angle - arc / 2;

                  final positions = <Offset>[];
                  for (int j = 0; j < lc; j++) {
                    final la = lc == 1 ? angle : startA + arc * j / (lc - 1);
                    positions.add(
                      Offset(
                        bPos[buckets[i].key]!.dx +
                            leafOrbit * cos(la) * expandT,
                        bPos[buckets[i].key]!.dy +
                            leafOrbit * sin(la) * expandT,
                      ),
                    );
                  }
                  lPos[buckets[i].key] = positions;
                }
              }

              return SizedBox(
                width: canvasW,
                height: canvasH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Ambient dots
                    CustomPaint(
                      size: Size(canvasW, canvasH),
                      painter: _AmbientPainter(isDark: isDark, seed: n),
                    ),

                    // Connection lines
                    CustomPaint(
                      size: Size(canvasW, canvasH),
                      painter: _LinePainter(
                        center: center,
                        bucketPos: bPos,
                        leafPos: lPos,
                        bucketIndices: {
                          for (int i = 0; i < n; i++) buckets[i].key: i,
                        },
                        gradients: _gradients,
                        isDark: isDark,
                      ),
                    ),

                    // Center glow ring
                    Positioned(
                      left: cx - centerR - 8 - pulse * 4,
                      top: cy - centerR - 8 - pulse * 4,
                      child: Container(
                        width: (centerR + 8 + pulse * 4) * 2,
                        height: (centerR + 8 + pulse * 4) * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFF14B8A6,
                            ).withValues(alpha: 0.08 + pulse * 0.06),
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                    // Center node with logo
                    Positioned(
                      left: cx - centerR,
                      top: cy - centerR,
                      child: Container(
                        width: centerR * 2,
                        height: centerR * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF14B8A6,
                              ).withValues(alpha: 0.3 + pulse * 0.15),
                              blurRadius: 20 + pulse * 10,
                              spreadRadius: 4 + pulse * 3,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            isDark
                                ? 'assets/images/fikr-logo-dark.png'
                                : 'assets/images/fikr-logo-light.png',
                            width: centerR * 2,
                            height: centerR * 2,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    // Bucket nodes
                    for (int i = 0; i < n; i++) ...[
                      _BucketBubble(
                        pos: bPos[buckets[i].key]!,
                        radius: bRad[buckets[i].key]!,
                        label: buckets[i].key,
                        count: buckets[i].value.length,
                        gradient: _gradientFor(i),
                        isExpanded: _expanded.contains(buckets[i].key),
                        isDark: isDark,
                        zoomScale: _zoomScale,
                        onTap: () => _toggle(buckets[i].key),
                      ),
                      if (lPos.containsKey(buckets[i].key))
                        for (int j = 0; j < lPos[buckets[i].key]!.length; j++)
                          _LeafBubble(
                            pos: lPos[buckets[i].key]![j],
                            title: buckets[i].value[j].title,
                            gradient: _gradientFor(i),
                            isDark: isDark,
                            zoomScale: _zoomScale,
                            progress: _lastToggled == buckets[i].key ? et : 1.0,
                          ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Bucket Bubble ────────────────────────────────────────

class _BucketBubble extends StatelessWidget {
  const _BucketBubble({
    required this.pos,
    required this.radius,
    required this.label,
    required this.count,
    required this.gradient,
    required this.isExpanded,
    required this.isDark,
    required this.zoomScale,
    required this.onTap,
  });

  final Offset pos;
  final double radius;
  final String label;
  final int count;
  final List<Color> gradient;
  final bool isExpanded;
  final bool isDark;
  final double zoomScale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zoomed = zoomScale > 1.5;
    final displayLabel = zoomed
        ? label
        : (label.length > 10 ? '${label.substring(0, 9)}…' : label);

    return Positioned(
      left: pos.dx - radius,
      top: pos.dy - radius,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                gradient[0].withValues(alpha: isExpanded ? 0.9 : 0.7),
                gradient[1].withValues(alpha: isExpanded ? 0.75 : 0.55),
              ],
              stops: const [0.3, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withValues(alpha: isExpanded ? 0.35 : 0.15),
                blurRadius: isExpanded ? 16 : 8,
                spreadRadius: isExpanded ? 3 : 1,
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: zoomed ? 7 : 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
                      shadows: const [
                        Shadow(color: Colors.black38, blurRadius: 3),
                      ],
                    ),
                    maxLines: zoomed ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    zoomed ? '$count notes' : '$count',
                    style: TextStyle(
                      fontSize: zoomed ? 6 : 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
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

// ── Leaf Bubble ──────────────────────────────────────────

class _LeafBubble extends StatelessWidget {
  const _LeafBubble({
    required this.pos,
    required this.title,
    required this.gradient,
    required this.isDark,
    required this.zoomScale,
    required this.progress,
  });

  final Offset pos;
  final String title;
  final List<Color> gradient;
  final bool isDark;
  final double zoomScale;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final zoomed = zoomScale > 1.5;

    // Show more of the title when zoomed
    final label = title.isNotEmpty
        ? (zoomed
              ? (title.length > 30 ? '${title.substring(0, 28)}…' : title)
              : (title.length > 14 ? '${title.substring(0, 12)}…' : title))
        : 'Untitled';

    // Scale node slightly when zoomed for readability
    final r = zoomed ? 26.0 : 22.0;

    return Positioned(
      left: pos.dx - r,
      top: pos.dy - r,
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: progress.clamp(0.0, 1.0),
          child: Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  gradient[0].withValues(alpha: 0.45),
                  gradient[1].withValues(alpha: 0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withValues(alpha: 0.12),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: zoomed ? 6 : 7.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.15,
                    shadows: const [
                      Shadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                  maxLines: zoomed ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Connection Lines ─────────────────────────────────────

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.center,
    required this.bucketPos,
    required this.leafPos,
    required this.bucketIndices,
    required this.gradients,
    required this.isDark,
  });

  final Offset center;
  final Map<String, Offset> bucketPos;
  final Map<String, List<Offset>> leafPos;
  final Map<String, int> bucketIndices;
  final List<List<Color>> gradients;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in bucketPos.entries) {
      final idx = bucketIndices[entry.key] ?? 0;
      final colors = gradients[idx % gradients.length];

      // Center → Bucket: gradient stroke
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.25 : 0.15),
            colors[0].withValues(alpha: isDark ? 0.3 : 0.2),
          ],
        ).createShader(Rect.fromPoints(center, entry.value))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Slight curve
      final dx = entry.value.dx - center.dx;
      final dy = entry.value.dy - center.dy;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      final curve = len * 0.06;
      final px = -dy / len * curve;
      final py = dx / len * curve;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          (center.dx + entry.value.dx) / 2 + px,
          (center.dy + entry.value.dy) / 2 + py,
          entry.value.dx,
          entry.value.dy,
        );
      canvas.drawPath(path, paint);

      // Bucket → Leaf lines
      if (leafPos.containsKey(entry.key)) {
        for (final lp in leafPos[entry.key]!) {
          final lPaint = Paint()
            ..color = colors[0].withValues(alpha: isDark ? 0.12 : 0.08)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke;
          canvas.drawLine(entry.value, lp, lPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

// ── Ambient background dots ──────────────────────────────

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.isDark, required this.seed});
  final bool isDark;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42 + seed);
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 2 + 0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) => false;
}
