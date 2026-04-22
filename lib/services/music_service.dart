import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Song {
  final String id;
  final String name;
  final String filePath;

  Song({required this.id, required this.name, required this.filePath});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'],
        name: json['name'],
        filePath: json['filePath'],
      );
}

class MusicService extends ChangeNotifier {
  static const String _playlistKey = 'music_playlist';

  final AudioPlayer _player = AudioPlayer();
  List<Song> _songs = [];
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  int? _currentIndex;

  List<Song> get songs => _songs;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  Song? get currentSong => _currentIndex != null && _currentIndex! >= 0 && _currentIndex! < _songs.length ? _songs[_currentIndex!] : null;

  Future<void> init() async {
    // Configure audio session for music playback
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      debugPrint('MusicService: Audio session configured for music');
    } catch (e) {
      debugPrint('MusicService: Audio session config failed: $e');
    }

    await _loadPlaylist();
    _setupPlayerListeners();
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_playlistKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _songs = decoded.map((e) => Song.fromJson(e)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to load playlist: $e');
      }
    }
  }

  Future<void> _savePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_songs.map((e) => e.toJson()).toList());
    await prefs.setString(_playlistKey, jsonString);
  }

  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      notifyListeners();
      
      // Auto-play next song if completed
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });

    _player.positionStream.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _player.durationStream.listen((duration) {
      if (duration != null) {
        _totalDuration = duration;
        notifyListeners();
      }
    });
    
    _player.currentIndexStream.listen((index) {
        if (index != null && index != _currentIndex && index < _songs.length) {
            _currentIndex = index;
            notifyListeners();
        }
    });
  }

  /// Returns the permanent music storage directory
  Future<Directory> get _musicDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'SaathiMusic'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies a picked file to permanent app storage and adds it as a song
  Future<void> addSong(String name, String filePath) async {
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        debugPrint('MusicService: Source file does not exist: $filePath');
        return;
      }

      // Copy to permanent storage so it survives cache clearing
      final dir = await _musicDir;
      final ext = p.extension(filePath);
      final songId = const Uuid().v4();
      final destPath = p.join(dir.path, '$songId$ext');
      await sourceFile.copy(destPath);
      debugPrint('MusicService: Copied song to: $destPath (${await File(destPath).length()} bytes)');

      final newSong = Song(
        id: songId,
        name: name,
        filePath: destPath,
      );
      _songs.add(newSong);
      await _savePlaylist();
      notifyListeners();
    } catch (e) {
      debugPrint('MusicService: Error adding song: $e');
    }
  }

  Future<void> removeSong(int index) async {
    if (index >= 0 && index < _songs.length) {
      final song = _songs[index];
      _songs.removeAt(index);
      await _savePlaylist();
      if (_currentIndex == index) {
        await stop();
      }
      // Delete the copied file
      try {
        final file = File(song.filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> playSong(int index) async {
    if (index >= 0 && index < _songs.length) {
      _currentIndex = index;
      final song = _songs[index];
      debugPrint('MusicService: Playing "${song.name}" from: ${song.filePath}');

      try {
        // Verify file exists
        final file = File(song.filePath);
        if (!await file.exists()) {
          debugPrint('MusicService: ERROR - File not found: ${song.filePath}');
          return;
        }
        debugPrint('MusicService: File size: ${await file.length()} bytes');

        await _player.stop();
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        await session.setActive(true);
        
        // Use AudioSource.file with MediaItem for notification support
        await _player.setAudioSource(
          AudioSource.file(
            song.filePath,
            tag: MediaItem(
              id: song.id,
              title: song.name,
              artist: 'साथी (Saathi)',
            ),
          ),
        );
        
        await _player.setVolume(1.0);
        await _player.play();
        debugPrint('MusicService: play() called - volume: ${_player.volume}');
      } catch (e) {
        debugPrint('MusicService: Error playing: $e');
      }
      notifyListeners();
    }
  }

  Future<bool> playSongByName(String query) async {
    if (_songs.isEmpty) return false;
    
    // Remove common filler words and split into keywords
    final cleanQuery = query.toLowerCase()
        .replaceAll('song', '')
        .replaceAll('गीत', '')
        .replaceAll('बजाउ', '')
        .replaceAll('play', '')
        .trim();
        
    final keywords = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    int bestIndex = -1;
    
    for (int i = 0; i < _songs.length; i++) {
        final songName = _songs[i].name.toLowerCase();
        // If it contains all keywords, it's a match
        bool matchesAll = true;
        for (final kw in keywords) {
            if (!songName.contains(kw)) {
                matchesAll = false;
                break;
            }
        }
        
        if (matchesAll && keywords.isNotEmpty) {
            bestIndex = i;
            break;
        }
    }
    
    if (bestIndex != -1) {
        await playSong(bestIndex);
        return true;
    } else {
        debugPrint('Song not found matching keywords: $keywords');
        return false;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    
    final session = await AudioSession.instance;
    await session.setActive(false);
    
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> next() async {
    if (_songs.isEmpty) return;
    final nextIndex = ((_currentIndex ?? 0) + 1) % _songs.length;
    await playSong(nextIndex);
  }

  Future<void> previous() async {
    if (_songs.isEmpty) return;
    final prevIndex = ((_currentIndex ?? 0) - 1 + _songs.length) % _songs.length;
    await playSong(prevIndex);
  }
  
  Future<void> seek(Duration position) async {
      await _player.seek(position);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
