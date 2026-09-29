import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../repositories/admin_repository.dart';
import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';
import '../auth/welcome_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.adminName});

  final String adminName;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repository = AdminRepository();
  int _selectedIndex = 0;
  bool _checkingAccess = true;
  bool _isAdmin = false;
  String? _accessError;

  static const _titles = ['Overview', 'Users', 'Support tickets'];
  static const _icons = [
    Icons.space_dashboard_rounded,
    Icons.people_alt_rounded,
    Icons.support_agent_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    setState(() {
      _checkingAccess = true;
      _accessError = null;
    });
    try {
      final allowed = await _repository.isCurrentUserAdmin();
      if (!mounted) return;
      setState(() {
        _isAdmin = allowed;
        _checkingAccess = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _accessError = 'Unable to verify admin access. Check your connection.';
        _checkingAccess = false;
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  Future<void> _showAccessInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF15191C),
        title: const Text('Admin access'),
        content: Text(
          'For the FYP prototype, set users/${FirebaseAuth.instance.currentUser?.uid ?? 'your-user-id'}.role to admin in Firestore, then sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wideLayout = MediaQuery.sizeOf(context).width >= 900;

    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: DLogColors.black,
        body: Center(
          child: CircularProgressIndicator(color: DLogColors.burgundyBright),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: DLogColors.black,
        body: DLogBackground(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: DLogColors.burgundyBright,
                        size: 54,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _accessError ??
                            'This account does not have admin access.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_accessError != null)
                        OutlinedButton(
                          onPressed: _verifyAccess,
                          child: const Text('TRY AGAIN'),
                        )
                      else
                        TextButton(
                          onPressed: _showAccessInfo,
                          child: const Text('HOW TO ENABLE ADMIN ACCESS'),
                        ),
                      TextButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('SIGN OUT'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final page = IndexedStack(
      index: _selectedIndex,
      children: [
        _AdminOverviewPage(repository: _repository),
        _AdminUsersPage(repository: _repository),
        _AdminTicketsPage(repository: _repository),
      ],
    );

    return Scaffold(
      backgroundColor: DLogColors.black,
      body: DLogBackground(
        child: SafeArea(
          child: wideLayout
              ? Row(
                  children: [
                    _wideNavigation(),
                    VerticalDivider(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _header(),
                          Expanded(child: page),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _header(),
                    Expanded(child: page),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: wideLayout
          ? null
          : NavigationBar(
              backgroundColor: const Color(0xFF101214),
              indicatorColor: DLogColors.burgundy.withValues(alpha: 0.32),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: List.generate(
                _titles.length,
                (index) => NavigationDestination(
                  icon: Icon(_icons[index]),
                  label: _titles[index],
                ),
              ),
            ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 18, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: DLogColors.burgundyBright,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DLOG ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Signed in as ${widget.adminName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DLogColors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, color: DLogColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _wideNavigation() {
    return NavigationRail(
      backgroundColor: const Color(0xFF090B0D).withValues(alpha: 0.86),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: DLogColors.burgundyBright),
      unselectedIconTheme: const IconThemeData(color: DLogColors.grey),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: DLogColors.grey,
        fontSize: 11,
      ),
      destinations: List.generate(
        _titles.length,
        (index) => NavigationRailDestination(
          icon: Icon(_icons[index]),
          label: Text(_titles[index]),
        ),
      ),
    );
  }
}

class _AdminOverviewPage extends StatefulWidget {
  const _AdminOverviewPage({required this.repository});

  final AdminRepository repository;

  @override
  State<_AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<_AdminOverviewPage> {
  late Future<AdminOverviewData> _overview;

  @override
  void initState() {
    super.initState();
    _overview = widget.repository.loadOverview();
  }

  void _reload() =>
      setState(() => _overview = widget.repository.loadOverview());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminOverviewData>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: DLogColors.burgundyBright),
          );
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: _firebaseFailureMessage('Firebase totals', snapshot.error),
            onRetry: _reload,
          );
        }

        final data = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 820 ? 4 : 2;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                _PageHeading(
                  eyebrow: 'ADMIN OVERVIEW',
                  title: 'Dashboard',
                  subtitle: 'Live totals from DLog records.',
                  trailing: IconButton(
                    tooltip: 'Refresh dashboard',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 11,
                  mainAxisSpacing: 11,
                  childAspectRatio: columns == 2 ? 1.48 : 1.35,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MetricCard(
                      label: 'TOTAL USERS',
                      value: data.userCount,
                      icon: Icons.people_alt_rounded,
                      accent: const Color(0xFFD9D9D9),
                    ),
                    _MetricCard(
                      label: 'TOTAL VEHICLES',
                      value: data.vehicleCount,
                      icon: Icons.directions_car_filled_rounded,
                      accent: const Color(0xFF63C5A2),
                    ),
                    _MetricCard(
                      label: 'SERVICE RECORDS',
                      value: data.serviceRecordCount,
                      icon: Icons.event_note_rounded,
                      accent: const Color(0xFFE7B554),
                    ),
                    _LiveTicketMetricCard(repository: widget.repository),
                  ],
                ),
                const SizedBox(height: 22),
                _MaintenanceSourcesCard(data: data),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _panelDecoration(),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded, color: DLogColors.grey),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'User service history is shown only as an aggregate here. Use support tickets for corrections instead of editing users’ records.',
                          style: TextStyle(
                            color: DLogColors.grey,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AdminUsersPage extends StatefulWidget {
  const _AdminUsersPage({required this.repository});

  final AdminRepository repository;

  @override
  State<_AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<_AdminUsersPage> {
  late Future<List<AdminUserData>> _users;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _users = widget.repository.loadUsers();
  }

  Future<void> _reload() async {
    final refreshed = widget.repository.loadUsers();
    setState(() => _users = refreshed);
    await refreshed;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminUserData>>(
      future: _users,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: DLogColors.burgundyBright),
          );
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: 'Could not load users from Firebase.',
            onRetry: _reload,
          );
        }

        final query = _query.trim().toLowerCase();
        final users = (snapshot.data ?? const <AdminUserData>[]).where((user) {
          return query.isEmpty ||
              user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _PageHeading(
              eyebrow: 'ACCOUNT DIRECTORY',
              title: 'Users',
              subtitle: '${snapshot.data?.length ?? 0} registered accounts',
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFF111518),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (users.isEmpty)
              _EmptyAdminState(
                icon: Icons.people_outline_rounded,
                title: query.isEmpty
                    ? 'No user records yet'
                    : 'No matching users',
                message: query.isEmpty
                    ? 'Registered DLog accounts will appear here.'
                    : 'Try another name or email.',
              )
            else
              ...users.map((user) => _UserCard(user: user)),
          ],
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AdminUserData user;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isEmpty
        ? '?'
        : user.name.trim().characters.first.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: DLogColors.burgundy.withValues(alpha: 0.26),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DLogColors.grey, fontSize: 11),
                ),
                const SizedBox(height: 7),
                Text(
                  user.createdAt == null
                      ? 'Joined date unavailable'
                      : 'Joined ${_formatDate(user.createdAt)}',
                  style: TextStyle(
                    color: DLogColors.grey.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              const Icon(
                Icons.directions_car_rounded,
                color: DLogColors.grey,
                size: 19,
              ),
              const SizedBox(height: 3),
              Text(
                '${user.vehicleCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                user.vehicleCount == 1 ? 'vehicle' : 'vehicles',
                style: const TextStyle(color: DLogColors.grey, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminTicketsPage extends StatefulWidget {
  const _AdminTicketsPage({required this.repository});

  final AdminRepository repository;

  @override
  State<_AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends State<_AdminTicketsPage> {
  late Stream<List<AdminTicketData>> _tickets;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _tickets = widget.repository.watchTickets();
  }

  void _reload() {
    setState(() => _tickets = widget.repository.watchTickets());
  }

  Future<void> _setStatus(AdminTicketData ticket, String status) async {
    try {
      await widget.repository.updateTicketStatus(
        ticketId: ticket.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket status updated.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update ticket: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminTicketData>>(
      stream: _tickets,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: DLogColors.burgundyBright),
          );
        }
        if (snapshot.hasError) {
          return _AdminErrorState(
            message: _firebaseFailureMessage('support tickets', snapshot.error),
            onRetry: _reload,
          );
        }

        final allTickets = snapshot.data ?? const <AdminTicketData>[];
        final tickets = allTickets.where((ticket) {
          return _filter == 'all' || ticket.status == _filter;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _PageHeading(
              eyebrow: 'USER SUPPORT',
              title: 'Support tickets',
              subtitle: '${allTickets.length} total · live from Firebase',
              trailing: IconButton(
                tooltip: 'Reconnect to ticket updates',
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ticketFilter('all', 'All', allTickets.length),
                  _ticketFilter(
                    'open',
                    'Open',
                    allTickets
                        .where((ticket) => ticket.status == 'open')
                        .length,
                  ),
                  _ticketFilter(
                    'in_progress',
                    'In Progress',
                    allTickets
                        .where((ticket) => ticket.status == 'in_progress')
                        .length,
                  ),
                  _ticketFilter(
                    'resolved',
                    'Resolved',
                    allTickets
                        .where((ticket) => ticket.status == 'resolved')
                        .length,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (tickets.isEmpty)
              const _EmptyAdminState(
                icon: Icons.inbox_rounded,
                title: 'No tickets in this view',
                message: 'New user support requests will appear here.',
              )
            else
              ...tickets.map(_ticketCard),
          ],
        );
      },
    );
  }

  Widget _ticketFilter(String value, String label, int count) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text('$label $count'),
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: DLogColors.burgundyBright,
        backgroundColor: const Color(0xFF121619),
        labelStyle: TextStyle(
          color: selected ? Colors.white : DLogColors.grey,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: selected
              ? DLogColors.burgundyBright
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
    );
  }

  Widget _ticketCard(AdminTicketData ticket) {
    final color = _ticketColor(ticket.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: _panelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.confirmation_num_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ticket.category} · ${ticket.userName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DLogColors.grey, fontSize: 10),
                ),
                const SizedBox(height: 7),
                Text(
                  ticket.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC6CBCD),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${_ticketLabel(ticket.status)} · ${_formatDate(ticket.createdAt)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Update ticket status',
            icon: const Icon(Icons.more_vert_rounded, color: DLogColors.grey),
            onSelected: (status) => _setStatus(ticket, status),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'open', child: Text('Mark Open')),
              PopupMenuItem(value: 'in_progress', child: Text('In Progress')),
              PopupMenuItem(value: 'resolved', child: Text('Resolved')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaintenanceSourcesCard extends StatelessWidget {
  const _MaintenanceSourcesCard({required this.data});

  final AdminOverviewData data;

  @override
  Widget build(BuildContext context) {
    final total = data.ruleCount;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MAINTENANCE DATA',
            style: TextStyle(
              color: DLogColors.grey,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                  painter: _RuleSourcePainter(
                    manufacturer: data.manufacturerRuleCount,
                    prototype: data.prototypeRuleCount,
                    other: data.otherRuleCount,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'RULES',
                          style: TextStyle(
                            color: DLogColors.grey,
                            fontSize: 8,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sourceLegend(
                      'Manufacturer source',
                      data.manufacturerRuleCount,
                      const Color(0xFF62C5A0),
                    ),
                    const SizedBox(height: 9),
                    _sourceLegend(
                      'DLog prototype',
                      data.prototypeRuleCount,
                      DLogColors.burgundyBright,
                    ),
                    const SizedBox(height: 9),
                    _sourceLegend(
                      'Other source',
                      data.otherRuleCount,
                      const Color(0xFFE5B957),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${data.ruleProfileCount} vehicle profiles configured',
                      style: const TextStyle(
                        color: DLogColors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sourceLegend(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: DLogColors.grey, fontSize: 10),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RuleSourcePainter extends CustomPainter {
  const _RuleSourcePainter({
    required this.manufacturer,
    required this.prototype,
    required this.other,
  });

  final int manufacturer;
  final int prototype;
  final int other;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    final total = manufacturer + prototype + other;
    if (total == 0) {
      stroke.color = const Color(0xFF272D31);
      canvas.drawArc(rect.deflate(7), -math.pi / 2, math.pi * 2, false, stroke);
      return;
    }

    final values = [
      (manufacturer, const Color(0xFF62C5A0)),
      (prototype, DLogColors.burgundyBright),
      (other, const Color(0xFFE5B957)),
    ];
    var start = -math.pi / 2;
    for (final (value, color) in values) {
      if (value == 0) continue;
      final sweep = (value / total) * math.pi * 2;
      stroke.color = color;
      canvas.drawArc(rect.deflate(7), start, sweep, false, stroke);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RuleSourcePainter oldDelegate) =>
      manufacturer != oldDelegate.manufacturer ||
      prototype != oldDelegate.prototype ||
      other != oldDelegate.other;
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: DLogColors.burgundyBright,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: DLogColors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _LiveTicketMetricCard extends StatelessWidget {
  const _LiveTicketMetricCard({required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminTicketData>>(
      stream: repository.watchTickets(),
      builder: (context, snapshot) {
        final tickets = snapshot.data;
        final openCount = tickets
            ?.where(
              (ticket) =>
                  ticket.status == 'open' || ticket.status == 'in_progress',
            )
            .length;
        final detail = snapshot.hasError
            ? 'Could not load tickets'
            : tickets == null
            ? 'Connecting to Firebase…'
            : '$openCount open or in progress';
        return _MetricCard(
          label: 'SUPPORT TICKETS',
          value: tickets?.length,
          detail: detail,
          icon: Icons.support_agent_rounded,
          accent: DLogColors.burgundyBright,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.detail,
  });

  final String label;
  final int? value;
  final IconData icon;
  final Color accent;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 21),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value?.toString() ?? '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DLogColors.grey,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontSize: 8),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyAdminState extends StatelessWidget {
  const _EmptyAdminState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(25),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Icon(icon, color: DLogColors.grey, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DLogColors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _firebaseFailureMessage(String target, Object? error) {
  if (error is FirebaseException) {
    final reason = switch (error.code) {
      'permission-denied' =>
        'Firestore denied this read. Check the project’s Firestore Rules for admin read access.',
      'unavailable' =>
        'Firestore is unavailable. Check the device connection and retry.',
      _ => error.message ?? 'Check the device connection and Firestore Rules.',
    };
    return 'Could not load $target. $reason (code: ${error.code}).';
  }
  return 'Could not load $target. Check the device connection and Firestore Rules. ${error ?? ''}';
}

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: DLogColors.grey,
              size: 35,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration() => BoxDecoration(
  color: const Color(0xFF101417).withValues(alpha: 0.96),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
);

String _ticketLabel(String status) => switch (status) {
  'open' => 'OPEN',
  'in_progress' => 'IN PROGRESS',
  'resolved' => 'RESOLVED',
  _ => 'STATUS UNKNOWN',
};

Color _ticketColor(String status) => switch (status) {
  'open' => const Color(0xFFE15963),
  'in_progress' => const Color(0xFFE5B957),
  'resolved' => const Color(0xFF62C5A0),
  _ => DLogColors.grey,
};

String _formatDate(DateTime? value) {
  if (value == null) return 'Date unavailable';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
