import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/voice_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late TextEditingController _apiUrlController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _apiUrlController = TextEditingController(text: settings.fastApiUrl);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsService>();
    final voiceService = context.read<VoiceService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.restore, color: Colors.white),
            label: const Text('Reset', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Settings'),
                  content: const Text('Reset all settings to default values?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await settings.resetToDefaults();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings reset to defaults')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'General Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Auto Save Recordings'),
            subtitle: const Text('Automatically save after recording'),
            value: settings.autoSave,
            onChanged: (value) async {
              await settings.setAutoSave(value);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Show Recording Duration'),
            subtitle: const Text('Display timer while recording'),
            value: settings.showDuration,
            onChanged: (value) async {
              await settings.setShowDuration(value);
              setState(() {});
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Recording Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          ListTile(
            title: const Text('Max Recording Duration'),
            subtitle: Text('${settings.maxRecordingDuration ~/ 60} minutes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final duration = await showDialog<int>(
                context: context,
                builder: (context) => _DurationPickerDialog(
                  initialDuration: settings.maxRecordingDuration,
                ),
              );

              if (duration != null) {
                await settings.setMaxRecordingDuration(duration);
                setState(() {});
              }
            },
          ),
          ListTile(
            title: const Text('Audio Quality'),
            subtitle: Text(settings.audioQuality.toUpperCase()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final quality = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Select Audio Quality'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'low'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Low (Smaller file size)'),
                      ),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'medium'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Medium (Balanced)'),
                      ),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, 'high'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('High (Best quality)'),
                      ),
                    ),
                  ],
                ),
              );

              if (quality != null) {
                await settings.setAudioQuality(quality);
                setState(() {});
              }
            },
          ),
          SwitchListTile(
            title: const Text('Auto-Stop on Silence'),
            subtitle: const Text('Stop recording automatically when you stop speaking'),
            value: settings.autoStopOnSilence,
            onChanged: (value) async {
              await settings.setAutoStopOnSilence(value);
              setState(() {});
            },
          ),
          if (settings.autoStopOnSilence) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Silence Threshold'),
                      Text('${settings.silenceThreshold.toInt()} dB'),
                    ],
                  ),
                  Slider(
                    value: settings.silenceThreshold,
                    min: -60,
                    max: -20,
                    divisions: 40,
                    label: '${settings.silenceThreshold.toInt()} dB',
                    onChanged: (value) async {
                      await settings.setSilenceThreshold(value);
                      setState(() {});
                    },
                  ),
                  const Text(
                    'Higher value means it stops more easily (less sensitive to noise)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Silence Duration'),
                      Text('${settings.silenceDuration} seconds'),
                    ],
                  ),
                  Slider(
                    value: settings.silenceDuration.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${settings.silenceDuration}s',
                    onChanged: (value) async {
                      await settings.setSilenceDuration(value.toInt());
                      setState(() {});
                    },
                  ),
                  const Text(
                    'How long to wait before stopping automatically',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Storage',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'API Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'FastAPI Server URL',
                hintText: 'http://localhost:8000/process',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) async {
                await settings.setFastApiUrl(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Recordings'),
            subtitle: const Text('View and manage recordings'),
            leading: const Icon(Icons.folder, color: Colors.blue),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/recordings'),
          ),
          FutureBuilder<List<dynamic>>(
            future: voiceService.getRecordings(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return ListTile(
                title: const Text('Total Recordings'),
                trailing: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Clear All Recordings'),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Recordings'),
                  content: const Text(
                    'This will permanently delete all recordings. This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Delete All'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                final recordings = await voiceService.getRecordings();
                for (final recording in recordings) {
                  await voiceService.deleteRecording(recording.path);
                }

                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All recordings deleted'),
                    ),
                  );
                }
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const ListTile(
            title: Text('Version'),
            trailing: Text('1.0.0'),
          ),
          const ListTile(
            title: Text('Developer'),
            trailing: Text('Your Name'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DurationPickerDialog extends StatefulWidget {
  final int initialDuration;

  const _DurationPickerDialog({required this.initialDuration});

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late int _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.initialDuration ~/ 60;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Max Recording Duration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_selectedMinutes minutes',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _selectedMinutes.toDouble(),
            min: 1,
            max: 60,
            divisions: 59,
            label: '$_selectedMinutes min',
            onChanged: (value) {
              setState(() {
                _selectedMinutes = value.toInt();
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedMinutes * 60),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
