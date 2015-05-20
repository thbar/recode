require 'logger'

module Recode
  def self.logger
    @logger ||= begin
      l = Logger.new(STDOUT)
      l.level = Logger::WARN
      l
    end
  end
  
  def self.system!(command)
    logger.debug "Running #{command}"
    fail "Command #{command} failed" unless system(command)
  end
  
  # unpack a xrns file, allow us to modify it, then repack it
  def self.generate(target, from:)
    fail "Source #{from.inspect} doesn't exist" unless File.exists?(from)
    FileUtils.rm(target) if File.exists?(target)
    Dir.mktmpdir('recode') do |dir|
      system!("unzip -q #{from} -d #{dir}")
      # leave the caller with the opportunity to modify the file
      yield dir
      # see http://superuser.com/a/119661/83592
      # expand for chdir + zip to work
      target = File.expand_path(target)
      Dir.chdir(dir) do
        system!("zip -q -r -D #{target} *")
      end
    end
  end
end