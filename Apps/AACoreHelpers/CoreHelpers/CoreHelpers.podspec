Pod::Spec.new do |s|
  s.name         = "CoreHelpers"
  s.version      = "1.0.0"
  s.summary      = "A framework providing core helper utilities for iOS/macOS projects."
  s.description  = <<-DESC
                   CoreHelpers is a collection of Swift and Objective-C utilities for application management, method swizzling, and more.
                   DESC
  s.homepage     = "https://github.com/awasthi027/"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Ashish Awasthi" => "myemail.awasthi@gmail.com" }
  s.platform     = :ios, "16.0"
  s.source       = { :git => "https://github.com/yourusername/CoreHelpers.git", :tag => s.version }
  s.source_files = "Sources/CoreHelpers/**/*.{h,m,swift}"
  s.public_header_files = "Sources/CoreHelpers/**/*.h"
  s.requires_arc = true
  s.swift_version = "5.0"
end
