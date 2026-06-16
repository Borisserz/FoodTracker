require 'xcodeproj'
project = Xcodeproj::Project.open('FoodTracker.xcodeproj')
widget_target = project.targets.find { |t| t.name == 'FoodTrackerWidgetExtension' }

files_to_share = [
  'FoodTracker/Models/SharedModelContainer.swift',
  'FoodTracker/Models/DataModels.swift',
  'FoodTracker/Models/DietModel.swift',
  'FoodTracker/Models/SmartPlanModels.swift',
  'FoodTracker/Models/UserModel.swift'
]

files_to_share.each do |file_path|
  ref = project.main_group.new_reference(file_path)
  widget_target.source_build_phase.add_file_reference(ref)
end

project.save
puts "Successfully shared models with widget extension!"
