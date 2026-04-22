import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../services/music_service.dart';

class MusicScreen extends StatelessWidget {
  const MusicScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('सङ्गीत (Music)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE3F2FD), Color(0xFFF5F7FA), Color(0xFFE8EAF6)],
              ),
            ),
          ),
          SafeArea(
            child: Consumer<MusicService>(
              builder: (context, musicService, child) {
                final songs = musicService.songs;
                
                return Column(
                  children: [
                    Expanded(
                      child: songs.isEmpty
                          ? Center(
                              child: Text(
                                'कुनै गीत छैन\n(No music added)',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 120),
                              itemCount: songs.length,
                              itemBuilder: (context, index) {
                                final song = songs[index];
                                final isPlayingThis = musicService.currentSong?.id == song.id && musicService.isPlaying;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  color: isPlayingThis ? Colors.blue.shade50 : Colors.white,
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: isPlayingThis ? const Color(0xFF0D47A1) : Colors.blue.shade100,
                                      child: Icon(
                                        isPlayingThis ? Icons.graphic_eq : Icons.music_note_rounded,
                                        color: isPlayingThis ? Colors.white : const Color(0xFF0D47A1),
                                      ),
                                    ),
                                    title: Text(
                                      song.name,
                                      style: GoogleFonts.outfit(
                                        fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 18,
                                        color: isPlayingThis ? const Color(0xFF0D47A1) : Colors.black87,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            isPlayingThis ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                            size: 36,
                                            color: const Color(0xFF0D47A1),
                                          ),
                                          onPressed: () {
                                            if (isPlayingThis) {
                                              musicService.pause();
                                            } else {
                                              musicService.playSong(index);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => musicService.removeSong(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Now Playing Bar (Floating at bottom)
          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: Consumer<MusicService>(
              builder: (context, musicService, _) {
                if (musicService.currentSong == null) return const SizedBox.shrink();
                
                return _GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.music_note, color: Color(0xFF0D47A1)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              musicService.currentSong!.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: const Color(0xFF0D47A1),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress Bar
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: const Color(0xFF0D47A1),
                          inactiveTrackColor: Colors.blue.shade100,
                          thumbColor: const Color(0xFF0D47A1),
                        ),
                        child: Slider(
                          min: 0,
                          max: musicService.totalDuration.inSeconds.toDouble() > 0 ? musicService.totalDuration.inSeconds.toDouble() : 1,
                          value: musicService.currentPosition.inSeconds.toDouble().clamp(
                            0, musicService.totalDuration.inSeconds.toDouble() > 0 ? musicService.totalDuration.inSeconds.toDouble() : 1
                          ),
                          onChanged: (value) {
                            musicService.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, size: 36),
                            color: const Color(0xFF0D47A1),
                            onPressed: () => musicService.previous(),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              musicService.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                              size: 56,
                            ),
                            color: const Color(0xFF0D47A1),
                            onPressed: () {
                              if (musicService.isPlaying) {
                                musicService.pause();
                              } else {
                                musicService.resume();
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, size: 36),
                            color: const Color(0xFF0D47A1),
                            onPressed: () => musicService.next(),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final musicService = context.read<MusicService>();
          final result = await FilePicker.pickFiles(
            type: FileType.audio,
            allowMultiple: true,
          );
          
          if (result != null && result.files.isNotEmpty) {
            for (var file in result.files) {
              if (file.path != null) {
                // Get name without extension
                String name = p.basenameWithoutExtension(file.path!);
                await musicService.addSong(name, file.path!);
              }
            }
          }
        },
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('गीत थप्नुहोस् (Add)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
