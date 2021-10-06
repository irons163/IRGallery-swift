Pod::Spec.new do |spec|
  spec.name         = "IRGallery-swift"
  spec.version      = "1.0.0"
  spec.summary      = "A powerful photo gallery of iOS."
  spec.description  = "A powerful photo gallery of iOS."
  spec.homepage     = "https://github.com/irons163/IRGallery-swift.git"
  spec.license      = "MIT"
  spec.author       = "irons163"
  spec.platform     = :ios, "14.0"
  spec.source       = { :git => "https://github.com/irons163/IRGallery-swift.git", :tag => spec.version.to_s }
  spec.source_files  = "IRGallery-swift/**/*.{h,m,swift}"
  spec.resources = ["IRGallery-swift/**/*.xib", "IRGallery-swift/**/*.xcassets"]
  spec.swift_version = '5.0'
end