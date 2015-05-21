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
    
end