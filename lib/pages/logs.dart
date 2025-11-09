import 'package:flutter/material.dart';
import 'package:ml_espresso_app/models/weight_reading.dart';
import 'package:ml_espresso_app/services/session_storage.dart';
import 'package:ml_espresso_app/widgets/weight_chart.dart';

class LogsPage extends StatefulWidget {
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = SessionStorage().sessions;
    
    // Debug: Print session count
    print('📋 LogsPage: Displaying ${sessions.length} sessions');
    
    return Scaffold(
      body: sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.coffee,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No extraction sessions yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start recording to create your first session',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                // Sessions are stored newest-first, but we want to number them oldest-first
                final sessionNumber = sessions.length - index;
                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: Icon(Icons.analytics, color: Colors.blue),
                    title: Text(
                      'Session $sessionNumber',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${session.readings.length} readings • ${session.durationSeconds.toStringAsFixed(1)}s',
                    ),
                    trailing: Text(
                      session.startTime.toString().substring(11, 19),
                      style: TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SessionDetailPage(
                            session: session,
                            sessionNumber: sessionNumber,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
  
}

/// Full-screen page to display session details with chart
class SessionDetailPage extends StatelessWidget {
  final ExtractionSession session;
  final int sessionNumber;

  const SessionDetailPage({
    Key? key,
    required this.session,
    required this.sessionNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final weights = session.readings.map((r) => r.weight).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final avgWeight = weights.reduce((a, b) => a + b) / weights.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Session $sessionNumber'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          // Session info card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Started',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          session.startTime.toString().substring(0, 19),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${session.durationSeconds.toStringAsFixed(1)}s',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Statistics row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Readings', '${session.readings.length}', Icons.timeline),
                    _buildStatCard('Min', '${minWeight.toStringAsFixed(1)}g', Icons.arrow_downward),
                    _buildStatCard('Avg', '${avgWeight.toStringAsFixed(1)}g', Icons.analytics),
                    _buildStatCard('Max', '${maxWeight.toStringAsFixed(1)}g', Icons.arrow_upward),
                  ],
                ),
              ],
            ),
          ),
          
          // Chart section
          Expanded(
            child: Container(
              color: Colors.grey[900],
              padding: EdgeInsets.all(8),
              child: WeightChart(session: session),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
