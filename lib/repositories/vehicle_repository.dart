import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vehicle_documents.dart';

class VehicleRepository {
  final FirebaseFirestore _firestore;

  VehicleRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('vehicles');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<String> addVehicle({
    required String userId,
    required String manufacturer,
    required String model,
    required String variant,
    required int year,
    required String engine,
    required String transmission,
    required int currentMileage,
    required String ruleGroupId,
    required String vehicleLifecycle,

    // Service history information
    bool serviceHistoryKnown = false,
    DateTime? lastServiceDate,
    int? lastServiceMileage,
    List<String> recentServiceItems = const [],
  }) async {
    final doc = _collection.doc();

    final Map<String, dynamic> vehicleData = {
      'userId': userId,
      'manufacturer': manufacturer,
      'model': model,
      'variant': variant,
      'year': year,
      'engine': engine,
      'transmission': transmission,
      'currentMileage': currentMileage,
      'ruleGroupId': ruleGroupId,
      'vehicleLifecycle': vehicleLifecycle,

      // Service history
      'serviceHistoryKnown': serviceHistoryKnown,
      'lastServiceDate': lastServiceDate != null
          ? Timestamp.fromDate(lastServiceDate)
          : null,
      'lastServiceMileage': lastServiceMileage,
      'recentServiceItems': recentServiceItems,

      'createdAt': FieldValue.serverTimestamp(),
    };

    await doc.set(vehicleData);
    await _makeDefaultIfMissing(userId, doc.id);

    return doc.id;
  }

  Future<void> _makeDefaultIfMissing(String userId, String vehicleId) async {
    final userRef = _users.doc(userId);
    await _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      final currentDefault = user.data()?['defaultVehicleId'];
      if (currentDefault is String && currentDefault.isNotEmpty) return;
      transaction.set(userRef, {
        'defaultVehicleId': vehicleId,
      }, SetOptions(merge: true));
    });
  }

  /// Returns the saved default, choosing the oldest vehicle when this is an
  /// existing account that predates the default-vehicle setting.
  Future<String?> getDefaultVehicleId(String userId) async {
    final userRef = _users.doc(userId);
    final user = await userRef.get();
    final currentDefault = user.data()?['defaultVehicleId'];

    if (currentDefault is String && currentDefault.isNotEmpty) {
      final vehicle = await _collection.doc(currentDefault).get();
      if (vehicle.exists && vehicle.data()?['userId'] == userId) {
        return currentDefault;
      }
    }

    final vehicles = await getVehiclesForUser(userId);
    if (vehicles.isEmpty) return null;

    // getVehiclesForUser sorts newest first; the oldest entry preserves the
    // first vehicle as the default for accounts created before this feature.
    final fallbackId = vehicles.last['id']?.toString();
    if (fallbackId == null || fallbackId.isEmpty) return null;

    return _firestore.runTransaction<String?>((transaction) async {
      final latestUser = await transaction.get(userRef);
      final latestDefault = latestUser.data()?['defaultVehicleId'];
      if (latestDefault is String && latestDefault.isNotEmpty) {
        final latestVehicle = await transaction.get(
          _collection.doc(latestDefault),
        );
        if (latestVehicle.exists && latestVehicle.data()?['userId'] == userId) {
          return latestDefault;
        }
      }

      final fallback = await transaction.get(_collection.doc(fallbackId));
      if (!fallback.exists || fallback.data()?['userId'] != userId) return null;

      transaction.set(userRef, {
        'defaultVehicleId': fallbackId,
      }, SetOptions(merge: true));
      return fallbackId;
    });
  }

  Future<Map<String, dynamic>?> getDefaultVehicleForUser(String userId) async {
    final vehicleId = await getDefaultVehicleId(userId);
    if (vehicleId == null) return null;
    return getVehicle(vehicleId);
  }

  Future<void> setDefaultVehicle({
    required String userId,
    required String vehicleId,
  }) async {
    final vehicleRef = _collection.doc(vehicleId);
    final userRef = _users.doc(userId);
    await _firestore.runTransaction((transaction) async {
      final vehicle = await transaction.get(vehicleRef);
      if (!vehicle.exists || vehicle.data()?['userId'] != userId) {
        throw StateError('This vehicle does not belong to the signed-in user.');
      }
      transaction.set(userRef, {
        'defaultVehicleId': vehicleId,
      }, SetOptions(merge: true));
    });
  }

  Future<List<Map<String, dynamic>>> getVehiclesForUser(String userId) async {
    final snapshot = await _collection.where('userId', isEqualTo: userId).get();

    final vehicles = snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();

    vehicles.sort((a, b) {
      final aCreated = a['createdAt'];
      final bCreated = b['createdAt'];

      if (aCreated is Timestamp && bCreated is Timestamp) {
        return bCreated.compareTo(aCreated);
      }

      return 0;
    });

    return vehicles;
  }

  Future<Map<String, dynamic>?> getVehicle(String vehicleId) async {
    final doc = await _collection.doc(vehicleId).get();

    if (!doc.exists) {
      return null;
    }

    return {'id': doc.id, ...doc.data()!};
  }

  Future<void> updateMileage({
    required String vehicleId,
    required int currentMileage,
  }) async {
    await _collection.doc(vehicleId).update({'currentMileage': currentMileage});
  }

  Future<void> updateVehicleDocuments({
    required String vehicleId,
    InsuranceDetails? insurance,
    RoadTaxDetails? roadTax,
  }) async {
    await _collection.doc(vehicleId).update({
      'insuranceDetails': insurance?.toMap(),
      'roadTaxDetails': roadTax?.toMap(),
      'documentsUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteVehicle(String vehicleId) async {
    final vehicleRef = _collection.doc(vehicleId);
    final initialVehicle = await vehicleRef.get();
    if (!initialVehicle.exists) return;

    final userId = initialVehicle.data()?['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      await vehicleRef.delete();
      return;
    }

    final userRef = _users.doc(userId);
    final candidates = await getVehiclesForUser(userId);

    await _firestore.runTransaction((transaction) async {
      final vehicle = await transaction.get(vehicleRef);
      if (!vehicle.exists) return;

      final user = await transaction.get(userRef);
      final isDefault = user.data()?['defaultVehicleId'] == vehicleId;
      String? replacementId;

      if (isDefault) {
        for (final candidate in candidates) {
          final candidateId = candidate['id']?.toString();
          if (candidateId == null || candidateId == vehicleId) continue;
          final replacement = await transaction.get(
            _collection.doc(candidateId),
          );
          if (replacement.exists && replacement.data()?['userId'] == userId) {
            replacementId = candidateId;
            break;
          }
        }
      }

      transaction.delete(vehicleRef);
      if (isDefault && user.exists) {
        transaction.update(userRef, {'defaultVehicleId': replacementId});
      }
    });
  }
}
