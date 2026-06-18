require 'xcodeproj'
project_path = '/Users/borisserzhanovich/projects/FoodTracker/FoodTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'FoodTracker' }

file_path = 'FoodTracker/Services/LocalFoodDatabaseService.swift'
group = project.main_group.find_subpath(File.dirname(file_path), true)
group.set_source_tree('SOURCE_ROOT')

file_ref = group.new_file(File.basename(file_path))
target.add_file_references([file_ref])

project.save
puts "Added LocalFoodDatabaseService.swift to project!"
