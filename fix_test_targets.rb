require 'xcodeproj'

project_path = 'FoodTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

unit_target = project.targets.find { |t| t.name == 'FoodTrackerTests' }
if unit_target
  unit_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    config.build_settings['TEST_TARGET_NAME'] = 'FoodTracker'
    config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/FoodTracker.app/FoodTracker'
  end
end

ui_target = project.targets.find { |t| t.name == 'FoodTrackerUITests' }
if ui_target
  ui_target.build_configurations.each do |config|
    config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
    config.build_settings['TEST_TARGET_NAME'] = 'FoodTracker'
  end
end

project.save
puts "Fixed PRODUCT_NAME build settings"
