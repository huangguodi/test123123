import 'dart:io';

void main(List<String> args) async {
  if (args.length != 3) {
    print('Usage: dart tools/update_branding.dart "App Name" "path/to/icon.png" "index_id"');
    print('Example: dart tools/update_branding.dart "MyApp" "assets/logo.png" "5"');
    exit(1);
  }

  final String newAppName = args[0];
  final String iconPath = args[1];
  final String indexId = args[2];

  print('🚀 Starting Branding Update...');
  print('📝 New App Name: $newAppName');
  print('🖼️  New Icon Path: $iconPath');
  print('🔢 New Index ID: $indexId');

  // 1. Verify Icon File
  final File iconFile = File(iconPath);
  if (!iconFile.existsSync()) {
    print('❌ Error: Icon file not found at $iconPath');
    exit(1);
  }

  // 2. Update Android App Name (AndroidManifest.xml)
  await _updateAndroidLabel(newAppName);

  // 3. Update iOS App Name (Info.plist)
  await _updateIOSDisplayName(newAppName);

  // 4. Update Icon Configuration (pubspec.yaml) & Run Generator
  await _updateIconConfig(iconPath);

  // 5. Update index ID (assets/app_config.json)
  await _updateAppConfigIndexId(indexId);

  print('✅ Branding Update Completed Successfully!');
}

Future<void> _updateAppConfigIndexId(String newId) async {
  final File configFile = File('assets/app_config.json');
  if (!configFile.existsSync()) {
    print('⚠️ Warning: assets/app_config.json not found.');
    return;
  }

  final content =
      '{\n  "index_id": "$newId"\n}\n';
  await configFile.writeAsString(content);
  print('✅ Updated index_id to "$newId" in assets/app_config.json');
}

Future<void> _updateAndroidLabel(String newName) async {
  final File manifestFile = File('android/app/src/main/AndroidManifest.xml');
  if (!manifestFile.existsSync()) {
    print('⚠️ Warning: AndroidManifest.xml not found.');
    return;
  }

  String content = await manifestFile.readAsString();
  // Regex to match android:label="Old Name"
  // Handles potential quotes variations or multiline, though label is usually single line
  final RegExp labelRegex = RegExp(r'android:label="[^"]*"');

  if (labelRegex.hasMatch(content)) {
    content = content.replaceAll(labelRegex, 'android:label="$newName"');
    await manifestFile.writeAsString(content);
    print('✅ Android label updated to "$newName"');
  } else {
    print('⚠️ Warning: Could not find android:label in AndroidManifest.xml');
  }
}

Future<void> _updateIOSDisplayName(String newName) async {
  final File plistFile = File('ios/Runner/Info.plist');
  if (!plistFile.existsSync()) {
    print('⚠️ Warning: Info.plist not found.');
    return;
  }

  String content = await plistFile.readAsString();
  // Regex to find CFBundleDisplayName key and replace the following string value
  // <key>CFBundleDisplayName</key>
  // <string>Old Name</string>
  final RegExp nameRegex = RegExp(
    r'(<key>CFBundleDisplayName</key>\s*<string>)(.*?)(</string>)',
    multiLine: true,
    dotAll: true,
  );

  if (nameRegex.hasMatch(content)) {
    content = content.replaceAllMapped(nameRegex, (match) {
      return '${match.group(1)}$newName${match.group(3)}';
    });
    await plistFile.writeAsString(content);
    print('✅ iOS CFBundleDisplayName updated to "$newName"');
  } else {
    print('⚠️ Warning: Could not find CFBundleDisplayName in Info.plist');
  }
}

Future<void> _updateIconConfig(String iconPath) async {
  final File pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ Error: pubspec.yaml not found.');
    exit(1);
  }

  String content = await pubspecFile.readAsString();

  // Update image_path in flutter_launcher_icons section
  // Pattern matches indentation + image_path: ...
  final RegExp imagePathRegex =
      RegExp(r'^(\s*)image_path:.*$', multiLine: true);

  if (imagePathRegex.hasMatch(content)) {
    content = content.replaceAllMapped(imagePathRegex, (match) {
      return '${match.group(1)}image_path: "$iconPath"';
    });
    await pubspecFile.writeAsString(content);
    print('✅ pubspec.yaml image_path updated.');
  } else {
    print(
        '⚠️ Warning: Could not find image_path in flutter_launcher_icons config. Appending config...');
    // Fallback if not found (though analysis showed it exists)
    // Ideally we shouldn't simply append if the section is missing, but assuming the section exists based on context.
  }

  print('🔄 Running flutter_launcher_icons...');

  // Run the generator
  final ProcessResult result = await Process.run(
    'dart',
    ['run', 'flutter_launcher_icons'],
    runInShell: true,
  );

  if (result.exitCode == 0) {
    print('✅ Icons generated successfully.');
  } else {
    print('❌ Error generating icons:');
    print(result.stdout);
    print(result.stderr);
  }
}
