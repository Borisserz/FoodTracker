require 'xcodeproj'

project_path = 'FoodTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

group = project.main_group.find_subpath('FoodTracker', false) || project.main_group
target = project.targets.first

Dir.glob('FoodTracker/*.json').each do |file_path|
  file_name = File.basename(file_path)
  
  unless group.files.any? { |f| f.path == file_name || f.name == file_name }
    puts "Adding #{file_name}"
    file_ref = group.new_reference(file_name)
    target.add_resources([file_ref])
  end
end

project.save
puts "Done"
