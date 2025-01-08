import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final AudioService audioService;
  final Function onDelete;

  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
    required this.audioService,
    required this.onDelete,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Add this getter to check if this specific recording is playing
  bool get isPlaying =>
      widget.audioService.isPlaying &&
      widget.audioService.currentlyPlayingPath == widget.audioPath;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    widget.audioService.player.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    widget.audioService.player.onPositionChanged.listen((position) {
      if (mounted &&
          widget.audioService.currentlyPlayingPath == widget.audioPath) {
        setState(() => _position = position);
      }
    });

    widget.audioService.player.onPlayerComplete.listen((_) {
      setState(() => _position = Duration.zero);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: textColor,
                  ),
                  onPressed: () async {
                    try {
                      if (isPlaying) {
                        await widget.audioService.stopPlaying();
                      } else {
                        await widget.audioService
                            .playRecording(widget.audioPath);
                      }
                      setState(() {});
                    } catch (e) {
                      // ...existing error handling...
                    }
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<Duration>(
                        stream: widget.audioService.player.onPositionChanged,
                        builder: (context, snapshot) {
                          final position = isPlaying
                              ? snapshot.data ?? Duration.zero
                              : Duration.zero;
                          return SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              min: 0,
                              max: _duration.inSeconds.toDouble(),
                              value: position.inSeconds.toDouble(),
                              onChanged: isPlaying
                                  ? (value) async {
                                      final position =
                                          Duration(seconds: value.toInt());
                                      await widget.audioService.player
                                          .seek(position);
                                    }
                                  : null,
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: textColor,
                                  ),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: textColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: textColor,
                  ),
                  onPressed: () => widget.onDelete(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (isPlaying) {
      widget.audioService.stopPlaying();
    }
    super.dispose();
  }
}
