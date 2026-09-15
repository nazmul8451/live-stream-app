import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final response = await http.post(
      Uri.parse('https://api.areisco.com/api/v1/trades/votes/65f123abc456789012345678/cast'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({"option": "A"}),
    );
    print('STATUS CODE: ${response.statusCode}');
    print('RESPONSE BODY: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
