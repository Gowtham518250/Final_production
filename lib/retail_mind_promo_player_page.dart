import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

class RetailMindPromoPlayerPage extends StatefulWidget {
  const RetailMindPromoPlayerPage({super.key});

  @override
  State<RetailMindPromoPlayerPage> createState() =>
      _RetailMindPromoPlayerPageState();
}

class _RetailMindPromoPlayerPageState extends State<RetailMindPromoPlayerPage> {
  VideoPlayerController? _controller;
  Future<void>? _initializeVideo;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startVideo() async {
    if (_controller != null) return;
    final controller = VideoPlayerController.asset(
      'assets/videos/retail_mind_promo.mp4',
    );
    setState(() {
      _controller = controller;
      _initializeVideo = controller.initialize().then((_) {
        return controller.play();
      });
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) {
      await _startVideo();
      return;
    }
    final value = controller.value;
    if (value.isPlaying) {
      await controller.pause();
      return;
    }

    if (value.position >= value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B17),
        foregroundColor: Colors.white,
        title: Text(
          'Retail Mind',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _controller == null
            ? _buildPoster()
            : FutureBuilder<void>(
                future: _initializeVideo,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load the promo video.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF818CF8),
                      ),
                    );
                  }

                  final controller = _controller;
                  if (controller == null) return _buildPoster();

                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: controller.value.aspectRatio,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                      _buildControls(),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildPoster() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/videos/retail_mind_promo_poster.jpg',
                    fit: BoxFit.cover,
                    cacheWidth: 720,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF111827)),
                  ),
                  Center(
                    child: IconButton(
                      onPressed: _startVideo,
                      iconSize: 72,
                      color: Colors.white,
                      icon: const Icon(Icons.play_circle_fill_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildControls(),
      ],
    );
  }

  Widget _buildControls() {
    final controller = _controller;
    if (controller == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Row(
          children: [
            IconButton(
              onPressed: _startVideo,
              color: Colors.white,
              iconSize: 30,
              icon: const Icon(Icons.play_circle_fill_rounded),
            ),
            Text(
              'Tap play',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final durationMs = value.duration.inMilliseconds.toDouble();
        final positionMs = value.position.inMilliseconds
            .toDouble()
            .clamp(0.0, durationMs)
            .toDouble();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: _togglePlayback,
                color: Colors.white,
                iconSize: 30,
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                ),
              ),
              Text(
                _formatDuration(value.position),
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: durationMs > 0 ? durationMs : 1,
                  value: positionMs,
                  activeColor: const Color(0xFF818CF8),
                  inactiveColor: Colors.white24,
                  onChanged: (position) => controller.seekTo(
                    Duration(milliseconds: position.round()),
                  ),
                ),
              ),
              Text(
                _formatDuration(value.duration),
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }
}
