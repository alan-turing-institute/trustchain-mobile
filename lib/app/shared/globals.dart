import 'package:credible/app/interop/secure_storage/secure_storage.dart';
import 'package:credible/app/pages/chain/models/chain.dart';
import 'package:credible/app/pages/did/models/did.dart';
import 'package:credible/app/pages/profile/models/config.dart';
import 'package:dio/dio.dart';

import 'config.dart';

Future<Response> resolveDidResponse(String did) async {
  final endpoint = (await ffi_config_instance.get_trustchain_endpoint());
  final route = '/did/' + did;
  final uri = Uri.parse(endpoint + route);
  return await Dio().getUri(uri);
}

Future<DIDModel> resolveDid(String did) async {
  return DIDModel.fromMap((await resolveDidResponse(did)).data);
}

// TODO [#43]: replace with FFI call
Future<DIDChainModel> resolveDidChain(String did) async {
  final endpoint = (await ffi_config_instance.get_trustchain_endpoint());
  final route = '/did/chain/' + did;
  final queryParams = {
    'root_event_time':
        (await ffi_config_instance.get_root_event_time()).toString(),
  };
  final uri = Uri.parse(endpoint + route).replace(queryParameters: queryParams);
  return DIDChainModel.fromMap((await Dio().getUri(uri)).data);
}

String humanReadableEndpoint(String endpoint) {
  return endpoint.split('www.').last;
}

Map<String, dynamic> stripContext(Map<String, dynamic> map) {
  // Remove any jsonld context entries in the hierarchy
  var result = Map<String, dynamic>();
  map.forEach((key, value) {
    if (key != '@context') {
      if (value is Map<String, dynamic>) {
        result[key] = stripContext(value);
      } else {
        result[key] = value;
      }
    }
  });
  return result;
}

// Checks that a given Unix (UTC) timestamp falls within the 24 hours of the given date.
bool validate_timestamp(int timestamp, DateTime date) {
  var date_utc = DateTime.utc(date.year, date.month, date.day, 0, 0, 0);
  var lower_bound = (date_utc.millisecondsSinceEpoch / 1000).round();
  if (timestamp < lower_bound) {
    return false;
  }
  date_utc = date_utc.add(const Duration(days: 1));
  var upper_bound = (date_utc.millisecondsSinceEpoch / 1000).round();
  if (!(timestamp < upper_bound)) {
    return false;
  }
  return true;
}

String? extractEndpoint(dynamic did_document, String service_id) {
  for (var service in did_document['service']) {
    if (service['id'] == service_id) {
      return service['serviceEndpoint'];
    }
  }
  return null;
}

String? extractServiceType(dynamic did_document, String service_id) {
  for (var service in did_document['service']) {
    if (service['id'] == service_id) {
      return service['type'];
    }
  }
  return null;
}

int? parseIntOrNull(s) {
  try {
    return (int.parse(s));
  } catch (err) {
    return (null);
  }
}
