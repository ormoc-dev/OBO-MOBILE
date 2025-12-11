import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/inspection_history_service.dart';

class InspectionHistoryScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionHistoryScreen({
    super.key,
    required this.inspectionId,
  });

  @override
  State<InspectionHistoryScreen> createState() => _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState extends State<InspectionHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await InspectionHistoryService.getInspectionHistory(widget.inspectionId);
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final isLargeTablet = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection History'),
        backgroundColor: const Color.fromRGBO(8, 111, 222, 0.977),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyState(isTablet)
              : _buildHistoryList(isTablet, isLargeTablet),
    );
  }

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: isTablet ? 80 : 60,
            color: const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 16),
          Text(
            'No History Available',
            style: TextStyle(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inspection history will appear here',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(bool isTablet, bool isLargeTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final entry = _history[index];
        return _buildHistoryItem(entry, isTablet, isLargeTablet);
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> entry, bool isTablet, bool isLargeTablet) {
    final action = entry['action'] as String? ?? 'unknown';
    final timestamp = DateTime.tryParse(entry['timestamp'] ?? '') ?? DateTime.now();
    final description = entry['description'] as String? ?? '';
    final userName = entry['userName'] as String? ?? 'Unknown';
    final fieldName = entry['fieldName'] as String?;
    final oldValue = entry['oldValue'] as String?;
    final newValue = entry['newValue'] as String?;

    final actionIcon = _getActionIcon(action);
    final actionColor = _getActionColor(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    actionIcon,
                    color: actionColor,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatAction(action),
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 13,
                      color: const Color(0xFF374151),
                      height: 1.5,
                    ),
                  ),
                  if (fieldName != null || oldValue != null || newValue != null)
                    const SizedBox(height: 12),
                ],
                if (fieldName != null) ...[
                  Row(
                    children: [
                      Icon(Icons.label_outline, size: 16, color: const Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Text(
                        'Field: $fieldName',
                        style: TextStyle(
                          fontSize: isTablet ? 13 : 12,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (oldValue != null && newValue != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Previous',
                                style: TextStyle(
                                  fontSize: isTablet ? 11 : 10,
                                  color: const Color(0xFF991B1B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                oldValue,
                                style: TextStyle(
                                  fontSize: isTablet ? 13 : 12,
                                  color: const Color(0xFF7F1D1D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16, color: const Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New',
                                style: TextStyle(
                                  fontSize: isTablet ? 11 : 10,
                                  color: const Color(0xFF065F46),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                newValue,
                                style: TextStyle(
                                  fontSize: isTablet ? 13 : 12,
                                  color: const Color(0xFF064E3B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (newValue != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: const Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            newValue,
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 12,
                              color: const Color(0xFF0C4A6E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // User info
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: const Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Text(
                      'By: $userName',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        color: const Color(0xFF9CA3AF),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline;
      case 'updated':
        return Icons.edit_outlined;
      case 'status_changed':
        return Icons.swap_horiz;
      case 'synced':
        return Icons.cloud_done;
      case 'sync_failed':
        return Icons.cloud_off;
      case 'media_added':
        return Icons.photo_library;
      default:
        return Icons.info_outline;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'created':
        return const Color(0xFF10B981);
      case 'updated':
        return const Color(0xFF3B82F6);
      case 'status_changed':
        return const Color(0xFF8B5CF6);
      case 'synced':
        return const Color(0xFF10B981);
      case 'sync_failed':
        return const Color(0xFFEF4444);
      case 'media_added':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatAction(String action) {
    switch (action) {
      case 'created':
        return 'Inspection Created';
      case 'updated':
        return 'Inspection Updated';
      case 'status_changed':
        return 'Status Changed';
      case 'synced':
        return 'Synced to Server';
      case 'sync_failed':
        return 'Sync Failed';
      case 'media_added':
        return 'Media Added';
      default:
        return action.replaceAll('_', ' ').split(' ').map((word) {
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
    }
  }
}


