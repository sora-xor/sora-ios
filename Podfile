platform :ios, '9.0'

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
  pod 'CommonWallet'
  pod 'Firebase/Core', :inhibit_warnings => true
  pod 'Firebase/Messaging', :inhibit_warnings => true
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'ReachabilitySwift'
  pod 'SwiftyBeaver'
  pod 'SKPhotoBrowser'
  pod 'SoraFoundation', '~> 0.4.0'

  target 'SoraPassportTests' do
      inherit! :search_paths
      
      pod 'Cuckoo'
      pod 'FireMock'
      pod 'SoraUI'
      pod 'SoraDocuments'
      pod 'SoraCrypto'
      pod 'SoraKeystore'
      pod 'RobinHood'
      pod 'IrohaCommunication'
      pod 'CommonWallet'
      pod 'SoraFoundation', '~> 0.4.0'
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
