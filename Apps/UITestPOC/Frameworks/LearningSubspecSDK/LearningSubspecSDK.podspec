Pod::Spec.new do |s|
    s.name         = "LearningSubspecSDK"
    s.module_name  = "LearningSubspecSDK"
    s.version      = "1.0.0"
    s.summary      = "Creating SDK to learn Extension and feature flag and subspec conncept"
    s.homepage     = "https://github.com/awasthi027/POC_Apps"
    s.authors      = { "Email" => "myemail.awasthi027@gmail.com", "Name" => "Ashish Awasthi" }

    s.requires_arc = true
    s.platform     = :ios
    s.ios.deployment_target = "16.0"
    s.default_subspecs = "Core", "Network", "SDKBasicInfo"
    s.source        = { :git => "https://github.com/awasthi027/POC_Apps.git", :tag => "#{s.version}" }
    s.swift_version = '5'

    s.subspec "Core" do |core|
        core.source_files  = "LearningSubspecSDK/**/*.{h,m,mm,c,swift}"
        
        core.dependency  "api-ios",                            "2.0.0"
        core.libraries = 'c++'
        core.pod_target_xcconfig = {
            "OTHER_CFLAGS" => "-fstack-protector-all",
            'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
            'CLANG_CXX_LIBRARY' => 'libc++'
        }
    end

   s.subspec "SDKBasicInfo" do |basicInfo|
      basicInfo.dependency "LearningSubspecSDK/Core"
      basicInfo.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "$(inherited) -DBasic_Info" }
   end

   s.subspec 'Network' do |network|
     network.dependency "LearningSubspecSDK/Core"
     network.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "$(inherited) -DNetwork" }
   end

   s.subspec 'AutomationSupports' do |automation|
     automation.dependency "LearningSubspecSDK/Core"
     automation.pod_target_xcconfig = { "OTHER_SWIFT_FLAGS" => "$(inherited) -DAutomationSupports" }
   end

end
