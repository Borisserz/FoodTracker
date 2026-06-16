require 'xcodeproj'
project = Xcodeproj::Project.open('FoodTracker.xcodeproj')
widget_target = project.targets.find { |t| t.name == 'FoodTrackerWidgetExtension' }

files_to_add = [
  'FoodTrackerWidgetExtension/WidgetIntents.swift',
  'FoodTrackerWidgetExtension/WidgetTimelineProvider.swift',
  'FoodTrackerWidgetExtension/WidgetViews.swift'
]

group = project.main_group.find_subpath('FoodTrackerWidgetExtension', false)

files_to_add.each do |file_path|
  filename = File.basename(file_path)
  # Check if reference already exists
  ref = group.files.find { |f| f.path == filename }
  unless ref
    ref = group.new_file(filename)
  end
  # Add to build phase if not already there
  unless widget_target.source_build_phase.files_references.include?(ref)
    widget_target.source_build_phase.add_file_reference(ref)
  end
end

project.save
puts "Successfully added widget files to target!"
