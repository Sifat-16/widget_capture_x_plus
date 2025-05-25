// lib/dart_html_stub.dart
// This file provides stubs for dart:html types for non-web platforms.

// Stub for html.Blob
class Blob {
  Blob(List<dynamic> blobParts, [String? type, String? endings]) {
    // Stub implementation: does nothing.
    // You could add a print statement for debugging if needed:
    // print('STUB: Blob constructor called on non-web platform.');
  }
}

// Stub for html.Url
class Url {
  static String createObjectUrlFromBlob(Blob blob) {
    // Stub implementation: returns a placeholder string.
    // This function would not actually create a usable URL on native.
    print('STUB: Url.createObjectUrlFromBlob called on non-web platform.');
    return 'stub_blob_url_${DateTime.now().millisecondsSinceEpoch}';
  }

  static void revokeObjectUrl(String url) {
    // Stub implementation: does nothing.
    // print('STUB: Url.revokeObjectUrl($url) called on non-web platform.');
  }
}

// Stub for html.AnchorElement
class AnchorElement {
  String? href;
  String? download; // To stub the download attribute

  AnchorElement({this.href});

  void setAttribute(String name, String value) {
    // Stub implementation: does nothing.
    if (name.toLowerCase() == 'download') {
      this.download = value;
    }
    // print('STUB: AnchorElement.setAttribute($name, $value) called on non-web platform.');
  }

  void click() {
    // Stub implementation: does nothing.
    print(
      'STUB: AnchorElement.click() called on non-web platform (download would not occur).',
    );
  }

  // Add other methods or properties if your download/web logic uses them.
}

// You might need stubs for other html elements if your web-specific code uses them.
// For example, if you were directly manipulating `window` or `document`:
//
// class Window {
//   // Add stubs for window properties/methods used
// }
// Window get window => Window(); // Stub global window object
//
// class Document {
//   // Add stubs for document properties/methods used
// }
// Document get document => Document(); // Stub global document object
