// lib/screens/entry_detail_screen.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EntryDetailScreen extends StatefulWidget {
  final DocumentSnapshot entryDoc;

  const EntryDetailScreen({Key? key, required this.entryDoc}) : super(key: key);

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late Map<String, dynamic> data;
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _showAudio = false; // Toggle between voice and text view

  @override
  void initState() {
    super.initState();
    data = widget.entryDoc.data() as Map<String, dynamic>? ?? {};
    _initAudio();

    // Auto-select view based on content
    final audioUrl = data['audioUrl'] as String?;
    final text = (data['text'] ?? '') as String;
    _showAudio = audioUrl != null && audioUrl.isNotEmpty && text.isEmpty;
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _initAudio() {
    final audioUrl = data['audioUrl'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) return;

    _player = AudioPlayer();
    _player!.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  Future<void> _togglePlayPause() async {
    if (_player == null) return;
    final audioUrl = data['audioUrl'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) return;

    if (_isPlaying) {
      await _player!.pause();
    } else {
      await _player!.play(UrlSource(audioUrl));
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'Unknown date';
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy, HH:mm').format(dt);
  }

  Color _emotionColor(String emotion) {
    final e = emotion.toLowerCase();
    if (e.contains('happy') || e.contains('joy')) return Colors.green;
    if (e.contains('sad')) return Colors.blueGrey;
    if (e.contains('angry')) return Colors.red;
    if (e.contains('anx') || e.contains('stress')) return Colors.orange;
    return Colors.grey;
  }

  // Decide whether to show AI summary for a given entry
  bool _shouldShowSummary(String text, String summary) {
    final t = text.trim();
    final s = summary.trim();
    if (t.isEmpty || s.isEmpty) return false;
    // If the entry is very short (few words), avoid showing a short robotic summary
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (words <= 3) return false;
    // If the summary is extremely short, don't show it
    if (s.length <= 30) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = _formatDate(createdAt);

    final ai = (data['ai'] ?? {}) as Map<String, dynamic>;
    final hasAi = ai.isNotEmpty;
    final emotion = (ai['emotion'] ?? 'unknown').toString();
    final sentiment = ai['sentiment'];
    final stressScore = ai['stressScore'];
    final summary = ai['summary']?.toString() ?? '';
    final suggestions = (ai['suggestions'] as List?)?.cast<String>() ?? [];
    final audioUrl = data['audioUrl'] as String?;
    final textContent = (data['text'] ?? '') as String;

    final hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    final hasText = textContent.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Entry Details'), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header with date and emotion
            Container(
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Emotion chip (if AI analysis available)
                  if (hasAi)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _emotionColor(emotion).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _emotionColor(emotion),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _emotionIcon(emotion),
                            size: 18,
                            color: _emotionColor(emotion),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            emotion.toUpperCase(),
                            style: TextStyle(
                              color: _emotionColor(emotion),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content type selector (if both audio and text exist)
            if (hasAudio && hasText) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showAudio = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: !_showAudio
                                    ? Colors.indigo
                                    : Colors.grey[300]!,
                                width: !_showAudio ? 3 : 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.text_fields,
                                color: !_showAudio
                                    ? Colors.indigo
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Text Entry',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: !_showAudio
                                      ? Colors.indigo
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showAudio = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _showAudio
                                    ? Colors.indigo
                                    : Colors.grey[300]!,
                                width: _showAudio ? 3 : 1,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mic,
                                color: _showAudio ? Colors.indigo : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Voice Note',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _showAudio
                                      ? Colors.indigo
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show text or audio based on selection
                  if (!_showAudio && hasText) ...[
                    // Text content section
                    const Text(
                      'Your Entry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          textContent,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ] else if (_showAudio && hasAudio) ...[
                    // Audio player section
                    const Text(
                      'Voice Note',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.withOpacity(0.1),
                            Colors.blue.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.indigo, Colors.blue],
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _togglePlayPause,
                                customBorder: const CircleBorder(),
                                child: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isPlaying ? 'Playing...' : 'Tap to play',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Voice recorded on $dateStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // AI Analysis section
                  if (hasAi) ...[
                    const Text(
                      'AI Analysis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sentiment & Stress cards
                    if (sentiment != null || stressScore != null)
                      Row(
                        children: [
                          if (sentiment != null)
                            Expanded(
                              child: _buildAnalysisCard(
                                icon: Icons.sentiment_satisfied_alt,
                                label: 'Sentiment',
                                value: (sentiment as num).toStringAsFixed(2),
                                color: sentiment >= 0
                                    ? Colors.green
                                    : Colors.red,
                                hint: sentiment >= 0 ? 'Positive' : 'Negative',
                              ),
                            ),
                          if (sentiment != null && stressScore != null)
                            const SizedBox(width: 12),
                          if (stressScore != null)
                            Expanded(
                              child: _buildAnalysisCard(
                                icon: Icons.psychology,
                                label: 'Stress Level',
                                value: (stressScore as num).toStringAsFixed(1),
                                color: stressScore >= 7
                                    ? Colors.red
                                    : Colors.orange,
                                hint: '/ 10',
                              ),
                            ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Summary card
                    if (_shouldShowSummary(textContent, summary))
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb_outline,
                                      color: Colors.indigo,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Summary',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                summary,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Suggestions
                    if (suggestions.isNotEmpty)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.favorite_outline,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Well-being Tips',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: suggestions.asMap().entries.map((
                                  entry,
                                ) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${entry.key + 1}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              height: 1.4,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String hint,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  IconData _emotionIcon(String emotion) {
    final e = emotion.toLowerCase();
    if (e.contains('happy') || e.contains('joy'))
      return Icons.sentiment_very_satisfied;
    if (e.contains('sad')) return Icons.sentiment_very_dissatisfied;
    if (e.contains('angry')) return Icons.mood_bad;
    if (e.contains('anx') || e.contains('stress'))
      return Icons.sentiment_neutral;
    if (e.contains('calm') || e.contains('peaceful')) return Icons.spa;
    return Icons.sentiment_satisfied;
  }
}
