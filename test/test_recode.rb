require_relative 'helper'
require 'recode'

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
    
end