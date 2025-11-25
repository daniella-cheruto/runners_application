import 'package:url_launcher/url_launcher.dart';

Future<void> openGoogleMaps(double lat, double lng) async {
  final uri = Uri.parse(
    "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    throw "Could not launch Google Maps";
  }
}
