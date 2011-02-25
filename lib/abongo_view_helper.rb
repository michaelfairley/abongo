#Gives you easy syntax to use ABongo in your views.

module AbongoViewHelper

  def ab_test(test_name, alternatives = nil, options = {}, &block)

    if (Abongo.options[:enable_specification] && !params[test_name].nil?)
      choice = params[test_name]
    elsif (Abongo.options[:enable_override_in_session] && !session[test_name].nil?)
      choice = session[test_name]
    elsif (Abongo.options[:enable_selection] && !params[test_name].nil?)
      choice = alternatives[params[test_name].to_i]
    elsif (alternatives.nil?)
      choice = Abongo.flip(test_name, options)
    else
      choice = Abongo.test(test_name, alternatives, options)
    end

    if block
      content_tag = capture(choice, &block)
      Rails::VERSION::MAJOR <= 2 and block_called_from_erb?(block) ? concat(content_tag) : content_tag
    else
      choice
    end
  end

  def bongo!(test_name, options = {})
    Abongo.bongo!(test_name, options)
  end

  #This causes an AJAX post against the URL.  That URL should call Abongo.human!
  #This guarantees that anyone calling Abongo.human! is capable of at least minimal Javascript execution, and thus is (probably) not a robot.
  def include_humanizing_javascript(url = "/abongo_mark_human", style = :prototype)
    script = nil
    if (style == :prototype)
      script = "var a=Math.floor(Math.random()*11); var b=Math.floor(Math.random()*11);var x=new Ajax.Request('#{url}', {parameters:{a: a, b: b, c: a+b}})"
    elsif (style == :jquery)
      script = "var a=Math.floor(Math.random()*11); var b=Math.floor(Math.random()*11);var x=jQuery.post('#{url}', {a: a, b: b, c: a+b})"
    end
    script.nil? ? "" : %Q|<script type="text/javascript">#{script}</script>|.html_safe
  end
  
end
