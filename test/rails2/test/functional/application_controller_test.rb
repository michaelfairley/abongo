require 'test_helper'

class ApplicationControllerTest < ActionController::TestCase
  test "the truth" do
    get 'test1'
    assert_select '#test', /a|b/
  end
end
