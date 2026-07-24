#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"

project_path = File.expand_path("../70K Bands.xcodeproj", __dir__)
project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == "MMF Bands" }
  puts "MMF Bands target already exists"
  exit 0
end

mdf = project.targets.find { |t| t.name == "MDF Bands" }
raise "MDF Bands target not found" unless mdf

mmf = project.new_target(:application, "MMF Bands", :ios, "16.0")
mmf.product_type = mdf.product_type

mdf.source_build_phase.files.each do |file|
  mmf.source_build_phase.add_file_reference(file.file_ref)
end

mdf.resources_build_phase.files.each do |file|
  name = file.file_ref&.path.to_s
  next if %w[Info-MDF.plist GoogleService-Info-MDF.plist UILaunchScreen-MDF.xib].include?(name)
  mmf.resources_build_phase.add_file_reference(file.file_ref)
end

bands_group = project.main_group["70000TonsBands"]
root_group = project.main_group

firebase_ref = root_group.find_file_by_path("GoogleService-Info-MMF.plist")
firebase_ref ||= root_group.new_file("GoogleService-Info-MMF.plist")

info_ref = bands_group.find_file_by_path("Info-MMF.plist")
info_ref ||= bands_group.new_file("Info-MMF.plist")

launch_ref = bands_group.find_file_by_path("UILaunchScreen-MMF.xib")
launch_ref ||= bands_group.new_file("UILaunchScreen-MMF.xib")

[firebase_ref, info_ref, launch_ref].each do |ref|
  mmf.resources_build_phase.add_file_reference(ref)
end

mdf.frameworks_build_phase.files.each do |file|
  mmf.frameworks_build_phase.add_file_reference(file.file_ref)
end

mdf.package_product_dependencies.each do |dep|
  mmf.package_product_dependencies << dep
end

mdf.shell_script_build_phases.each do |phase|
  new_phase = mmf.new_shell_script_build_phase(phase.name)
  new_phase.shell_script = phase.shell_script
  new_phase.input_paths.replace(phase.input_paths)
  new_phase.output_paths.replace(phase.output_paths)
end

mdf.build_configurations.each do |mdf_config|
  mmf_config = mmf.build_configurations.find { |c| c.name == mdf_config.name }
  mmf_config.build_settings.merge!(mdf_config.build_settings)
  mmf_config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.rdorn.mmfbands"
  mmf_config.build_settings["INFOPLIST_FILE"] = "70000TonsBands/Info-MMF.plist"
  mmf_config.build_settings["INFOPLIST_KEY_CFBundleDisplayName"] = "MMF Bands!"
  mmf_config.build_settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "FESTIVAL_MMF"
end

project.save

scheme_path = File.expand_path("xcshareddata/xcschemes/MMF Bands.xcscheme", project_path)
if File.exist?(scheme_path)
  scheme = File.read(scheme_path).gsub("MMF_TARGET_ID_PLACEHOLDER", mmf.uuid)
  File.write(scheme_path, scheme)
end

puts "Added MMF Bands target (id: #{mmf.uuid})"
