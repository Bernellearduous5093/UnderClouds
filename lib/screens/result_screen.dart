import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../models/cloud_result.dart';
import '../models/cloud_type.dart';
import '../services/cloud_analyzer.dart';
import '../services/location_service.dart';

const _kAnalyzeSteps = [
  'Extracting image features…',
  'Matching cloud database…',
  'Calculating cloud-base altitude…',
  'Projecting ground coordinates…',
  'Retrieving landmark info…',
];

class ResultScreen extends StatefulWidget {
  final XFile photo;
  final LocationSnapshot location;

  const ResultScreen({
    super.key,
    required this.photo,
    required this.location,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  CloudResult? _result;
  String? _error;

  // Analysis step animation (independent of actual analysis timing)
  Timer? _stepTimer;
  int _stepIdx = 0;
  double _stepProgress = 0;

  // Card entrance animation
  late final AnimationController _cardAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Scan beam animation
  late final AnimationController _scanAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  // Banner ad
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _bannerAd?.dispose();
    _cardAnim.dispose();
    _scanAnim.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 520), (_) {
      if (!mounted || _result != null || _error != null) return;
      setState(() {
        _stepIdx = min(_stepIdx + 1, _kAnalyzeSteps.length - 1);
        _stepProgress = (_stepIdx / _kAnalyzeSteps.length * 85)
            .clamp(0, 85)
            .toDouble();
      });
    });

