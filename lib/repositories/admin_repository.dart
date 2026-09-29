import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/maintenance_rules.dart';

class AdminOverviewData {
  const AdminOverviewData({
    required this.userCount,
    required this.vehicleCount,
    required this.serviceRecordCount,
    required this.ticketCount,
    required this.openTicketCount,
    required this.ruleProfileCount,
    required this.ruleCount,
    required this.prototypeRuleCount,
    required this.manufacturerRuleCount,
    required this.otherRuleCount,
  });

  final int userCount;
  final int vehicleCount;
  final int serviceRecordCount;
  final int ticketCount;
  final int openTicketCount;
  final int ruleProfileCount;
  final int ruleCount;
  final int prototypeRuleCount;
  final int manufacturerRuleCount;
  final int otherRuleCount;
}

class AdminUserData {
  const AdminUserData({
    required this.uid,
    required this.name,
    required this.email,
    required this.vehicleCount,
    required this.role,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final int vehicleCount;
  final String role;
  final DateTime? createdAt;
}

class AdminTicketData {
  const AdminTicketData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String category;
  final String subject;
  final String message;
  final String status;
  final DateTime? createdAt;
}

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final profile = await _firestore.collection('users').doc(user.uid).get();
    return profile.data()?['role']?.toString().trim().toLowerCase() == 'admin';
  }

  Future<AdminOverviewData> loadOverview() async {
    final snapshots = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('vehicles').get(),
      _firestore.collection('serviceRecords').get(),
      _firestore.collection('supportTickets').get(),
    ]);

    final tickets = snapshots[3].docs;
    final rules = MaintenanceRules.all;
    final prototypeRules = rules
        .where((rule) => rule.source == MaintenanceRules.dlogPrototypeMatrix)
        .length;
    final manufacturerRules = rules
        .where((rule) => rule.source.startsWith('manufacturer_'))
        .length;
    final profiles = rules.map((rule) => rule.ruleGroupId).toSet();

    return AdminOverviewData(
      userCount: snapshots[0].size,
      vehicleCount: snapshots[1].size,
      serviceRecordCount: snapshots[2].size,
      ticketCount: tickets.length,
      openTicketCount: tickets.where((ticket) {
        final status = ticket.data()['status']?.toString().toLowerCase();
        return status == 'open' || status == 'in_progress';
      }).length,
      ruleProfileCount: profiles.length,
      ruleCount: rules.length,
      prototypeRuleCount: prototypeRules,
      manufacturerRuleCount: manufacturerRules,
      otherRuleCount: rules.length - prototypeRules - manufacturerRules,
    );
  }

  Future<List<AdminUserData>> loadUsers() async {
    final snapshots = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('vehicles').get(),
    ]);

    final vehiclesByUser = <String, int>{};
    for (final vehicle in snapshots[1].docs) {
      final userId = vehicle.data()['userId']?.toString();
      if (userId == null || userId.isEmpty) continue;
      vehiclesByUser.update(
        userId,
        (currentCount) => currentCount + 1,
        ifAbsent: () => 1,
      );
    }

    final users = snapshots[0].docs.map((document) {
      final data = document.data();
      final name = data['fullName']?.toString().trim() ?? '';
      final email = data['email']?.toString().trim() ?? '';
      return AdminUserData(
        uid: document.id,
        name: name.isEmpty ? 'Name not provided' : name,
        email: email.isEmpty ? 'Email not provided' : email,
        vehicleCount: vehiclesByUser[document.id] ?? 0,
        role: data['role']?.toString() ?? 'unknown',
        createdAt: _readDate(data['createdAt']),
      );
    }).toList();

    users.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return users;
  }

  Future<List<AdminTicketData>> loadTickets() async {
    final snapshot = await _firestore.collection('supportTickets').get();
    return _ticketsFromSnapshot(snapshot);
  }

  Stream<List<AdminTicketData>> watchTickets() {
    return _firestore
        .collection('supportTickets')
        .snapshots()
        .map(_ticketsFromSnapshot);
  }

  List<AdminTicketData> _ticketsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final tickets = snapshot.docs.map((document) {
      final data = document.data();
      return AdminTicketData(
        id: document.id,
        userId: data['userId']?.toString() ?? '',
        userName: data['userName']?.toString() ?? 'Name not provided',
        userEmail: data['userEmail']?.toString() ?? 'Email not provided',
        category: data['category']?.toString() ?? 'Uncategorised',
        subject: data['subject']?.toString() ?? 'No subject',
        message: data['message']?.toString() ?? '',
        status: data['status']?.toString().toLowerCase() ?? 'unknown',
        createdAt: _readDate(data['createdAt']),
      );
    }).toList();

    tickets.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });
    return tickets;
  }

  Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    if (!const {'open', 'in_progress', 'resolved'}.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported ticket status.');
    }
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) throw StateError('Admin session has expired.');

    await _firestore.collection('supportTickets').doc(ticketId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': adminId,
    });
  }

  Future<String> submitSupportTicket({
    required String category,
    required String subject,
    required String message,
  }) async {
    final allowedCategories = {
      'App bug',
      'Maintenance data',
      'Account',
      'Other',
    };
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    if (!allowedCategories.contains(category)) {
      throw ArgumentError.value(
        category,
        'category',
        'Choose a valid support category.',
      );
    }
    if (cleanSubject.length < 4 || cleanSubject.length > 80) {
      throw ArgumentError.value(
        subject,
        'subject',
        'Subject must be 4–80 characters.',
      );
    }
    if (cleanMessage.length < 12 || cleanMessage.length > 1200) {
      throw ArgumentError.value(
        message,
        'message',
        'Details must be 12–1200 characters.',
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in before contacting support.');
    }

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final profileName = profile.data()?['fullName']?.toString().trim() ?? '';
    final ticket = _firestore.collection('supportTickets').doc();

    await ticket.set({
      'userId': user.uid,
      'userName': profileName.isEmpty
          ? (user.displayName ?? 'Name not provided')
          : profileName,
      'userEmail': user.email ?? '',
      'category': category,
      'subject': cleanSubject,
      'message': cleanMessage,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ticket.id;
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
