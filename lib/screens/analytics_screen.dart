// lib/screens/analytics_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<Map<String, dynamic>> _analytics7Days;

  @override
  void initState() {
    super.initState();
    _analytics7Days = _fetch7DaysAnalytics();
  }

  double _emotionToScore(String? emotion) {
    final e = (emotion ?? '').toLowerCase();
    if (e.contains('happy') || e.contains('joy')) return 0.8;
    if (e.contains('excited')) return 0.7;
    if (e.contains('calm') || e.contains('peaceful')) return 0.5;
    if (e.contains('neutral')) return 0.0;
    if (e.contains('anxious') || e.contains('stress')) return -0.3;
    if (e.contains('sad')) return -0.6;
    if (e.contains('angry')) return -0.8;
    return 0.0;
  }

  String _getEmotionEmoji(String? emotion) {
    final e = (emotion ?? '').toLowerCase();
    if (e.contains('happy') || e.contains('joy')) return '😊';
    if (e.contains('excited')) return '🤩';
    if (e.contains('calm') || e.contains('peaceful')) return '😌';
    if (e.contains('neutral')) return '😐';
    if (e.contains('anxious') || e.contains('stress')) return '😰';
    if (e.contains('sad')) return '😢';
    if (e.contains('angry')) return '😠';
    return '😶';
  }

  Future<Map<String, dynamic>> _fetch7DaysAnalytics() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {
        'moodSpots': <FlSpot>[],
        'emotionCounts': <String, int>{},
        'dayLabels': <String>[],
        'totalEntries': 0,
        'bestDay': null,
        'worstDay': null,
        'bestScore': -2.0,
        'worstScore': 2.0,
        'frequencyInsight': 'Please sign in to view analytics',
        'aiInsight': 'Analytics require a logged-in user',
        'suggestions': [
          'Sign in to your account',
          'Start journaling',
          'View your mood insights',
        ],
        'volatilityAlert': null,
        'dayEmotions': <String, List<String>>{},
        'startDate': DateTime.now(),
        'endDate': DateTime.now(),
        'isError': true,
      };
    }

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 6));

    final snap = await FirebaseFirestore.instance
        .collection('entries')
        .where('userId', isEqualTo: uid)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day),
          ),
        )
        .get();

    snap.docs.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    // Group by day
    final dayMap = <String, List<Map<String, dynamic>>>{};
    for (var doc in snap.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      final dayKey = DateFormat('yyyy-MM-dd').format(createdAt);

      if (!dayMap.containsKey(dayKey)) {
        dayMap[dayKey] = [];
      }
      dayMap[dayKey]!.add(data);
    }

    // Calculate mood scores and emotion distribution
    final moodSpots = <FlSpot>[];
    final emotionCounts = <String, int>{};
    final dayEmotions = <String, List<String>>{};
    final dayLabels = <String>[];
    double bestScore = -2.0;
    double worstScore = 2.0;
    String? bestDay;
    String? worstDay;

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(day);
      dayLabels.add(DateFormat('EEE').format(day));
      dayEmotions[dayKey] = [];

      final entries = dayMap[dayKey] ?? [];

      if (entries.isEmpty) {
        moodSpots.add(FlSpot(i.toDouble(), 0.0));
      } else {
        double totalScore = 0;
        for (var entry in entries) {
          final ai = entry['ai'] as Map<String, dynamic>?;
          final emotion = (ai?['emotion'] ?? 'neutral').toString();
          final score = _emotionToScore(emotion);
          totalScore += score;

          emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
          dayEmotions[dayKey]!.add(emotion);
        }

        final avgScore = totalScore / entries.length;
        moodSpots.add(FlSpot(i.toDouble(), avgScore));

        if (avgScore > bestScore) {
          bestScore = avgScore;
          bestDay = dayKey;
        }
        if (avgScore < worstScore) {
          worstScore = avgScore;
          worstDay = dayKey;
        }
      }
    }

    // Calculate entry frequency insight
    final totalEntries = snap.docs.length;
    String frequencyInsight = '';
    if (totalEntries == 0) {
      frequencyInsight = 'No entries this week yet. Start journaling today!';
    } else if (totalEntries < 3) {
      frequencyInsight =
          'You created $totalEntries entry/entries this week. Try to write more for better insights!';
    } else if (totalEntries <= 5) {
      frequencyInsight =
          'Great! You created $totalEntries entries this week. Keep up the consistent journaling!';
    } else {
      frequencyInsight =
          'Excellent! You created $totalEntries entries this week. You\'re very committed to reflection!';
    }

    // Generate AI insight
    String aiInsight = _generateAIInsight(moodSpots, emotionCounts);

    // Generate suggestions
    List<String> suggestions = _generateSuggestions(moodSpots, emotionCounts);

    // Check for emotional volatility
    double volatility = _calculateVolatility(moodSpots);
    String? volatilityAlert;
    if (volatility > 1.0) {
      volatilityAlert =
          'Your mood changed significantly this week. You may be under unpredictable stress.';
    }

    return {
      'moodSpots': moodSpots,
      'emotionCounts': emotionCounts,
      'dayLabels': dayLabels,
      'totalEntries': totalEntries,
      'bestDay': bestDay,
      'worstDay': worstDay,
      'bestScore': bestScore,
      'worstScore': worstScore,
      'frequencyInsight': frequencyInsight,
      'aiInsight': aiInsight,
      'suggestions': suggestions,
      'volatilityAlert': volatilityAlert,
      'dayEmotions': dayEmotions,
      'startDate': sevenDaysAgo,
      'endDate': now,
    };
  }

  double _calculateVolatility(List<FlSpot> spots) {
    if (spots.length < 2) return 0;
    double sumDiff = 0;
    for (int i = 1; i < spots.length; i++) {
      sumDiff += (spots[i].y - spots[i - 1].y).abs();
    }
    return sumDiff / (spots.length - 1);
  }

  String _generateAIInsight(
    List<FlSpot> moodSpots,
    Map<String, int> emotionCounts,
  ) {
    if (moodSpots.isEmpty) {
      return 'No data available yet. Start journaling to get insights!';
    }

    final avgMood =
        moodSpots.fold<double>(0, (previous, spot) => previous + spot.y) /
        moodSpots.length;

    final topEmotion = emotionCounts.isEmpty
        ? 'neutral'
        : emotionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    if (avgMood > 0.4) {
      return 'This week was quite positive overall! You experienced mostly $topEmotion emotions. Keep channeling that energy!';
    } else if (avgMood > -0.2) {
      return 'This week was balanced. You had a mix of emotions, with $topEmotion being most common. Good self-awareness!';
    } else {
      return 'This week was challenging. You felt $topEmotion more often. Remember, difficult weeks pass. Be kind to yourself.';
    }
  }

  List<String> _generateSuggestions(
    List<FlSpot> moodSpots,
    Map<String, int> emotionCounts,
  ) {
    final suggestions = <String>[];

    final topEmotion = emotionCounts.isEmpty
        ? 'stress'
        : emotionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    if (topEmotion.toLowerCase().contains('stress') ||
        topEmotion.toLowerCase().contains('anxious')) {
      suggestions.add('Try a 10-minute breathing exercise to reset.');
      suggestions.add('Schedule a 15-minute walk outside.');
    } else if (topEmotion.toLowerCase().contains('sad')) {
      suggestions.add('Reach out to someone you trust.');
      suggestions.add('Do something you enjoy today.');
    } else if (topEmotion.toLowerCase().contains('happy') ||
        topEmotion.toLowerCase().contains('excited')) {
      suggestions.add('Celebrate your progress and positive vibes!');
      suggestions.add('Share your joy with others.');
    }

    if (suggestions.isEmpty) {
      suggestions.add('Reflect on what made you feel good this week.');
      suggestions.add('Practice gratitude for small wins.');
    }

    if (suggestions.length < 3) {
      suggestions.add('Continue journaling regularly for better insights.');
    }

    return suggestions.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analytics7Days,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text('Error loading analytics'),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No data available'),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final isError = (data['isError'] ?? false) as bool;

          if (isError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.amber[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign In Required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Please sign in to your account to view your mood analytics',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          final moodSpots = (data['moodSpots'] ?? []) as List<FlSpot>;
          final emotionCounts =
              (data['emotionCounts'] ?? {}) as Map<String, int>;
          final dayLabels = (data['dayLabels'] ?? []) as List<String>;
          final totalEntries = (data['totalEntries'] ?? 0) as int;
          final bestDay = data['bestDay'] as String?;
          final worstDay = data['worstDay'] as String?;
          final bestScore = (data['bestScore'] ?? -2.0) as double;
          final worstScore = (data['worstScore'] ?? 2.0) as double;
          final frequencyInsight =
              (data['frequencyInsight'] ?? 'No data') as String;
          final aiInsight =
              (data['aiInsight'] ?? 'No insights available') as String;
          final suggestions = (data['suggestions'] ?? []) as List<String>;
          final volatilityAlert = data['volatilityAlert'] as String?;
          final startDate = (data['startDate'] ?? DateTime.now()) as DateTime;
          final endDate = (data['endDate'] ?? DateTime.now()) as DateTime;

          if (totalEntries == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No moods tracked this week yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Write something to see your mood insights!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 100,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF1E293B),
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mood Overview',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '${DateFormat('MMM dd').format(startDate)} — ${DateFormat('MMM dd').format(endDate)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mood Trend Chart
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.trending_up_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mood Trend',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'How you felt this week',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 200,
                                child: LineChart(
                                  LineChartData(
                                    minY: -1,
                                    maxY: 1,
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          strokeWidth: 1,
                                        );
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          getTitlesWidget: (value, meta) {
                                            int idx = value.toInt();
                                            if (idx < 0 || idx > 6) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                dayLabels[idx],
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            if (value == -1 ||
                                                value == 0 ||
                                                value == 1) {
                                              String label = 'Negative';
                                              if (value == 0) {
                                                label = 'Neutral';
                                              }
                                              if (value == 1) {
                                                label = 'Positive';
                                              }
                                              return Text(
                                                label,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white70,
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: moodSpots,
                                        isCurved: true,
                                        color: Colors.white,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter:
                                              (spot, percent, barData, index) {
                                                return FlDotCirclePainter(
                                                  radius: 5,
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                  strokeColor: const Color(
                                                    0xFF6366F1,
                                                  ),
                                                );
                                              },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.0,
                                              ),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Emotion Distribution
                      const Text(
                        'Emotion Distribution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: emotionCounts.entries.map((entry) {
                            final emotion = entry.key;
                            final count = entry.value;
                            final total = emotionCounts.values.fold<int>(
                              0,
                              (previous, v) => previous + v,
                            );
                            final percentage = (count / total * 100).toInt();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Text(
                                    _getEmotionEmoji(emotion),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          emotion,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: count / total,
                                            minHeight: 6,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  const Color(
                                                    0xFF6366F1,
                                                  ).withValues(alpha: 0.7),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '$percentage%',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Best & Worst Day Cards
                      if (bestDay != null || worstDay != null) ...[
                        const Text(
                          'Weekly Highlights',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // >>> Responsive LayoutBuilder instead of simple Row
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 380;

                            final bestCard = bestDay == null
                                ? null
                                : _HighlightCard(
                                    startColor: Colors.green,
                                    endColor: Colors.green,
                                    borderColor: Colors.green,
                                    icon: Icons.emoji_events_rounded,
                                    iconColor: Colors.green,
                                    title: 'Best Day',
                                    dayLabel: DateFormat(
                                      'EEEE, MMM dd',
                                    ).format(DateTime.parse(bestDay)),
                                    sentimentLabel:
                                        'Sentiment: +${bestScore.toStringAsFixed(1)}',
                                  );

                            final worstCard = worstDay == null
                                ? null
                                : _HighlightCard(
                                    startColor: Colors.red,
                                    endColor: Colors.red,
                                    borderColor: Colors.red,
                                    icon: Icons.favorite_outline_rounded,
                                    iconColor: Colors.red.shade600,
                                    title: 'Challenging Day',
                                    dayLabel: DateFormat(
                                      'EEEE, MMM dd',
                                    ).format(DateTime.parse(worstDay)),
                                    sentimentLabel:
                                        'Sentiment: ${worstScore.toStringAsFixed(1)}',
                                  );

                            if (isNarrow) {
                              // Small screens – stack cards vertically
                              return Column(
                                children: [
                                  if (bestCard != null) bestCard,
                                  if (bestCard != null && worstCard != null)
                                    const SizedBox(height: 12),
                                  if (worstCard != null) worstCard,
                                ],
                              );
                            } else {
                              // Larger screens – side by side
                              return Row(
                                children: [
                                  if (bestCard != null)
                                    Expanded(child: bestCard),
                                  if (bestCard != null && worstCard != null)
                                    const SizedBox(width: 12),
                                  if (worstCard != null)
                                    Expanded(child: worstCard),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Entry Frequency
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.indigo.withValues(alpha: 0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.indigo,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                frequencyInsight,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // AI Weekly Insight
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withValues(alpha: 0.1),
                              Colors.orange.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.lightbulb_rounded,
                                color: Colors.amber,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Weekly Insight',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    aiInsight,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Volatility Alert
                      if (volatilityAlert != null) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: Colors.orange[700],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  volatilityAlert,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Personalized Suggestions
                      const Text(
                        'Suggestions for Next Week',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...suggestions.asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final suggestion = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$index',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    suggestion,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reusable card for Best / Challenging day
class _HighlightCard extends StatelessWidget {
  final Color startColor;
  final Color endColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String dayLabel;
  final String sentimentLabel;

  const _HighlightCard({
    required this.startColor,
    required this.endColor,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.dayLabel,
    required this.sentimentLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor.withValues(alpha: 0.1),
            endColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dayLabel,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            sentimentLabel,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
