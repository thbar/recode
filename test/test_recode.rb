require_relative 'helper'
require 'recode'
require 'nokogiri'

class RecodeTest < Minitest::Test
  
  def target
    'test/fixtures/output.xrns'
  end
  
  def template
    'test/fixtures/test-song.xrns'
  end
  
  def test_noop_generate
    Recode.generate(target, from: template) do |dir|
      # we should have been called here to modify the files
      assert File.exists?(dir + '/Song.xml')
    end

    # do a quick comparison, must have been a copy
    before = `unzip -l #{template} | tail -n +2 | sort`
    after = `unzip -l #{target} | tail -n +2 | sort`
    assert_equal(after, before)
  end
  
  def test_song_tweaking
    Recode.generate('test/fixtures/blank.xrns', from: template) do |dir|
      song_file = File.join(dir, 'Song.xml')
      doc = Nokogiri::XML(IO.read(song_file))
      doc.search('/RenoiseSong/PatternPool/Patterns/Pattern/Tracks/PatternTrack').each do |node|
        # note: this will crash Renoise - we must generate replacements PatternTrack here instead
        node.remove
      end
      IO.write(song_file, doc.to_xml)
    end
  end
  
  # exploratory code on xrns Song.xml format to figure out what the rules are
  def test_format_verifier
    Recode.generate('test/fixtures/format.xrns', from: template) do |dir|
      song_file = File.join(dir, 'Song.xml')
      doc = Nokogiri::XML(IO.read(song_file))
      
      # declaration of the song's tracks (optionally with effects etc)
      assert_equal ["SequencerTrack"] * 6 + ["SequencerMasterTrack"], doc.search('/RenoiseSong/Tracks/*').map(&:name)
      
      # available patterns are grouped into a pattern pool (and later referenced from the sequence)
      assert_equal 1, doc.search('/RenoiseSong/PatternPool/Patterns/Pattern').count

      # each pattern has its own length
      assert_equal 8, Integer(doc.search('/RenoiseSong/PatternPool/Patterns/Pattern[1]/NumberOfLines').text)
      
      # each pattern must have data for the exact number of tracks configured for the song (see above)
      assert_equal ["PatternTrack"] * 6 + ["PatternMasterTrack"], doc.search('/RenoiseSong/PatternPool/Patterns/Pattern[1]/Tracks/*').map(&:name)
    end
  end
  
  def test_pattern_track_generation
    track = Recode::PatternTrack.new

    track.add_line(2)
    track[2].add_note('OFF')

    track.add_line(0)
    # note hexa here!
    track[0].add_note('C-4', instrument: 0xD, volume: 0x80)
    
    expected = <<XML
<PatternTrack type="PatternTrack">
  <SelectedPresetName>Init</SelectedPresetName>
  <SelectedPresetIsModified>false</SelectedPresetIsModified>
  <Lines>
    <Line index="0">
      <NoteColumns>
        <NoteColumn>
          <Note>C-4</Note>
          <Instrument>0D</Instrument>
          <Volume>80</Volume>
        </NoteColumn>
      </NoteColumns>
      <EffectColumns>
        <EffectColumn/>
      </EffectColumns>
    </Line>
    <Line index="2">
      <NoteColumns>
        <NoteColumn>
          <Note>OFF</Note>
        </NoteColumn>
      </NoteColumns>
      <EffectColumns>
        <EffectColumn/>
      </EffectColumns>
    </Line>
  </Lines>
  <AliasPatternIndex>-1</AliasPatternIndex>
  <ColorEnabled>false</ColorEnabled>
  <Color>0,0,0</Color>
</PatternTrack>
XML

    assert_equal expected.chomp, track.to_doc.to_xml
  end
  
  def test_pattern_master_track_generation
    track = Recode::PatternTrack.new(type: 'PatternMasterTrack')
    
    expected = <<XML
<PatternMasterTrack type="PatternMasterTrack">
  <SelectedPresetName>Init</SelectedPresetName>
  <SelectedPresetIsModified>false</SelectedPresetIsModified>
  <AliasPatternIndex>-1</AliasPatternIndex>
  <ColorEnabled>false</ColorEnabled>
  <Color>0,0,0</Color>
</PatternMasterTrack>
XML

    assert_equal expected.chomp, track.to_doc.to_xml
  end
  
  def test_generate_pattern
    Recode.generate('test/fixtures/generated.xrns', from: template) do |dir|
      song = Recode::Song.new(dir)
      assert_equal Nokogiri::XML::Document, song.doc.class
      
      pattern = song.add_pattern
      assert_equal pattern, song.pattern_pool.patterns[0]
      
      # the pattern tracks must instantiate each song track
      assert_equal 6 + 1, pattern.tracks.length
      assert_equal ['PatternTrack'], pattern.tracks[0..5].map(&:type).uniq
      assert_equal 'PatternMasterTrack', pattern.tracks[6].type
      
      # we must be able to specify the length of the pattern
      pattern.length = 64
      assert_equal 64, pattern.length
    end
  end
  
  def test_write_single_pattern_song
    Recode.generate('test/fixtures/hello.xrns', from: template) do |dir|
      song = Recode::Song.new(dir)

      pattern = song.add_pattern
      pattern.length = 8
      
      line = pattern.tracks[3].add_line(0)
      line.add_note('C-4', instrument: 0x3)

      line = pattern.tracks[3].add_line(4)
      line.add_note('C-4', instrument: 0x3)

      line = pattern.tracks[4].add_line(4)
      line.add_note('C-4', instrument: 0x4)

      song.save
      
      # put assertions on generated xml now
      doc = Nokogiri::XML(IO.read(dir + '/Song.xml'))
      assert_equal 'RenoiseSong', doc.root.name

      assert_equal 1, doc.search('/RenoiseSong/PatternPool').length
      assert_equal 1, doc.search('/RenoiseSong/PatternPool/Patterns/Pattern').length
      assert_equal 6, doc.search('/RenoiseSong/PatternPool/Patterns/Pattern[1]/Tracks/PatternTrack').length
      
      output = []
      doc.search('//PatternTrack').each_with_index do |pattern_track, pattern_track_index|
        pattern_track.search('Line').each do |line|
          line_index = line['index']
          line.search('NoteColumn').each do |note_column|
            output << {track: pattern_track_index, line: Integer(line_index), values: [note_column.children.map(&:text)]}
          end
        end
      end
      
      expected = [
        {track: 3, line: 0, values: [["C-4", "03"]]},
        {track: 3, line: 4, values: [["C-4", "03"]]},
        {track: 4, line: 4, values: [["C-4", "04"]]}
      ]

      assert_equal expected, output
    end
  end
end