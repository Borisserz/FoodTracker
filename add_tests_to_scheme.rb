require 'xcodeproj'
require 'fileutils'

project_path = 'FoodTracker.xcodeproj'
scheme_dir = File.join(project_path, 'xcshareddata', 'xcschemes')
FileUtils.mkdir_p(scheme_dir)
scheme_path = File.join(scheme_dir, 'FoodTracker.xcscheme')

unless File.exist?(scheme_path)
  puts "FoodTracker.xcscheme not found! Creating default scheme..."
  project = Xcodeproj::Project.open(project_path)
  target = project.targets.find { |t| t.name == 'FoodTracker' }
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  scheme.save_as(project_path, 'FoodTracker', true)
end

project = Xcodeproj::Project.open(project_path)
scheme = Xcodeproj::XCScheme.new(scheme_path)

unit_target = project.targets.find { |t| t.name == 'FoodTrackerTests' }
ui_target = project.targets.find { |t| t.name == 'FoodTrackerUITests' }

test_action = scheme.test_action
if test_action.nil?
  puts "Adding test action..."
  # Just recreate or it's tricky to set up elements.
  # Xcodeproj::XCScheme does not have `test_action=` setter directly, we modify the XML node or use standard methods.
end

if test_action
  testables = test_action.testables
  
  has_unit = testables.any? { |t| t.buildable_references.any? { |ref| ref.target_name == 'FoodTrackerTests' } }
  unless has_unit
    testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(unit_target)
    test_action.add_testable(testable)
  end
  
  has_ui = testables.any? { |t| t.buildable_references.any? { |ref| ref.target_name == 'FoodTrackerUITests' } }
  unless has_ui
    testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(ui_target)
    test_action.add_testable(testable)
  end
  
  scheme.save_as(project_path, 'FoodTracker', true)
  puts "Updated scheme with test targets"
else
  # If TestAction is missing entirely, let's just recreate the whole scheme
  puts "Recreating scheme to include tests"
  scheme = Xcodeproj::XCScheme.new
  target = project.targets.find { |t| t.name == 'FoodTracker' }
  scheme.add_build_target(target)
  scheme.set_launch_target(target)
  
  testable_unit = Xcodeproj::XCScheme::TestAction::TestableReference.new(unit_target)
  testable_ui = Xcodeproj::XCScheme::TestAction::TestableReference.new(ui_target)
  
  scheme.test_action.add_testable(testable_unit)
  scheme.test_action.add_testable(testable_ui)
  
  scheme.save_as(project_path, 'FoodTracker', true)
  puts "Created new scheme with test targets"
end
