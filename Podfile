platform :ios, '9.0'

source 'https://github.com/soramitsu/podspec-ios.git'
source 'https://github.com/CocoaPods/Specs.git'

abstract_target 'SoraPassportAll' do
  use_frameworks!
  
  pod 'SwiftLint'
  pod 'R.swift', :inhibit_warnings => true
  pod 'FireMock', :inhibit_warnings => true
  pod 'GCDWebServer', :inhibit_warnings => true
  pod 'IrohaCrypto'
  pod 'SoraDocuments'
  pod 'SoraCrypto'
  pod 'SoraKeystore'
  pod 'SoraUI'
  pod 'RobinHood'
  pod 'Kingfisher', :inhibit_warnings => true
  pod 'CommonWallet', :git => 'https://github.com/soramitsu/common-wallet-ios.git', :commit => 'c945b7250729129a75ff207bd439421754f72909'
  pod 'Firebase/Core', :inhibit_warnings => true
  pod 'Firebase/Messaging', :inhibit_warnings => true
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'ReachabilitySwift'
  pod 'SwiftyBeaver'
  pod 'SKPhotoBrowser'

  target 'SoraPassportTests' do
      inherit! :search_paths
      
      pod 'Cuckoo'
      pod 'FireMock'
      pod 'SoraUI'
      pod 'SoraDocuments'
      pod 'SoraCrypto'
      pod 'SoraKeystore'
      pod 'RobinHood'
  end
  
  target 'SoraPassportUITests' do
      inherit! :search_paths
  end

  target 'SoraPassport'
  
end

post_install do |installer|
  installer.pods_project.build_configuration_list.build_configurations.each do |configuration|
    configuration.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
  end
end
