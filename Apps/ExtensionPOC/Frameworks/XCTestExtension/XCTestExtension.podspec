Pod::Spec.new do |s|
    s.name         = "XCTestExtension"
    s.module_name  = "XCTestExtension"
    s.version      = "1.0.0"
    s.summary      = "Creating this framework make XCtest class extension"
    s.homepage     = "https://github.com/awasthi027/POC_Apps"
    s.authors      = { "Email" => "myemail.awasthi027@gmail.com", "Name" => "Ashish Awasthi" }

    s.requires_arc = true
    s.platform     = :ios
    s.ios.deployment_target = "16.0"
    s.default_subspecs = "Core"
    s.source        = { :git => "https://github.com/awasthi027/POC_Apps.git", :tag => "#{s.version}" }
    s.swift_version = '5'

    s.subspec "Core" do |core|
        core.source_files = "XCTestExtension/**/*.{h,m,mm,c,swift}"
        core.framework = 'XCTest'
        core.pod_target_xcconfig = {
            'FRAMEWORK_SEARCH_PATHS' => '$(PLATFORM_DIR)/Developer/Library/Frameworks'
        }
    end
end
