import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/cross_platform_auth_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../models/deal.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<Deal> _allDeals = [];
  List<Deal> _filteredDeals = [];
  int _totalUsers = 0;
  int _totalDeals = 0;
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    print('AdminPanelScreen: _loadAdminData started');
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load all deals (including archived for admin)
      print('AdminPanelScreen: loading deals');
      final dealsQuery = await FirebaseService.firestore
          .collection('deals')
          .orderBy('createdAt', descending: true)
          .get();
      final deals = dealsQuery.docs
          .map((doc) => Deal.fromFirestore(doc.data(), doc.id))
          .toList();

      // Load user count (handle permission errors gracefully)
      int userCount = 0;
      try {
        final usersQuery = await FirebaseService.firestore
            .collection('users')
            .get();
        userCount = usersQuery.docs.length;
      } catch (e) {
        print('Error loading user count: $e');
        // Keep userCount as 0
      }

      setState(() {
        _allDeals = deals;
        _totalUsers = userCount;
        _totalDeals = deals.length;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading admin data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  void _applyFilter() {
    setState(() {
      if (_filterStatus == 'All') {
        _filteredDeals = _allDeals;
      } else if (_filterStatus == 'Active') {
        _filteredDeals = _allDeals
            .where((deal) => deal.isActive && !deal.isArchived)
            .toList();
      } else if (_filterStatus == 'Hot') {
        _filteredDeals = _allDeals.where((deal) => deal.isHot).toList();
      } else if (_filterStatus == 'Trending') {
        _filteredDeals = _allDeals.where((deal) => deal.isTrending).toList();
      } else if (_filterStatus == 'Archived') {
        _filteredDeals = _allDeals.where((deal) => deal.isArchived).toList();
      }
    });
  }

  // FAST TEXT PASTE DEAL UPLOAD (editfeatures.md requirement)
  Future<void> _addDealFromText() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddDealFromTextDialog(),
    );

    if (result != null) {
      try {
        final dealData = {
          'pastedText': result['pastedText'],
          'title': result['title'],
          'category': result['category'],
          'link': result['link'],
          'isActive': true,
          'isHot': result['isHot'] ?? false,
          'isTrending': result['isTrending'] ?? false,
          'isPinned': result['isPinned'] ?? false,
          'isArchived': false,
          'expiryDate': DateTime.now()
              .add(const Duration(days: 30))
              .toIso8601String(),
          'views': 0,
          'likes': 0,
          'shares': 0,
          'rankingScore': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseService.firestore.collection('deals').add(dealData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deal added from text successfully!')),
        );

        // Show local notification and send push notification if it's a hot deal
        if (result['isHot'] == true) {
          try {
            final currentUser = CrossPlatformAuthService().currentUser;
            final isAdmin = currentUser?.isAdmin ?? false;

            // Show local notification to admin
            await NotificationService().showHotDealNotification(
              result['title'],
            );

            // Send push notification to all users (FREE - FCM has no cost!)
            await PushNotificationService().sendHotDealNotification(
              result['title'],
              isAdmin,
            );
          } catch (e) {
            print('Failed to send hot deal notifications: $e');
          }
        }

        _loadAdminData(); // Refresh data
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding deal: $e')));
      }
    }
  }

  // EDIT PASTED TEXT (editfeatures.md requirement)
  Future<void> _editDealText(Deal deal) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditDealTextDialog(deal: deal),
    );

    if (result != null) {
      try {
        await FirebaseService.firestore
            .collection('deals')
            .doc(deal.id)
            .update({
              'pastedText': result['pastedText'],
              'title': result['title'],
              'category': result['category'],
              'link': result['link'],
              'updatedAt': FieldValue.serverTimestamp(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deal text updated successfully!')),
        );

        _loadAdminData(); // Refresh data
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating deal: $e')));
      }
    }
  }

  // ADMIN ACTIONS (editfeatures.md requirement)
  Future<void> _toggleHot(Deal deal) async {
    try {
      await FirebaseService.firestore.collection('deals').doc(deal.id).update({
        'isHot': !deal.isHot,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deal.isHot ? 'Removed from Hot' : 'Added to Hot'),
        ),
      );

      // Show local notification and send push notification if deal is now hot
      if (!deal.isHot) {
        try {
          final currentUser = CrossPlatformAuthService().currentUser;
          final isAdmin = currentUser?.isAdmin ?? false;

          // Show local notification to admin
          await NotificationService().showHotDealNotification(
            deal.displayTitle,
          );

          // Send push notification to all users (FREE - FCM has no cost!)
          await PushNotificationService().sendHotDealNotification(
            deal.displayTitle,
            isAdmin,
          );
        } catch (e) {
          print('Failed to send hot deal notifications: $e');
        }
      }

      _loadAdminData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating deal: $e')));
    }
  }

  Future<void> _toggleTrending(Deal deal) async {
    try {
      await FirebaseService.firestore.collection('deals').doc(deal.id).update({
        'isTrending': !deal.isTrending,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deal.isTrending ? 'Removed from Trending' : 'Added to Trending',
          ),
        ),
      );

      _loadAdminData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating deal: $e')));
    }
  }

  Future<void> _togglePinned(Deal deal) async {
    try {
      await FirebaseService.firestore.collection('deals').doc(deal.id).update({
        'isPinned': !deal.isPinned,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deal.isPinned ? 'Unpinned deal' : 'Pinned deal'),
        ),
      );

      _loadAdminData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating deal: $e')));
    }
  }

  // ARCHIVE INSTEAD OF DELETE (editfeatures.md requirement)
  Future<void> _archiveDeal(Deal deal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Deal'),
        content: Text(
          'Are you sure you want to archive "${deal.displayTitle}"?\n\nThis will hide the deal from users but keep it in the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseService.firestore
            .collection('deals')
            .doc(deal.id)
            .update({
              'isArchived': true,
              'archivedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deal archived successfully!')),
        );

        _loadAdminData();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error archiving deal: $e')));
      }
    }
  }

  Future<void> _restoreDeal(Deal deal) async {
    try {
      await FirebaseService.firestore.collection('deals').doc(deal.id).update({
        'isArchived': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deal restored successfully!')),
      );

      _loadAdminData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error restoring deal: $e')));
    }
  }

  Future<void> _deleteDeal(Deal deal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deal'),
        content: Text(
          'Are you sure you want to permanently delete "${deal.displayTitle}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseService.firestore
            .collection('deals')
            .doc(deal.id)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deal deleted successfully!')),
        );

        _loadAdminData();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting deal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      'AdminPanelScreen build: _isLoading=$_isLoading, _hasError=$_hasError',
    );
    if (_isLoading) {
      print('AdminPanelScreen: showing loading indicator');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUser = CrossPlatformAuthService().currentUser;
    print(
      'AdminPanelScreen: currentUser=$currentUser, isAdmin=${currentUser?.isAdmin}',
    );
    if (currentUser == null || !currentUser.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Access denied. Admin privileges required.')),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load admin data'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAdminData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminData,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin Welcome Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${currentUser.displayName}!',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Administrator Access Granted',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Statistics Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Users',
                            _totalUsers.toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Deals',
                            _totalDeals.toString(),
                            Icons.shopping_bag,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // FAST TEXT PASTE BUTTON (editfeatures.md requirement)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addDealFromText,
                        icon: const Icon(Icons.paste),
                        label: const Text('Add Deal from Text Paste'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Filter Dropdown
                    Row(
                      children: [
                        Text(
                          'Filter Deals:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _filterStatus,
                            items:
                                ['All', 'Active', 'Hot', 'Trending', 'Archived']
                                    .map(
                                      (status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _filterStatus = value;
                                  _applyFilter();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Deals List
                    Text(
                      'Manage Deals (${_filteredDeals.length})',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _allDeals.isEmpty
                        ? Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'No deals available',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          )
                        : SizedBox(
                            height:
                                constraints.maxHeight * 0.5 +
                                159, // Show overflow by 159 pixels
                            child: ListView.builder(
                              itemCount: _filteredDeals.length,
                              itemBuilder: (context, index) {
                                final deal = _filteredDeals[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(
                                      deal.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${deal.storeName ?? 'No store'} • ${deal.category ?? 'No category'}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                _buildMetricChip(
                                                  '👍 ${deal.likes}',
                                                  Colors.blue[100]!,
                                                ),
                                                const SizedBox(width: 4),
                                                _buildMetricChip(
                                                  '📤 ${deal.shares}',
                                                  Colors.green[100]!,
                                                ),
                                                const SizedBox(width: 4),
                                                _buildMetricChip(
                                                  '👁️ ${deal.views}',
                                                  Colors.grey[100]!,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        // Admin Status Badges
                                        Row(
                                          children: [
                                            if (deal.isHot)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[100],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'HOT',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red[700],
                                                  ),
                                                ),
                                              ),
                                            if (deal.isTrending)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange[100],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'TRENDING',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange[700],
                                                  ),
                                                ),
                                              ),
                                            if (deal.isPinned)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[100],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'PINNED',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                            if (deal.isArchived)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'ARCHIVED',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: SizedBox(
                                      width: 250,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Delete Deal
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed: () => _deleteDeal(deal),
                                            tooltip: 'Delete Deal',
                                          ),
                                          // Hot Toggle
                                          IconButton(
                                            icon: Icon(
                                              deal.isHot
                                                  ? Icons.whatshot
                                                  : Icons.whatshot_outlined,
                                              color: deal.isHot
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                            onPressed: () => _toggleHot(deal),
                                            tooltip: deal.isHot
                                                ? 'Remove from Hot'
                                                : 'Add to Hot',
                                          ),
                                          // Trending Toggle
                                          IconButton(
                                            icon: Icon(
                                              deal.isTrending
                                                  ? Icons.trending_up
                                                  : Icons.trending_up_outlined,
                                              color: deal.isTrending
                                                  ? Colors.orange
                                                  : Colors.grey,
                                            ),
                                            onPressed: () =>
                                                _toggleTrending(deal),
                                            tooltip: deal.isTrending
                                                ? 'Remove from Trending'
                                                : 'Add to Trending',
                                          ),
                                          // Pin Toggle
                                          IconButton(
                                            icon: Icon(
                                              deal.isPinned
                                                  ? Icons.push_pin
                                                  : Icons.push_pin_outlined,
                                              color: deal.isPinned
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                            onPressed: () =>
                                                _togglePinned(deal),
                                            tooltip: deal.isPinned
                                                ? 'Unpin'
                                                : 'Pin',
                                          ),
                                          // Edit Text
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () =>
                                                _editDealText(deal),
                                            tooltip: 'Edit Text',
                                          ),
                                          // Archive/Restore
                                          IconButton(
                                            icon: Icon(
                                              deal.isArchived
                                                  ? Icons.restore
                                                  : Icons.archive,
                                              color: deal.isArchived
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                            onPressed: () => deal.isArchived
                                                ? _restoreDeal(deal)
                                                : _archiveDeal(deal),
                                            tooltip: deal.isArchived
                                                ? 'Restore'
                                                : 'Archive',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String text, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: backgroundColor == Colors.grey[100]!
              ? Colors.grey[700]
              : Colors.blue[700],
        ),
      ),
    );
  }
}

// FAST TEXT PASTE DIALOG (editfeatures.md requirement)
class AddDealFromTextDialog extends StatefulWidget {
  const AddDealFromTextDialog({super.key});

  @override
  State<AddDealFromTextDialog> createState() => _AddDealFromTextDialogState();
}

class _AddDealFromTextDialogState extends State<AddDealFromTextDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pastedTextController = TextEditingController();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _linkController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Deal from Text'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _pastedTextController,
                  decoration: const InputDecoration(
                    labelText: 'Pasted Text',
                    hintText: 'Enter the raw deal text',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pasted text';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter deal title',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'Enter deal category',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: 'Link (Optional)',
                    hintText: 'Enter deal link',
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, {
                'pastedText': _pastedTextController.text,
                'title': _titleController.text,
                'category': _categoryController.text,
                'link': _linkController.text,
                'isHot': false,
              });
            }
          },
          child: const Text('Add Deal'),
        ),
      ],
    );
  }
}

// EDIT DEAL TEXT DIALOG (editfeatures.md requirement)
class EditDealTextDialog extends StatefulWidget {
  final Deal deal;

  const EditDealTextDialog({super.key, required this.deal});

  @override
  State<EditDealTextDialog> createState() => _EditDealTextDialogState();
}

class _EditDealTextDialogState extends State<EditDealTextDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pastedTextController = TextEditingController();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _linkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pastedTextController.text = widget.deal.pastedText ?? '';
    _titleController.text = widget.deal.title ?? '';
    _categoryController.text = widget.deal.category ?? '';
    _linkController.text = widget.deal.link ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Deal Text'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _pastedTextController,
                  decoration: const InputDecoration(
                    labelText: 'Pasted Text',
                    hintText: 'Enter the raw deal text',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pasted text';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter deal title',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'Enter deal category',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a category';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, {
                'pastedText': _pastedTextController.text,
                'title': _titleController.text,
                'category': _categoryController.text,
                'link': _linkController.text,
              });
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}
