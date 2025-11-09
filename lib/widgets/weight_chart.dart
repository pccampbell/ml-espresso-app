import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ml_espresso_app/models/weight_reading.dart';

class WeightChart extends StatelessWidget {
  final ExtractionSession session;

  const WeightChart({Key? key, required this.session}) : super(key: key);
  
  /// Calculate appropriate Y-axis interval to avoid overlapping labels
  /// Aims for 4-6 labels on the Y-axis
  double _calculateYAxisInterval(double min, double max) {
    double range = max - min;
    if (range <= 0) return 1; // Prevent division by zero
    
    // Target ~5 intervals (4-6 labels)
    double roughInterval = range / 5;
    
    // Round to nice numbers
    if (roughInterval <= 1) return 1;
    if (roughInterval <= 2) return 2;
    if (roughInterval <= 5) return 5;
    if (roughInterval <= 10) return 10;
    if (roughInterval <= 20) return 20;
    if (roughInterval <= 50) return 50;
    if (roughInterval <= 100) return 100;
    return 200;
  }

  @override
  Widget build(BuildContext context) {
    if (session.readings.isEmpty) {
      return const Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Calculate time and weight data points
    final startTime = session.startTime;
    List<FlSpot> spots = session.readings.map((reading) {
      double seconds = reading.timestamp.difference(startTime).inMilliseconds / 1000.0;
      return FlSpot(seconds, reading.weight);
    }).toList();

    // Calculate chart bounds
    double minWeight = session.readings.map((r) => r.weight).reduce((a, b) => a < b ? a : b);
    double maxWeight = session.readings.map((r) => r.weight).reduce((a, b) => a > b ? a : b);
    double maxTime = session.readings.last.timestamp.difference(startTime).inMilliseconds / 1000.0;

    // Ensure there's always a range (prevent division by zero)
    if (maxWeight - minWeight < 0.1) {
      // If all values are the same, create a small range around the value
      double center = minWeight;
      minWeight = center - 5;
      maxWeight = center + 5;
    }

    // Add some padding to the bounds
    double weightPadding = (maxWeight - minWeight) * 0.1;
    if (weightPadding < 1.0) weightPadding = 1.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session info
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Readings: ${session.readings.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  'Duration: ${maxTime.toStringAsFixed(1)}s',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (session.readings.isNotEmpty)
                  Text(
                    'Latest: ${session.readings.last.weight.toStringAsFixed(1)}g',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
          
          // Chart
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: (maxWeight - minWeight) / 5, // Dynamic interval
                  verticalInterval: maxTime > 30 ? 10 : 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white10,
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.white10,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      'Time (s)',
                      style: TextStyle(color: Colors.white70),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: maxTime > 30 ? 10 : 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      'Weight (g)',
                      style: TextStyle(color: Colors.white70),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: _calculateYAxisInterval(minWeight, maxWeight),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                minX: 0,
                maxX: maxTime > 5 ? maxTime : 5,
                minY: minWeight - weightPadding,
                maxY: maxWeight + weightPadding,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length < 50, // Only show dots if not too many points
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.blue,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.2),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        return LineTooltipItem(
                          '${touchedSpot.y.toStringAsFixed(1)}g\n${touchedSpot.x.toStringAsFixed(1)}s',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

