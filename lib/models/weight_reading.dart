class WeightReading {
  final DateTime timestamp;
  final double weight;
  
  WeightReading({
    required this.timestamp,
    required this.weight,
  });
  
  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'weight': weight,
    };
  }
  
  /// Create from map for deserialization
  factory WeightReading.fromMap(Map<String, dynamic> map) {
    return WeightReading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      weight: map['weight'],
    );
  }
  
  @override
  String toString() {
    return 'WeightReading(timestamp: $timestamp, weight: $weight)';
  }
}

class ExtractionSession {
  final DateTime startTime;
  final List<WeightReading> readings;
  DateTime? endTime;
  
  ExtractionSession({
    required this.startTime,
    List<WeightReading>? readings,
    this.endTime,
  }) : readings = readings ?? [];
  
  /// Add a new reading to the session
  void addReading(double weight) {
    readings.add(WeightReading(
      timestamp: DateTime.now(),
      weight: weight,
    ));
  }
  
  /// End the session
  void endSession() {
    endTime = DateTime.now();
  }
  
  /// Get duration in seconds
  double get durationSeconds {
    if (readings.isEmpty) return 0;
    final end = endTime ?? readings.last.timestamp;
    return end.difference(startTime).inMilliseconds / 1000.0;
  }
  
  /// Get flow rate (grams per second) at any point
  List<double> getFlowRates() {
    if (readings.length < 2) return [];
    
    List<double> flowRates = [];
    for (int i = 1; i < readings.length; i++) {
      final timeDiff = readings[i].timestamp.difference(readings[i - 1].timestamp).inMilliseconds / 1000.0;
      final weightDiff = readings[i].weight - readings[i - 1].weight;
      
      if (timeDiff > 0) {
        flowRates.add(weightDiff / timeDiff);
      }
    }
    
    return flowRates;
  }
  
  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'readings': readings.map((r) => r.toMap()).toList(),
    };
  }
  
  /// Create from map for deserialization
  factory ExtractionSession.fromMap(Map<String, dynamic> map) {
    return ExtractionSession(
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['endTime']) : null,
      readings: (map['readings'] as List).map((r) => WeightReading.fromMap(r)).toList(),
    );
  }
}

