platform :ios, '13.0'

source 'https://github.com/soramitsu/SSFSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'

abstract_target 'SoraPassportAll' do
  use_frameworks!

  pod 'Sourcery', '~> 1.4'
  pod 'SwiftLint', '~> 0.49.0'
  pod 'R.swift', '~> 6.1.0'
  pod 'FireMock', :inhibit_warnings => true
  pod 'SoraDocuments'
  pod 'SoraKeystore'
  pod 'SoraUI'
  pod 'RobinHood', '~> 2.6.1'
  pod 'Kingfisher', :git => 'https://github.com/onevcat/Kingfisher', :branch => 'version6-xcode13', :inhibit_warnings => true
  pod 'SVGKit', :git => 'https://github.com/SVGKit/SVGKit.git', :tag => '3.0.0'
  pod 'FirebaseMessaging'
  pod 'Firebase/Crashlytics'
  pod 'FirebaseAnalytics'
  pod 'ReachabilitySwift'
  pod 'Starscream', :git => 'https://github.com/soramitsu/fearless-starscream.git', :tag => ‘4.0.9’
  pod 'SwiftyBeaver'
  pod 'SoraFoundation'
  pod 'Anchorage'
  pod 'Then'
  pod 'lottie-ios', '~> 4.4.3'  
  pod 'Nantes'
  pod 'SnapKit'
  pod 'SoraUIKit', :git => 'https://github.com/soramitsu/ios-ui', :tag => ‘1.1.12’
  pod 'IdensicMobileSDK', :http => 'https://github.com/PayWings/PayWingsOnboardingKycSDK-iOS-IdensicMobile/archive/v2.2.3.tar.gz'
  pod 'SCard', :git => 'https://github.com/sora-xor/sora-card-ios', :branch => 'release/1.5.1'
  pod 'FLEX', :configurations => ['Debug', 'Dev']
  pod 'sorawallet', :podspec => 'https://raw.githubusercontent.com/soramitsu/x-networking-old/0.2.10/lib/sorawallet/sorawallet.podspec'
  
  target 'SoraPassportTests' do
      inherit! :search_paths
      
      pod 'Cuckoo', '~> 1.9.1'
      pod 'FireMock'
      pod 'SoraUI'
      pod 'Starscream', :git => 'https://github.com/soramitsu/fearless-starscream.git', :tag => ‘4.0.9’
      pod 'SoraDocuments'
      pod 'SoraKeystore'
      pod 'RobinHood', '~> 2.6.1'
      pod 'SoraFoundation'
      pod 'GoogleAPIClientForREST/Core'
      pod 'GoogleAPIClientForREST/Drive'
      pod 'sorawallet', :podspec => 'https://raw.githubusercontent.com/soramitsu/x-networking-old/0.2.10/lib/sorawallet/sorawallet.podspec'
  end
  
  target 'SoraPassportUITests' do
      inherit! :search_paths
  end

  target 'SoraPassportIntegrationTests'

  target 'SoraPassport'
  
end

post_install do |installer|
  installer.pods_project.build_configuration_list.build_configurations.each do |configuration|
    configuration.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
  end
  installer.generated_projects.each do |project|
    project.build_configurations.each do |config|
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f <= 9.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        config.build_settings["DEVELOPMENT_TEAM"] = "YLWWUD25VZ"
        if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f <= 9.0
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
          config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
        end
      end
    end
  end
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
        config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
        config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
        config.build_settings["DEVELOPMENT_TEAM"] = "YLWWUD25VZ"
        config.build_settings['CODE_SIGN_STYLE'] = "Manual"
        config.build_settings['CODE_SIGN_IDENTITY'] = "iPhone Developer"
        xcconfig_path = config.base_configuration_reference.real_path
        xcconfig = File.read(xcconfig_path)
        xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
        File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
    end
  end
end
