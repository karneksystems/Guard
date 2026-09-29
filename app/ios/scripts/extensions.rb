# Shared by screen_time.rb and live_activity.rb: add an app extension target
# to Runner.xcodeproj and embed it in Runner. Needs the xcodeproj gem.
require 'xcodeproj'

module GuardExtensions
  PROJECT = File.expand_path('../Runner.xcodeproj', __dir__)

  module_function

  def open
    project = Xcodeproj::Project.open(PROJECT)
    app = project.targets.find { |t| t.name == 'Runner' } or abort('no Runner target')
    [project, app]
  end

  def shared_file(project, name)
    project.files.find { |f| f.path.to_s.end_with?(name) } or abort("#{name} is not in the project")
  end

  # Extensions go in before Thin Binary, or Xcode reports a build cycle with Flutter's script phase.
  def embed_phase(project, app)
    embed = app.copy_files_build_phases.find { |ph| ph.name == 'Embed Foundation Extensions' }
    return embed if embed

    embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed.name = 'Embed Foundation Extensions'
    embed.symbol_dst_subfolder_spec = :plug_ins
    thin = app.build_phases.index { |ph| ph.respond_to?(:name) && ph.name == 'Thin Binary' } || app.build_phases.length
    app.build_phases.insert(thin, embed)
    embed
  end

  # name: target and folder; suffix: bundle id after $(APP_BUNDLE_ID).
  # entitlements: false for an extension that needs no capabilities.
  def add(project, app, name:, suffix:, shared:, deployment: '16.0', entitlements: true)
    target = project.targets.find { |t| t.name == name }
    unless target
      target = project.new_target(:app_extension, name, :ios, deployment, nil, :swift)
      group = project.main_group.find_subpath(name, true)
      group.set_source_tree('<group>')
      group.set_path(name)
      source = group.files.find { |f| f.path == "#{name}.swift" } || group.new_reference("#{name}.swift")
      target.add_file_references([source, *shared])
      group.new_reference('Info.plist') unless group.files.any? { |x| x.path == 'Info.plist' }
      if entitlements && group.files.none? { |x| x.path == "#{name}.entitlements" }
        group.new_reference("#{name}.entitlements")
      end
    end

    target.build_configurations.each do |config|
      base = app.build_configurations.find { |c| c.name == config.name } || app.build_configurations.first
      config.base_configuration_reference = base.base_configuration_reference
      s = config.build_settings
      s['PRODUCT_NAME'] = '$(TARGET_NAME)'
      s['PRODUCT_BUNDLE_IDENTIFIER'] = "$(APP_BUNDLE_ID).#{suffix}"
      s['INFOPLIST_FILE'] = "#{name}/Info.plist"
      s['GENERATE_INFOPLIST_FILE'] = 'NO'
      if entitlements
        s['CODE_SIGN_ENTITLEMENTS'] = "#{name}/#{name}.entitlements"
      else
        s.delete('CODE_SIGN_ENTITLEMENTS')
      end
      s['CODE_SIGN_STYLE'] = 'Automatic'
      s['IPHONEOS_DEPLOYMENT_TARGET'] = deployment
      s['SWIFT_VERSION'] = '5.0'
      s['TARGETED_DEVICE_FAMILY'] = '1,2'
      s['SKIP_INSTALL'] = 'YES'
      s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
    end

    embed = embed_phase(project, app)
    app.add_dependency(target) unless app.dependencies.any? { |d| d.target == target }
    unless embed.files_references.include?(target.product_reference)
      build_file = embed.add_file_reference(target.product_reference)
      build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
    end
    target
  end
end
