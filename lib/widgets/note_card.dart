import 'dart:io';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../theme/app_palette.dart';
import 'drawing_canvas.dart';

/// A single note tile for the home masonry grid.
class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  Color _legible(int chosen, Color bg, Color fallback) {
    if (chosen == 0xFF000000) return fallback;
    final c = Color(chosen);
    final diff = (c.computeLuminance() - bg.computeLuminance()).abs();
    return diff < 0.25 ? fallback : c;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = AppPalette.resolve(note.color, brightness);
    final onBg = AppPalette.onColor(bg);
    final titleColor = _legible(note.titleColor, bg, onBg);
    final bodyColor = _legible(note.contentColor, bg, onBg).withValues(alpha: 0.82);
    final firstImage = _firstExistingImage();

    return Hero(
      tag: 'note-${note.id}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (firstImage != null)
                _CoverImage(path: firstImage)
              else if (note.drawings.isNotEmpty)
                Container(
                  height: 96,
                  width: double.infinity,
                  color: Colors.white,
                  child: CustomPaint(painter: StrokePainter(strokes: note.drawings)),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (note.isPinned)
                          Icon(Icons.push_pin_rounded,
                              size: 15, color: onBg.withValues(alpha: 0.6)),
                      ],
                    ),
                    if (note.content.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        note.content.trim(),
                        style: TextStyle(
                            fontSize: 13, height: 1.35, color: bodyColor),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (_hasMeta) ...[
                      const SizedBox(height: 10),
                      _MetaRow(note: note, color: onBg.withValues(alpha: 0.6)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasMeta =>
      note.images.isNotEmpty ||
      note.audioRecordings.isNotEmpty ||
      note.drawings.isNotEmpty;

  String? _firstExistingImage() {
    for (final path in note.images) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }
}

class _CoverImage extends StatelessWidget {
  final String path;
  const _CoverImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 120,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Note note;
  final Color color;
  const _MetaRow({required this.note, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11, color: color);
    return Row(
      children: [
        if (note.images.isNotEmpty) ...[
          Icon(Icons.image_outlined, size: 13, color: color),
          const SizedBox(width: 3),
          Text('${note.images.length}', style: style),
          const SizedBox(width: 8),
        ],
        if (note.audioRecordings.isNotEmpty) ...[
          Icon(Icons.mic_none_rounded, size: 13, color: color),
          const SizedBox(width: 3),
          Text('${note.audioRecordings.length}', style: style),
          const SizedBox(width: 8),
        ],
        if (note.drawings.isNotEmpty)
          Icon(Icons.draw_outlined, size: 13, color: color),
      ],
    );
  }
}
