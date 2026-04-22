import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../app_theme.dart';
import '../services/location_service.dart';
import '../services/cloud_classifier.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initialized = false;
  bool _permissionDenied = false;
  bool _capturing = false;

  double _pitch = 0;
  double _bearing = 0;

  final _previewKey = GlobalKey();
  Uint8List? _frozenFrame;

  StreamSubscription<double>? _pitchSub;
  StreamSubscription<double>? _bearingSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final granted = await LocationService.instance.requestPermissions();
    if (!granted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();

    CloudClassifier.instance.warmUp();

    _pitchSub = LocationService.instance.pitchStream
        .listen((p) { if (mounted) setState(() => _pitch = p); });
    _bearingSub = LocationService.instance.bearingStream
        .listen((b) { if (mounted) setState(() => _bearing = b); });

    if (mounted) setState(() => _initialized = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pitchSub?.cancel();
      _bearingSub?.cancel();
      _controller?.dispose();
      _controller = null;
      if (mounted) setState(() => _initialized = false);
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pitchSub?.cancel();
    _bearingSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onCapture() async {
    if (_capturing || _controller == null) return;
    setState(() => _capturing = true);
    _capturePreviewFrame();

    try {
      final snapshotFuture = LocationService.instance.captureSnapshot();
      final photoFuture = _controller!.takePicture();
      final snapshot = await snapshotFuture;
      final photo = await photoFuture;

      if (mounted) {
        await Navigator.push(context, _slideRight(
          ResultScreen(photo: photo, location: snapshot),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _capturing = false; _frozenFrame = null; });
    }
  }

  void _capturePreviewFrame() {
    final boundary = _previewKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;
    boundary.toImage(pixelRatio: 1.0).then((image) async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (mounted && bytes != null) {
        setState(() => _frozenFrame = bytes.buffer.asUint8List());
      }
    });
  }

  PageRoute<T> _slideRight<T>(Widget page) => PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) => SlideTransition(
      position: animation.drive(
        Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) return _buildPermissionDenied();
    if (!_initialized) return _buildLoading();
    return _buildCamera();
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: CircularProgressIndicator(color: kGold, strokeWidth: 2),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography, size: 64, color: kCreamFaint),
              const SizedBox(height: 16),
              Text('Camera & location access required',
                  style: kSans(size: 18, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Grant permissions in system settings, then restart the app.',
                  style: kSans(color: kCreamDim),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _init,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: kGold,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: kGoldGlow, blurRadius: 16)
                    ],
                  ),
                  child: Text('Retry',
                      style: kSans(
                          size: 14,
                          weight: FontWeight.w800,
                          color: kBg)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCamera() {
    final lowPitch = _pitch < 5;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview or frozen frame ──────────────────────────
          _frozenFrame != null
              ? Image.memory(_frozenFrame!, fit: BoxFit.cover)
              : (_controller != null && _controller!.value.isInitialized)
                  ? RepaintBoundary(
                      key: _previewKey,
                      child: CameraPreview(_controller!),
                    )
                  : const ColoredBox(color: Colors.black),

          // ── Top gradient ────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 130,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x80000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Top bar ─────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _GpsDot(ready: !_permissionDenied),
                        const SizedBox(width: 8),
                        Text('UnderClouds',
                            style: kSans(
                                size: 18,
                                weight: FontWeight.w900,
                                letterSpacing: -0.4)),
                      ],
                    ),
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x73000000),
                        border: Border.all(color: kPillBorder, width: 1),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          size: 18, color: kCreamDim),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Floating pill HUD ────────────────────────────────────────
          Positioned(
            top: 90, left: 0, right: 0,
            child: Center(
              child: _FloatingPill(
                  pitch: _pitch, bearing: _bearing),
            ),
          ),

          // ── Low-pitch hint ───────────────────────────────────────────
          if (lowPitch && !_capturing)
            Positioned(
              top: 150, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x94000000),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: kPillBorder.withAlpha(51), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward,
                          size: 14, color: kCreamDim),
                      const SizedBox(width: 6),
                      Text('Point at clouds in the sky',
                          style: kSans(
                              size: 12,
                              color: kCreamDim,
                              weight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Compass rose ─────────────────────────────────────────────
          Positioned(
            top: 120, right: 16,
            child: _CompassRose(bearing: _bearing, size: 72),
          ),

          // ── Corner bracket guides ────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(14, 58, 14, 100),
                child: CustomPaint(painter: _BracketPainter()),
              ),
            ),
          ),

          // ── Pitch bar (right edge) ───────────────────────────────────
          Positioned(
            right: 14, top: 0, bottom: 100,
            child: Center(
              child: _PitchBar(pitch: _pitch, barHeight: 150),
            ),
          ),

          // ── Bottom gradient (decorative) ──────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0, height: 160,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xB8080E1A), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Capture button + label ────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CaptureButton(
                      onCapture: _onCapture,
                      disabled: _capturing),
                  const SizedBox(height: 7),
                  Text('TAP TO CAPTURE',
                      style: kSans(
                          size: 10,
                          color: kCreamDim,
                          weight: FontWeight.w700,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── GPS dot ────────────────────────────────────────────────────────────
class _GpsDot extends StatefulWidget {
  final bool ready;
  const _GpsDot({required this.ready});

  @override
  State<_GpsDot> createState() => _GpsDotState();
}

class _GpsDotState extends State<_GpsDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..repeat(reverse: true);

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.ready) {
      return Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x4DFFFFFF),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, _) {
        final v = Curves.easeInOut.transform(_ac.value);
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kConfGreen.withAlpha((102 + (v * 153).round()).clamp(0, 255)),
            boxShadow: [
              BoxShadow(
                color: kConfGreen.withAlpha((51 + (v * 102).round()).clamp(0, 255)),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Floating pill HUD ──────────────────────────────────────────────────
class _FloatingPill extends StatelessWidget {
  final double pitch, bearing;
  const _FloatingPill({required this.pitch, required this.bearing});

  String _cardinal(double b) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[(((b % 360) + 360) % 360 / 45).round() % 8];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
          decoration: BoxDecoration(
            color: kPill,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: kPillBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PillItem(
                label: 'Elev',
                value: '${pitch.toStringAsFixed(1)}°',
                highlight: pitch >= 5,
              ),
              Container(
                width: 1, height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: const Color(0x2EFFFFFF),
              ),
              _PillItem(
                label: 'Azm',
                value:
                    '${bearing.round().toString().padLeft(3, '0')}° ${_cardinal(bearing)}',
                highlight: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _PillItem(
      {required this.label,
      required this.value,
      required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: kSans(
                size: 8.5,
                color: kCreamDim,
                weight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 1),
        Text(value,
            style: kMono(
                size: 14,
                color: highlight ? kGold : kCreamDim,
                letterSpacing: 0.3)),
      ],
    );
  }
}

// ── Compass rose ───────────────────────────────────────────────────────
class _CompassRose extends StatelessWidget {
  final double bearing, size;
  const _CompassRose({required this.bearing, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CompassPainter(bearing: bearing),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double bearing;
  _CompassPainter({required this.bearing});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    canvas.drawCircle(c, r - 1, Paint()..color = const Color(0xAD040A14));
    canvas.drawCircle(
        c, r - 1,
        Paint()
          ..color = kPillBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    canvas.drawCircle(
        c, r - 5,
        Paint()
          ..color = const Color(0x0D6DB8F2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);

    for (int i = 0; i < 72; i++) {
      final deg = i * 5.0;
      final rad = (deg - 90) * pi / 180;
      final isMajor = deg % 90 == 0;
      final isMinor = deg % 15 == 0;
      final inner = r - (isMajor ? 11 : isMinor ? 7 : 4);
      canvas.drawLine(
        Offset(c.dx + cos(rad) * inner, c.dy + sin(rad) * inner),
        Offset(c.dx + cos(rad) * (r - 2.5), c.dy + sin(rad) * (r - 2.5)),
        Paint()
          ..color = isMajor
              ? const Color(0xBFFFDC8C)
              : isMinor
                  ? const Color(0x47F0F6FF)
                  : const Color(0x1AF0F6FF)
          ..strokeWidth = isMajor ? 1.5 : 0.8
          ..strokeCap = StrokeCap.round,
      );
    }

    const dirs = [('N', kGold, 0.0), ('E', kCreamDim, 90.0),
                  ('S', kCreamDim, 180.0), ('W', kCreamDim, 270.0)];
    for (final (label, color, deg) in dirs) {
      final rad = (deg - 90) * pi / 180;
      final pr = r - 17;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(c.dx + cos(rad) * pr - tp.width / 2,
              c.dy + sin(rad) * pr - tp.height / 2));
    }

    final nRad = (bearing - 90) * pi / 180;
    canvas.drawLine(
        c,
        Offset(c.dx + cos(nRad) * (r - 14),
            c.dy + sin(nRad) * (r - 14)),
        Paint()
          ..color = kGold
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        c,
        Offset(c.dx + cos(nRad + pi) * (r - 22),
            c.dy + sin(nRad + pi) * (r - 22)),
        Paint()
          ..color = const Color(0x33F0F6FF)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 3.5, Paint()..color = kGold);
    canvas.drawCircle(c, 1.5, Paint()..color = kBg);

    final tp2 = TextPainter(
      text: TextSpan(
          text: '${bearing.round()}°',
          style: const TextStyle(
              fontSize: 6.5,
              color: kCreamDim,
              fontFamily: 'SpaceMono')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas,
        Offset(c.dx - tp2.width / 2, size.height - tp2.height - 3.5));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.bearing != bearing;
}

// ── Pitch bar ──────────────────────────────────────────────────────────
class _PitchBar extends StatelessWidget {
  final double pitch, barHeight;
  const _PitchBar({required this.pitch, required this.barHeight});

  @override
  Widget build(BuildContext context) {
    final fillH = (pitch / 90).clamp(0.0, 1.0) * barHeight;
    final active = pitch >= 5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${pitch.toStringAsFixed(1)}°',
          style: kMono(
              size: 9,
              color: active ? kGold : kCreamDim,
              letterSpacing: 0.4),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 4, height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x12F0F6FF),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                      color: const Color(0x1AF0F6FF), width: 1),
                ),
              ),
              Positioned(
                top: barHeight / 2 - 0.5, left: -4, right: -4,
                child: Container(height: 1,
                    color: const Color(0x2EF0F6FF)),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  height: fillH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: active
                        ? LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [kGold, kGold.withAlpha(127)],
                          )
                        : null,
                    color: active ? null : const Color(0x33FFFFFF),
                    boxShadow: active
                        ? [BoxShadow(color: kGoldGlow, blurRadius: 8)]
                        : null,
                  ),
                ),
              ),
              Positioned(
                bottom: fillH - 1.5, left: -5, right: -5,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: active
                        ? kGold
                        : const Color(0x4DFFFFFF),
                    boxShadow: active
                        ? [const BoxShadow(color: kGold, blurRadius: 6)]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('Elev', style: kSans(size: 9, color: kCreamFaint)),
      ],
    );
  }
}

