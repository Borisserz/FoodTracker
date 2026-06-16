require 'xcodeproj'
require 'fileutils'

project_path = 'FoodTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'FoodTracker' }

# Unit Tests
test_target_name = 'FoodTrackerTests'
if !project.targets.any? { |t| t.name == test_target_name }
  FileUtils.mkdir_p(test_target_name)
  
  group = project.main_group.find_subpath(test_target_name, true)
  group.set_source_tree('<group>')
  group.set_path(test_target_name)

  # :unit_test_bundle
  test_target = project.new_target(:unit_test_bundle, test_target_name, :ios, '17.6')
  test_target.product_name = test_target_name
  
  test_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = "#{test_target_name}/Info.plist"
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.borisdev.FoodTracker2026.#{test_target_name}"
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['DEVELOPMENT_TEAM'] = 'LSCCP92LMG'
    config.build_settings['TEST_TARGET_NAME'] = main_target.name
    config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/FoodTracker.app/FoodTracker'
  end

  info_plist_path = File.join(test_target_name, 'Info.plist')
  File.write(info_plist_path, <<~PLIST)
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>CFBundlePackageType</key>
      <string>BNDL</string>
  </dict>
  </plist>
  PLIST
  group.new_file('Info.plist')

  swift_file_path = File.join(test_target_name, "#{test_target_name}.swift")
  File.write(swift_file_path, "import XCTest\n@testable import FoodTracker\n\nfinal class #{test_target_name}: XCTestCase {\n    func testExample() throws {\n    }\n}\n")
  swift_file_ref = group.new_file("#{test_target_name}.swift")
  test_target.source_build_phase.add_file_reference(swift_file_ref)
  
  test_target.add_dependency(main_target)
  puts "Added #{test_target_name}"
end

# UI Tests
ui_test_target_name = 'FoodTrackerUITests'
if !project.targets.any? { |t| t.name == ui_test_target_name }
  FileUtils.mkdir_p(ui_test_target_name)
  
  group = project.main_group.find_subpath(ui_test_target_name, true)
  group.set_source_tree('<group>')
  group.set_path(ui_test_target_name)

  ui_test_target = project.new_target(:ui_test_bundle, ui_test_target_name, :ios, '17.6')
  ui_test_target.product_name = ui_test_target_name
  
  ui_test_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = "#{ui_test_target_name}/Info.plist"
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.borisdev.FoodTracker2026.#{ui_test_target_name}"
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    config.build_settings['DEVELOPMENT_TEAM'] = 'LSCCP92LMG'
    config.build_settings['TEST_TARGET_NAME'] = main_target.name
  end

  info_plist_path = File.join(ui_test_target_name, 'Info.plist')
  File.write(info_plist_path, <<~PLIST)
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>CFBundlePackageType</key>
      <string>BNDL</string>
  </dict>
  </plist>
  PLIST
  group.new_file('Info.plist')

  swift_file_path = File.join(ui_test_target_name, "#{ui_test_target_name}.swift")
  File.write(swift_file_path, "import XCTest\n\nfinal class #{ui_test_target_name}: XCTestCase {\n    func testExample() throws {\n        let app = XCUIApplication()\n        app.launch()\n    }\n}\n")
  swift_file_ref = group.new_file("#{ui_test_target_name}.swift")
  ui_test_target.source_build_phase.add_file_reference(swift_file_ref)
  
  ui_test_target.add_dependency(main_target)
  puts "Added #{ui_test_target_name}"
end

project.save
puts "Done"
