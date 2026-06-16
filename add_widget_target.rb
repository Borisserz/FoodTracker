require 'xcodeproj'
require 'fileutils'

project_path = 'FoodTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target_name = 'FoodTrackerWidgetExtension'
bundle_id = 'com.borisdev.FoodTracker2026.FoodTrackerWidgetExtension'

if project.targets.any? { |t| t.name == target_name }
  puts "Target #{target_name} already exists!"
  exit 0
end

FileUtils.mkdir_p('FoodTrackerWidgetExtension')

group = project.main_group.find_subpath('FoodTrackerWidgetExtension', true)
group.set_source_tree('<group>')
group.set_path('FoodTrackerWidgetExtension')

target = project.new_target(:app_extension, target_name, :ios, '17.6')
target.product_name = target_name

target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'FoodTrackerWidgetExtension/Info.plist'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'FoodTrackerWidgetExtension/FoodTrackerWidget.entitlements'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = 'LSCCP92LMG'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
end

info_plist_path = File.join('FoodTrackerWidgetExtension', 'Info.plist')
File.write(info_plist_path, <<~PLIST)
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
PLIST
group.new_file('Info.plist')

entitlements_path = File.join('FoodTrackerWidgetExtension', 'FoodTrackerWidget.entitlements')
File.write(entitlements_path, <<~ENTITLEMENTS)
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.borisdev.WorkoutTracker</string>
    </array>
</dict>
</plist>
ENTITLEMENTS
group.new_file('FoodTrackerWidget.entitlements')

swift_file_path = File.join('FoodTrackerWidgetExtension', 'FoodTrackerWidget.swift')
File.write(swift_file_path, "import SwiftUI\nimport WidgetKit\n")
swift_file_ref = group.new_file('FoodTrackerWidget.swift')
target.source_build_phase.add_file_reference(swift_file_ref)

main_target = project.targets.find { |t| t.name == 'FoodTracker' }
if main_target
  main_target.add_dependency(target)
  
  embed_phase = main_target.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins }
  unless embed_phase
    embed_phase = main_target.new_copy_files_build_phase('Embed App Extensions')
    embed_phase.symbol_dst_subfolder_spec = :plug_ins
  end
  embed_file = embed_phase.add_file_reference(target.product_reference)
  embed_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

project.save
puts "Successfully added \#{target_name} to project!"
