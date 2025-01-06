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
      setState(() => _position = position);
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    widget.audioService.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () async {
                    if (widget.audioService.isPlaying) {
                      await widget.audioService.stopPlaying();
                    } else {
                      await widget.audioService.playRecording(widget.audioPath);
                    }
                    setState(() {});
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          min: 0,
                          max: _duration.inSeconds.toDouble(),
                          value: _position.inSeconds.toDouble(),
                          onChanged: (value) async {
                            final position = Duration(seconds: value.toInt());
                            await widget.audioService.player.seek(position);
                            setState(() => _position = position);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => widget.onDelete(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
