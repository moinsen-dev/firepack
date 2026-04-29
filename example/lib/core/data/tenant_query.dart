// Hand-written helper — referenced by every generated repository whose
// collection has a `tenant:` field in the spec.
//
// firepack stays neutral about how the tenant id is sourced (auth claim,
// app config, route param, …) — it just emits `.scopedToOrg(orgId)`
// against the consumer's CollectionReference and expects this extension
// to exist somewhere in the project.
//
// This minimal example uses `organizationId` as the tenant field, which
// matches `tenant: organizationId` in the spec.

import 'package:cloud_firestore/cloud_firestore.dart';

extension TenantQuery on CollectionReference<Map<String, dynamic>> {
  Query<Map<String, dynamic>> scopedToOrg(String orgId) =>
      where('organizationId', isEqualTo: orgId);
}
