require_relative 'test_helper'

class CremitaTest < Minitest::Test
  def setup
    @cremita = Cremita.new
  end

  def test_fetch_commits
    assert_equal 87, @cremita.fetch_commits('Typeform/Typeform', 'preprod-2025', 'testing-2030').length
  end
end
