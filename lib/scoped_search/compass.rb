  base = File.join(File.dirname(__FILE__), '..')
  styles = File.join(base, 'vendor', 'assets', 'stylesheets')
  ::Compass::Frameworks.register('scoped_search', :path => base, :stylesheets_directory => styles)
