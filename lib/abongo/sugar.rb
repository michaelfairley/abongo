#This module exists entirely to save finger strain for programmers.
#It is designed to be included in your ApplicationController.
#
#See abongo.rb for descriptions of what these do.

class Abongo
  module Sugar

    def ab_test(test_name, alternatives = nil, options = {})
      @choices ||= {}
      unless @choices[test_name]
        if (Abongo.options[:enable_specification] && !params[test_name].nil?)
          @choices[test_name] = params[test_name]
        elsif (Abongo.options[:enable_override_in_session] && !session[test_name].nil?)
          @choices[test_name] = session[test_name]
        elsif (Abongo.options[:enable_selection] && !params[test_name].nil?)
          @choices[test_name] = Abongo.parse_alternatives(alternatives)[params[test_name].to_i]
        elsif (alternatives.nil?)
          begin
            @choices[test_name] = Abongo.flip(test_name, options)
          rescue
            if Abongo.options[:failsafe]
              @choices[test_name] = true
            else
              raise
            end
          end
        else
          begin
            @choices[test_name] = Abongo.test(test_name, alternatives, options)
          rescue
            if Abongo.options[:failsafe]
              @choices[test_name] = Abongo.parse_alternatives(alternatives).first
            else
              raise
            end
          end
        end
      end

      if block_given?
        yield(@choices[test_name])
      else
        @choices[test_name]
      end
    end
    
    def bongo!(test_name, options = {})
      begin
        Abongo.bongo!(test_name, options)
      rescue
        if Abongo.options[:failsafe]
          return
        else
          raise
        end
      end
    end
    
    #Mark the user as a human.
    def abongo_mark_human
      textual_result = "1"
      begin
        a = params[:a].to_i
        b = params[:b].to_i
        c = params[:c].to_i
        if (request.method == :post && (a + b == c))
          Abongo.human!
        else
          textual_result = "0"
        end
      rescue #If a bot doesn't pass a, b, or c, to_i will fail.  This scarfs up the exception, to save it from polluting our logs.
        textual_result = "0"
      end
      render :text => textual_result, :layout => false #Not actually used by browser
      
    end
  end
end
