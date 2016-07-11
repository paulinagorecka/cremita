# require 'minitest/autorun'
#
# class Foo
#   def run
#     puts 'Misio!'
#   end
# end
#
# class FooTest < Minitest::Test
#   def test_foo
#     assert_output('Misio!/n') { Foo.new.run }
#   end
# end

require 'minitest/autorun'

class Foo
  def run
    puts "Hello world!"
  end
end

class FooTest < Minitest::Test
  def test_foo
    assert_output(stdout = "Hello world!\n") { Foo.new.run }
  end

  def test_foo_other
    out, err = capture_io { Foo.new.run }

    assert_equal out, "Hello world!\n"
  end
end