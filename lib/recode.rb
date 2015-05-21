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

  class NoteColumn
    attr_accessor :note, :instrument, :volume
    def initialize(note, instrument:, volume:)
      @note = note
      @instrument = instrument
      @volume = volume
    end
  end
  
  class PatternTrackLine
    attr_accessor :notes
    
    def initialize
      @notes = []
    end
    
    def add_note(node, instrument: nil, volume: nil)
      notes.push(NoteColumn.new(node, instrument: instrument, volume: volume))
    end
  end
  
  class PatternTrack
    attr_accessor :lines, :type
    
    ALLOWED_TYPES = %w[PatternTrack PatternMasterTrack]
    
    def initialize(type: self.class.name.split('::').last)
      @lines = []
      fail "Invalid type #{type}" unless ALLOWED_TYPES.include?(type)
      @type = type
    end
    
    def add_line(index)
      fail "Line already added at index #{index}" if lines[index]
      lines[index] = Recode::PatternTrackLine.new
    end

    def [](index)
      lines[index]
    end
    
    def to_doc
      builder = Nokogiri::XML::Builder.new do |x|
        x.send(type, type: type) do
          x.SelectedPresetName 'Init'
          x.SelectedPresetIsModified false
          unless lines.empty?
            x.Lines do
              lines.each_with_index do |line,index|
                next unless line
                x.Line(index: index) do
                  x.NoteColumns do
                    line.notes.each do |note|
                      x.NoteColumn do
                        x.Note(note.note)
                        x.Instrument('%02X' % note.instrument) if note.instrument
                        x.Volume('%02x' % note.volume) if note.volume
                      end
                    end
                  end
                  x.EffectColumns do
                    x.EffectColumn # not supported yet
                  end
                end
              end
            end
          end
          x.AliasPatternIndex -1
          x.ColorEnabled false
          x.Color [0, 0, 0].join(',')
        end
      end
      builder.doc.root
    end
  end
end