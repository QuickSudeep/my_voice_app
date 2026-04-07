import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import '../services/voice_service.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({Key? key}) : super(key: key);

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    // Listen to player state
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    // Listen to playback completion
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        setState(() {
          _currentlyPlayingPath = null;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPauseRecording(String path) async {
    try {
      if (_currentlyPlayingPath == path) {
        // Pause/Resume current recording
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
      } else {
        // Play new recording
        await _audioPlayer.setFilePath(path);
        await _audioPlayer.play();
        setState(() {
          _currentlyPlayingPath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _currentlyPlayingPath = null;
      _isPlaying = false;
    });
  }

  Future<void> _deleteRecording(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Stop playback if this file is playing
      if (_currentlyPlayingPath == path) {
        await _stopPlayback();
      }

      final success = await context.read<VoiceService>().deleteRecording(path);

      if (mounted) {
        if (success) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording deleted')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete recording')),
          );
        }
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = context.read<VoiceService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
        actions: [
          if (_currentlyPlayingPath != null)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopPlayback,
              tooltip: 'Stop Playback',
            ),
        ],
      ),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: voiceService.getRecordings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final recordings = snapshot.data ?? [];

          if (recordings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_none, size: 100, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings yet',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start recording from the home screen',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: recordings.length,
            itemBuilder: (context, index) {
              final recording = recordings[index];
              final file = File(recording.path);
              final fileName = p.basename(recording.path);
              final stat = file.statSync();
              final isPlaying =
                  _currentlyPlayingPath == recording.path && _isPlaying;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPlaying ? Colors.red : Colors.blue,
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: FutureBuilder<int>(
                    future: voiceService.getFileSize(recording.path),
                    builder: (context, sizeSnapshot) {
                      final size = sizeSnapshot.data ?? 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDateTime(stat.modified)),
                          Text(_formatFileSize(size)),
                        ],
                      );
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRecording(recording.path),
                      ),
                    ],
                  ),
                  onTap: () => _playPauseRecording(recording.path),
                ),
              );
            },
          );
        },
      ),

      // Currently playing indicator
      bottomNavigationBar: _currentlyPlayingPath != null
          ? StreamBuilder<Duration>(
              stream: _audioPlayer.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;

                return StreamBuilder<Duration?>(
                  stream: _audioPlayer.durationStream,
                  builder: (context, durationSnapshot) {
                    final duration = durationSnapshot.data ?? Duration.zero;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;

                    return Container(
                      color: Colors.grey[100],
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 4,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(_isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                iconSize: 32,
                                onPressed: () =>
                                    _playPauseRecording(_currentlyPlayingPath!),
                              ),
                              IconButton(
                                icon: const Icon(Icons.stop),
                                iconSize: 32,
                                onPressed: _stopPlayback,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            )
          : null,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