// ── Corner brackets ────────────────────────────────────────────────────
class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x47FFFFFF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const L = 22.0;
    final w = size.width, h = size.height;
    canvas.drawPath(
        Path()..moveTo(L, 0)..lineTo(0, 0)..lineTo(0, L), p);
    canvas.drawPath(
        Path()..moveTo(w - L, 0)..lineTo(w, 0)..lineTo(w, L), p);
    canvas.drawPath(
        Path()..moveTo(0, h - L)..lineTo(0, h)..lineTo(L, h), p);
    canvas.drawPath(
        Path()..moveTo(w - L, h)..lineTo(w, h)..lineTo(w, h - L), p);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

// ── Capture button ─────────────────────────────────────────────────────
class _CaptureButton extends StatefulWidget {
  final VoidCallback onCapture;
  final bool disabled;
  const _CaptureButton(
      {required this.onCapture, required this.disabled});

  @override
  State<_CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<_CaptureButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() { _glow.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.disabled ? null : widget.onCapture,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (_, _) {
          final v = Curves.easeInOut.transform(_glow.value);
          final ringAlpha = widget.disabled
              ? 38
              : (56 + (v * 56).round()).clamp(0, 255);
          final glowAlpha = widget.disabled
              ? 0
              : (25 + (v * 25).round()).clamp(0, 255);
          return SizedBox(
            width: 90, height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kGold.withAlpha(ringAlpha), width: 1.5),
                    boxShadow: glowAlpha > 0
                        ? [BoxShadow(
                            color: kGold.withAlpha(glowAlpha),
                            blurRadius: 16 + v * 14)]
                        : null,
                  ),
                ),
                // Button ring
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kCream.withAlpha(
                            widget.disabled ? 56 : 224),
                        width: 2.5),
                  ),
                ),
                // Icon area
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.2, -0.24),
                      colors: [
                        Color(0x1A6DB8F2),
                        Color(0x086DB8F2)
                      ],
                    ),
                  ),
                  child: Center(
                    child: widget.disabled
                        ? SizedBox(
                            width: 26, height: 26,
                            child: CircularProgressIndicator(
                              color: kCream.withAlpha(178),
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(Icons.cloud_outlined,
                            color: kCream.withAlpha(209), size: 30),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
