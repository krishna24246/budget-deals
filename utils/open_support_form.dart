import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openSupportForm(BuildContext context) async {
  final Uri formUrl = Uri.parse("https://forms.gle/yiwG7mm9sVPqQvjN9");
  try {
    if (!await launchUrl(formUrl, mode: LaunchMode.externalApplication)) {
      throw 'Could not open the support form';
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to open support form. Please check your internet connection.',
        ),
      ),
    );
  }
}
