# Adds the three Screen Time extensions to Runner.xcodeproj and switches the
# app to its Screen Time entitlements. Run from app/ios:
#
#   ruby scripts/screen_time.rb
#
# CI runs this for the Screen Time build; the committed project stays
# without it, so a TestFlight build works before Apple approves the Family
# Controls distribution entitlement. Idempotent. Needs the xcodeproj gem.
require 'xcodeproj'

PROJECT = File.expand_path('../Runner.xcodeproj', __dir__)
EXTENSIONS = [
  # target name, bundle id suffix (the App IDs registered on 23 Sep 2026)
  ['GuardMonitor', 'monitor'],
  ['GuardShield', 'shieldconfig'],
  ['GuardShieldAction', 'shieldaction'],
].freeze

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == 'Runner' } or abort('no Runner target')
shared = project.files.find { |f| f.path.to_s.end_with?('GateShared.swift') } or abort('GateShared.swift is not in the project')

# Extensions go in before Thin Binary, or Xcode reports a build cycle with Flutter's script phase.
embed = app.copy_files_build_phases.find { |ph| ph.name == 'Embed Foundation Extensions' }
unless embed
  embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed.name = 'Embed Foundation Extensions'
  embed.symbol_dst_subfolder_spec = :plug_ins
  thin = app.build_phases.index { |ph| ph.respond_to?(:name) && ph.name == 'Thin Binary' } || app.build_phases.length
  app.build_phases.insert(thin, embed)
end

EXTENSIONS.each do |name, suffix|
  target = project.targets.find { |t| t.name == name }
  unless target
    target = project.new_target(:app_extension, name, :ios, '16.0', nil, :swift)
    group = project.main_group.find_subpath(name, true)
    group.set_source_tree('<group>')
    group.set_path(name)
    source = group.files.find { |f| f.path == "#{name}.swift" } || group.new_reference("#{name}.swift")
    target.add_file_references([source, shared])
    %w[Info.plist].each { |f| group.new_reference(f) unless group.files.any? { |x| x.path == f } }
    group.new_reference("#{name}.entitlements") unless group.files.any? { |x| x.path == "#{name}.entitlements" }
  end

  target.build_configurations.each do |config|
    base = app.build_configurations.find { |c| c.name == config.name } || app.build_configurations.first
    config.base_configuration_reference = base.base_configuration_reference
    s = config.build_settings
    s['PRODUCT_NAME'] = '$(TARGET_NAME)'
    s['PRODUCT_BUNDLE_IDENTIFIER'] = "$(APP_BUNDLE_ID).#{suffix}"
    s['INFOPLIST_FILE'] = "#{name}/Info.plist"
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['CODE_SIGN_ENTITLEMENTS'] = "#{name}/#{name}.entitlements"
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    s['SWIFT_VERSION'] = '5.0'
    s['TARGETED_DEVICE_FAMILY'] = '1,2'
    s['SKIP_INSTALL'] = 'YES'
    s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  end

  app.add_dependency(target) unless app.dependencies.any? { |d| d.target == target }
  unless embed.files_references.include?(target.product_reference)
    build_file = embed.add_file_reference(target.product_reference)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
end

app.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner-ScreenTime.entitlements'
end
project.build_configurations.each { |c| c.build_settings['GUARD_SCREEN_TIME'] = 'YES' }

project.save
puts "Screen Time enabled: #{EXTENSIONS.map(&:first).join(', ')} embedded in Runner."
