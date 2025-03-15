# Define platform
platform :ios, '13.0'

target 'TrustPact' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Firebase dependencies
  pod 'FirebaseAuth', '10.18.0'
  pod 'FirebaseFirestore', '10.18.0'
  pod 'FirebaseStorage', '10.18.0'
  pod 'FirebaseFirestoreSwift', '10.18.0'

  target 'TrustPactTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'TrustPactUITests' do
    # Pods for UI testing
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    # Set deployment target to iOS 13.0 for all targets
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      
      # Exclude arm64 for simulator builds
      if config.build_settings['SDKROOT'] == 'iphonesimulator'
        config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      end
      
      # Specific fixes for BoringSSL-GRPC when building for simulator
      if target.name == 'BoringSSL-GRPC' && config.build_settings['SDKROOT'] == 'iphonesimulator'
        # Disable debug symbols generation
        config.build_settings['GCC_GENERATE_DEBUGGING_SYMBOLS'] = 'NO'
        
        # Set debug information format to dwarf
        config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
        
        # Set C flags to use -g0 and exclude -G
        if config.build_settings['OTHER_CFLAGS']
          config.build_settings['OTHER_CFLAGS'] = config.build_settings['OTHER_CFLAGS'].gsub(/-G\b/, '') + ' -g0'
        else
          config.build_settings['OTHER_CFLAGS'] = '-g0'
        end
        
        # Set C++ flags to use -g0 and exclude -G
        if config.build_settings['OTHER_CPLUSPLUSFLAGS']
          config.build_settings['OTHER_CPLUSPLUSFLAGS'] = config.build_settings['OTHER_CPLUSPLUSFLAGS'].gsub(/-G\b/, '') + ' -g0'
        else
          config.build_settings['OTHER_CPLUSPLUSFLAGS'] = '-g0'
        end
      end
    end
  end
  
  # Direct patch for the project.pbxproj file to fix the -GCC_WARN_INHIBIT_ALL_WARNINGS issue
  project_pbxproj_path = installer.pods_project.path.to_s + '/project.pbxproj'
  if File.exist?(project_pbxproj_path)
    puts "Patching project.pbxproj to fix BoringSSL-GRPC -G flag issue..."
    project_pbxproj_content = File.read(project_pbxproj_path)
    modified_content = project_pbxproj_content.gsub('-GCC_WARN_INHIBIT_ALL_WARNINGS', ' GCC_WARN_INHIBIT_ALL_WARNINGS')
    File.write(project_pbxproj_path, modified_content)
    puts "Patching complete!"
  else
    puts "Warning: Could not find project.pbxproj at #{project_pbxproj_path}"
  end
end

