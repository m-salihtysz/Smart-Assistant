import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  String content = file.readAsStringSync();

  // Pattern for Text('some string') or Text("some string")
  content = content.replaceAllMapped(
    RegExp(r"Text\('([^']+)'\)"),
    (m) {
      if (m.group(1) == 'tr' || m.group(1) == 'en') return m.group(0)!; // ignore locales
      return "Text('${m.group(1)}'.tr(context))";
    },
  );
  content = content.replaceAllMapped(
      RegExp(r"Text\('([^']+)',\s*(style:|textAlign:|maxLines:|overflow:)"),
      (m) => "Text('${m.group(1)}'.tr(context), ${m.group(2)}"
  );
  // labelText: '...'
  content = content.replaceAllMapped(
    RegExp(r"labelText:\s*'([^']+)'"),
    (m) => "labelText: '${m.group(1)}'.tr(context)",
  );
  // hintText: '...'
  content = content.replaceAllMapped(
    RegExp(r"hintText:\s*'([^']+)'"),
    (m) => "hintText: '${m.group(1)}'.tr(context)",
  );
  
  // label: Text('...') inside buttons etc 
  content = content.replaceAllMapped(
    RegExp(r"label:\s*Text\('([^']+)'\)"),
    (m) => "label: Text('${m.group(1)}'.tr(context))",
  );

  // Write back
  file.writeAsStringSync(content);
  print('Done applying tr(context) to main.dart');
}
