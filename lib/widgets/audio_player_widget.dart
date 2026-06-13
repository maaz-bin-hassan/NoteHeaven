import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';

/// A self-contained audio clip player. Each widget owns its own [AudioPlayer]
/// so multiple clips no longer share state; the [AudioService] coordinates
/// single-clip playback by id.
class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final AudioService audioService;
  final int index;
  final VoidCallback onDelete;

  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
    required this.audioService,
    required this.index,
    required this.onDelete,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _player;
  late final int _id;
  final _subs = <StreamSubscription>[];

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _id = widget.audioService.nextPlayerId();
    _init();
    widget.audioService.activePlayerId.addListener(_onActiveChanged);
  }

  Future<void> _init() async {
    try {
      await _player.setSource(DeviceFileSource(widget.audioPath));
      final d = await _player.getDuration();
      if (mounted && d != null) setState(() => _duration = d);
    } catch (_) {
      // Missing/unreadable file — the player simply stays at 0:00.
    }

    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    }));
  }

  void _onActiveChanged() {
    // Another clip started — stop ourselves.
    if (widget.audioService.activePlayerId.value != _id && _isPlaying) {
      _player.pause();
    }
  }

  Future<void> _toggle() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        widget.audioService.activePlayerId.value = _id;
        await _player.resume();
      }
    } catch (_) {}
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxMs = _duration.inMilliseconds.toDouble();
    final valueMs = _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed: _toggle,
            tooltip: _isPlaying ? 'Pause' : 'Play',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs <= 0 ? 1 : maxMs,
                    value: maxMs <= 0 ? 0 : valueMs,
                    onChanged: maxMs <= 0
                        ? null
                        : (v) => _player.seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_position),
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        'Recording ${widget.index + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      Text(_fmt(_duration),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: scheme.error,
            onPressed: widget.onDelete,
            tooltip: 'Delete recording',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.audioService.activePlayerId.removeListener(_onActiveChanged);
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
