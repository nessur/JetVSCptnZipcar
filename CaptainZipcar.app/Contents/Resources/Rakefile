  require 'rubygems'
  require 'bundler/setup' # Releasy requires require that your application uses bundler.
  require 'releasy'

  #<<<
  Releasy::Project.new do
    name "My Application"
    version "1.3.2"
    verbose # Can be removed if you don't want to see all build messages.

    executable "bin/my_application.rb"
    files ["lib/**/*.rb", "config/**/*.yml", "media/**/*.*", "*.rb"]
    # exposed_files "README.html", "LICENSE.txt"
    add_link "http://my_application.github.com", "My Application website"
    exclude_encoding # Applications that don't use advanced encoding (e.g. Japanese characters) can save build size with this.

    # Create a variety of releases, for all platforms.
    add_build :osx_app do
      url "com.github.my_application"
      wrapper "wrappers/gosu-mac-wrapper-0.7.41.tar.gz" # Assuming this is where you downloaded this file.
      icon "media/icon.icns"
      add_package :tar_gz
    end
  end