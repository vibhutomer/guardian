import 'dart:convert';
import 'package:http/http.dart' as http;

class GooglePlacesService {
  // ⚠️ REPLACE WITH YOUR REAL API KEY
  final String apiKey = "API_KEY";

  Future<List<Map<String, dynamic>>> findNearbyHospitals(
    double lat,
    double lng,
  ) async {
    // We use the NEW Places API (v1) to get Phone Numbers
    const String url = "https://places.googleapis.com/v1/places:searchNearby";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          // ASK FOR PHONE NUMBERS SPECIFICALLY
          "X-Goog-FieldMask":
              "places.displayName,places.formattedAddress,places.nationalPhoneNumber,places.location",
        },
        body: jsonEncode({
          "includedTypes": ["hospital"],
          "maxResultCount": 5, // Get top 5 closest
          "locationRestriction": {
            "circle": {
              "center": {"latitude": lat, "longitude": lng},
              "radius": 10000.0, // 10km Radius
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['places'] == null) return [];

        List<Map<String, dynamic>> hospitals = (data['places'] as List).map((
          place,
        ) {
          return {
            "name": place['displayName']['text'],
            "address": place['formattedAddress'] ?? "Address unavailable",
            "phone": place['nationalPhoneNumber'] ?? "", // <--- We need this!
            "lat": place['location']['latitude'],
            "lng": place['location']['longitude'],
            "status": "REQUEST_SENT",
          };
        }).toList();

        return hospitals;
      } else {
        print("❌ API Error: ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Error fetching hospitals: $e");
      return [];
    }
  }
}
