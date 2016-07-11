require_relative 'test_helper'

class CremitaTest < Minitest::Test
  def setup
    @cremita = Cremita.new(argv: ['Typeform/Typeform', 'preprod-2025', 'testing-2030'])
  end

  # def test_fetch_commits
  #   assert_equal 87, @cremita.fetch_commits('Typeform/Typeform', 'preprod-2025', 'testing-2030').length
  # end

  # def test_otput
  #   out, err = capture_io do
  #     @cremita.run
  #   end
  #
  #   puts out
    # assert_equal 'sdfdsfsdf', out
    # assert_output(stdout = File.read('./output.txt')) { out }
  # end
end