    try {
      final result = await CloudAnalyzer.instance.analyze(
        image: widget.photo,
        location: widget.location,
      );
      _stepTimer?.cancel();
      if (mounted) {
        setState(() { _result = result; _stepProgress = 100; });
        _loadBannerAd();
        Future.delayed(const Duration(milliseconds: 80),
            () { if (mounted) _cardAnim.forward(); });
      }
    } catch (e) {
      _stepTimer?.cancel();
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _bannerLoaded = true);
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSheet,
      body: _result == null && _error == null
          ? _buildAnalyzing()
          : _error != null
              ? _buildError()
              : _buildResult(),
    );
  }

  // ── Analyzing overlay ──────────────────────────────────────────────
  Widget _buildAnalyzing() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(widget.photo.path), fit: BoxFit.cover),
        // Scrim
        Container(color: const Color(0x8D080E1A)),
        // Grid
        CustomPaint(painter: _GridPainter()),
        // Scan beam
        AnimatedBuilder(
          animation: _scanAnim,
          builder: (ctx, _) {
            final h = MediaQuery.of(ctx).size.height;
            return Positioned(
              top: h * _scanAnim.value - 1.5,
              left: 0, right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      kGold.withAlpha(178),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Spinner + step
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56, height: 56,
                child: CircularProgressIndicator(
                  color: kGold,
                  strokeWidth: 2,
                  backgroundColor: kGold.withAlpha(30),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xBF080E1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGold.withAlpha(71)),
                ),
                child: Column(
                  children: [
                    Text(
                      _kAnalyzeSteps[_stepIdx],
                      style: kMono(size: 10, color: kGold,
                          letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 180, height: 3,
                      child: Stack(children: [
                        Container(
                          decoration: BoxDecoration(
                            color: kCreamFaint,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _stepProgress / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: [kGold, kGold.withAlpha(127)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: kGoldGlow, blurRadius: 8)
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Error ──────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kConfRed.withAlpha(25),
                border: Border.all(color: kConfRed.withAlpha(64)),
              ),
              child: const Icon(Icons.error_outline,
                  size: 32, color: kConfRed),
            ),
            const SizedBox(height: 16),
            Text('Analysis failed',
                style: kSans(size: 18, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                style: kSans(size: 12, color: kCreamDim),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                setState(() { _error = null; _result = null;
                  _stepIdx = 0; _stepProgress = 0; });
                _analyze();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: kGold,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: kGoldGlow, blurRadius: 16)],
                ),
                child: Text('Retry',
                    style: kSans(
                        size: 14,
                        weight: FontWeight.w800,
                        color: kBg)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Back',
                  style: kSans(size: 13, color: kCreamDim)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Result ─────────────────────────────────────────────────────────
  Widget _buildResult() {
    final r = _result!;
    final showSpatial = !r.isTooUncertain &&
        !r.cloudType.skipDistanceAndLocation &&
        r.pitchDegrees >= 5.0;

    return CustomScrollView(
      slivers: [
        // Collapsible photo header
        SliverPersistentHeader(
          pinned: true,
          delegate: _SkyHeaderDelegate(
            photo: widget.photo,
            cloudName: r.cloudType.shortName,
            abbr: r.cloudType.abbr,
            altitudeCategory: r.cloudType.skipDistanceAndLocation
                ? null
                : r.cloudType.altitudeCategory,
            altitudeColor: r.cloudType.altitudeCategoryColor,
            onBack: () => Navigator.pop(context),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                _animated(_buildCloudCard(r), 0.00),
                if (showSpatial) ...[
                  _animated(_buildDistanceCard(r), 0.10),
                  if (r.hasLocationData)
                    _animated(_buildLocationCard(r), 0.18),
                  if (r.landmark != null)
                    _animated(_buildLandmarkCard(r.landmark!), 0.26),
                ],
                if (r.isTooUncertain)
                  _animated(_buildRedPlaceholder(), 0.10),
                if (_bannerLoaded && _bannerAd != null)
                  SizedBox(
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _animated(Widget child, double start) {
    final opacity = CurvedAnimation(
      parent: _cardAnim,
      curve: Interval(start, start + 0.45, curve: Curves.easeOut),
    );
    final slide = Tween(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnim,
      curve: Interval(start, start + 0.45, curve: Curves.easeOutCubic),
    ));
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: slide, child: child),
    );
  }

  // ── Cloud type card ────────────────────────────────────────────────
  Widget _buildCloudCard(CloudResult r) {
    final confColor = r.isTooUncertain
        ? kConfRed
        : r.isLowConfidence
            ? kConfOrange
            : kConfGreen;

    return _WarmCard(
      icon: Icons.cloud_outlined,
      title: 'Cloud Type',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(r.cloudType.shortName,
                  style: kSerif(size: 22)),
              const SizedBox(width: 8),
              Text(r.cloudType.abbr,
                  style: kMono(size: 11, color: kCreamDim)),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.cloudType.description,
              style: kSans(size: 12, color: kCreamDim, height: 1.65)),
          const SizedBox(height: 10),
          // Confidence row
          Row(
            children: [
              _PulseDot(color: confColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    _ConfBar(
                        confidence: r.confidence,
                        color: confColor),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Confidence',
                            style: kSans(
                                size: 10,
                                color: kCreamDim,
                                weight: FontWeight.w700)),
                        Text(
                          '${(r.confidence * 100).toStringAsFixed(0)}%',
                          style: kMono(size: 10, color: confColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Banners
          if (r.isTooUncertain) ...[
            const SizedBox(height: 10),
            _WarningBanner(
              color: kConfRed,
              title: 'Cloud type unclear',
              body: 'Point at sky clouds and try again.',
            ),
          ] else if (r.isLowConfidence) ...[
            const SizedBox(height: 10),
            _WarningBanner(
              color: kConfOrange,
              title: null,
              body: 'Low confidence — result is approximate.',
            ),
            if (r.secondCloudType != null) ...[
              const SizedBox(height: 4),
              Text(
                'Runner-up: ${r.secondCloudType!.shortName} (${r.secondCloudType!.abbr})'
                ' ${(r.secondConfidence! * 100).toStringAsFixed(0)}%',
                style: kSans(size: 11, color: kCreamDim),
              ),
            ],
          ],
          // Skip reason
          if (r.cloudType.skipDistanceAndLocation) ...[
            const SizedBox(height: 8),
            _InfoBox(text: r.cloudType.skipReason),
          ],
          // Low pitch
          if (!r.cloudType.skipDistanceAndLocation &&
              !r.isTooUncertain &&
              r.pitchDegrees < 5.0) ...[
            const SizedBox(height: 8),
            const _InfoBox(text: 'Elevation angle too low to estimate distance and location.'),
          ],
        ],
      ),
    );
  }

  // ── Distance card ──────────────────────────────────────────────────
  Widget _buildDistanceCard(CloudResult r) {
    final hDist = r.horizontalDistanceM!;
    final sDist = r.slantDistanceM!;

    String fmt(double m) => m >= 1000
        ? '${(m / 1000).toStringAsFixed(1)} km'
        : '${m.toStringAsFixed(0)} m';

    return _WarmCard(
      icon: Icons.straighten,
      title: 'Distance',
      child: Column(
        children: [
          // Two big tiles
          Row(
            children: [
              for (final (label, value) in [
                ('Cloud base', '~${fmt(r.cloudType.altitudeMeters)}'),
                ('Horiz. dist.', fmt(hDist)),
              ])
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                        right: label == 'Cloud base' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: kGold.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: kGold.withAlpha(35), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: kSans(
                                size: 9,
                                color: kCreamDim,
                                weight: FontWeight.w700,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(value,
                            style: kMono(size: 14, color: kCream,
                                letterSpacing: -0.3)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Slant dist.', value: fmt(sDist)),
          _InfoRow(
            label: 'Elevation',
            value: '${r.pitchDegrees.toStringAsFixed(1)}°',
          ),
          _InfoRow(
            label: 'Alt. range',
            value: r.cloudType.altitudeRange,
          ),
        ],
      ),
    );
  }

  // ── Location card ──────────────────────────────────────────────────
  Widget _buildLocationCard(CloudResult r) {
    return _WarmCard(
      icon: Icons.location_on_outlined,
      title: 'Location Below',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.address != null) ...[
            Text(
              r.address!.split('·').first.trim(),
              style: kSans(size: 14, weight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(r.address!,
                style: kSans(size: 12, color: kCreamDim, height: 1.5)),
            const SizedBox(height: 10),
          ],
          _InfoRow(
            label: 'Coords',
            value:
                '${r.cloudLat!.toStringAsFixed(4)}°N, ${r.cloudLon!.toStringAsFixed(4)}°E',
          ),
          _InfoRow(
            label: 'Direction',
            value:
                '${r.bearingDegrees.toStringAsFixed(0)}° (${LocationService.bearingToCardinal(r.bearingDegrees)})',
          ),
        ],
      ),
    );
  }

  // ── Landmark card ──────────────────────────────────────────────────
  Widget _buildLandmarkCard(LandmarkResult lm) {
    return _WarmCard(
      icon: Icons.place_outlined,
      title: 'Landmark',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lm.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                lm.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Placeholder thumb when no image
              if (lm.imageUrl == null)
                Container(
                  width: 64, height: 52,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: kGold.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: kGold.withAlpha(51), width: 1),
                  ),
                  child: const Icon(Icons.account_balance_outlined,
                      color: kGold, size: 28),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lm.name,
                        style: kSans(
                            size: 14, weight: FontWeight.w800,
                            height: 1.2)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(lm.type,
                            style: kSans(
                                size: 10,
                                color: kGold,
                                weight: FontWeight.w700)),
                        if (lm.distanceMeters > 0) ...[
                          Text(' · ',
                              style: kSans(
                                  size: 10, color: kCreamFaint)),
                          Text(
                            lm.distanceMeters >= 1000
                                ? '${(lm.distanceMeters / 1000).toStringAsFixed(1)} km'
                                : '${lm.distanceMeters.toStringAsFixed(0)} m',
                            style: kSans(
                                size: 10, color: kCreamDim),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (lm.description != null) ...[
            const SizedBox(height: 8),
            Text(lm.description!,
                style: kSans(
                    size: 11, color: kCreamDim, height: 1.55)),
          ],
          if (lm.wikiUrl != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(lm.wikiUrl!),
                  mode: LaunchMode.externalApplication),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new,
                      size: 12, color: kCreamDim),
                  const SizedBox(width: 5),
                  Text('Learn more on Wikipedia',
                      style: kSans(
                          size: 11,
                          color: kCreamDim,
                          weight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Red placeholder ────────────────────────────────────────────────
  Widget _buildRedPlaceholder() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCreamFaint, width: 1.5,
            style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0x26F0F6FF), width: 1.3),
            ),
            child: const Icon(Icons.add,
                color: Color(0x26F0F6FF), size: 16),
          ),
          const SizedBox(height: 8),
          Text('Distance · Location · Landmark hidden',
              style: kSans(
                  size: 11,
                  color: const Color(0x33F0F6FF),
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

// ── Sliver header delegate ─────────────────────────────────────────────
class _SkyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final XFile photo;
  final String cloudName, abbr;
  final String? altitudeCategory;
  final Color altitudeColor;
  final VoidCallback onBack;

  const _SkyHeaderDelegate({
    required this.photo,
    required this.cloudName,
    required this.abbr,
    required this.altitudeCategory,
    required this.altitudeColor,
    required this.onBack,
  });

  @override double get minExtent => 62;
  @override double get maxExtent => 220;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final collapse =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final nameOpacity = (1 - collapse * 1.3).clamp(0.0, 1.0);
    final titleOpacity = ((collapse - 0.6) * 2.5).clamp(0.0, 1.0);
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(photo.path), fit: BoxFit.cover),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x47000000),
                Colors.transparent,
                Color(0xC0080E1A),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Back button
        Positioned(
          top: topPad + 8, left: 12,
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x7A000000),
                border: Border.all(
                    color: kPillBorder.withAlpha(56), width: 1),
              ),
              child: const Icon(Icons.arrow_back,
                  color: kCream, size: 18),
            ),
          ),
        ),
        // Cloud name overlay (fades on collapse)
        Positioned(
          bottom: 14, left: 18, right: 18,
          child: Opacity(
            opacity: nameOpacity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(cloudName,
                        style: kSerif(
                            size: 26,
                            color: kCream)),
                    const SizedBox(width: 10),
                    Text(abbr,
                        style: kMono(size: 12, color: kGold)),
                  ],
                ),
                if (altitudeCategory != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: altitudeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: altitudeColor.withAlpha(68),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: altitudeColor,
                            boxShadow: [
                              BoxShadow(
                                  color: altitudeColor.withAlpha(100),
                                  blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('$altitudeCategory cloud',
                            style: kSans(
                                size: 10,
                                color: altitudeColor,
                                weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Collapsed title
        if (titleOpacity > 0)
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: titleOpacity,
                child: Text(cloudName,
                    style: kSans(
                        size: 15, weight: FontWeight.w800)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(_SkyHeaderDelegate old) =>
      old.cloudName != cloudName || old.collapse != collapse;

  double get collapse => 0; // placeholder for shouldRebuild
}

// ── Shared card widget ─────────────────────────────────────────────────
class _WarmCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _WarmCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kGold, size: 16),
              const SizedBox(width: 7),
              Text(title,
                  style: kSans(
                      size: 12,
                      weight: FontWeight.w800,
                      color: kGold,
                      letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Info row ───────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: kSans(size: 12, color: kCreamDim,
                    weight: FontWeight.w600)),
          ),
          Expanded(
            flex: 5,
            child: Text(value,
                style: kMono(size: 12, color: kCream,
                    letterSpacing: -0.2),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ── Info box ───────────────────────────────────────────────────────────
class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kCreamFaint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: kSans(size: 11, color: kCreamDim, height: 1.5)),
    );
  }
}

// ── Warning banner ─────────────────────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  final Color color;
  final String? title;
  final String body;
  const _WarningBanner(
      {required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(64), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!,
                      style: kSans(
                          size: 12,
                          color: color,
                          weight: FontWeight.w800)),
                if (title != null) const SizedBox(height: 2),
                Text(body,
                    style: kSans(
                        size: 11,
                        color: color.withAlpha(187),
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulse dot ──────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_ac.value);
        return Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withAlpha((102 + (v * 153).round()).clamp(0, 255)),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha((51 + (v * 89).round()).clamp(0, 255)),
                blurRadius: 7,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Confidence bar ─────────────────────────────────────────────────────
class _ConfBar extends StatefulWidget {
  final double confidence;
  final Color color;
  const _ConfBar({required this.confidence, required this.color});

  @override
  State<_ConfBar> createState() => _ConfBarState();
}

class _ConfBarState extends State<_ConfBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();
  late final Animation<double> _anim = CurvedAnimation(
    parent: _ac,
    curve: const ElasticOutCurve(0.75),
  );

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0x14F0F6FF),
          borderRadius: BorderRadius.circular(3),
        ),
        clipBehavior: Clip.hardEdge,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor:
              (_anim.value * widget.confidence).clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(colors: [
                widget.color.withAlpha(135),
                widget.color,
              ]),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withAlpha(84),
                  blurRadius: 8,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Analysis grid ──────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = kGold.withAlpha(20)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 15; i++) {
      final y = i * size.height / 15;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    for (int i = 0; i <= 9; i++) {
      final x = i * size.width / 9;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
