require 'xcodeproj'

project_path = 'FoodTracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'FoodTracker' }

existing = target.shell_script_build_phases.find { |p| p.name == 'Firebase Crashlytics' }
if existing
  puts "Already exists"
else
  phase = target.new_shell_script_build_phase('Firebase Crashlytics')
  phase.shell_script = '"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"'
  phase.input_paths = [
    '${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}',
    '${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}',
    '${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist'
  ]
  project.save
  puts "Added Crashlytics run script"
end
