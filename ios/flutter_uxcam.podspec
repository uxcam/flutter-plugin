#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_uxcam'
  s.version          = '2.1.0'
  s.summary          = 'UXCam flutter plugin.'
  s.description      = <<-DESC
UXCam flutter plugin
                       DESC
  s.homepage         = 'https://www.uxcam.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'UXCam Inc' => 'admin@uxcam.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.static_framework = true
  s.dependency 'UXCam','~> 3.4.1'
  s.ios.deployment_target = '10.0'
end

