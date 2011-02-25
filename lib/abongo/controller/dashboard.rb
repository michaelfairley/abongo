class Abongo
  module Controller
    module Dashboard

      if Rails::VERSION::MAJOR <= 2
        ActionController::Base.view_paths.unshift File.join(File.dirname(__FILE__), "../views")
      else
        ActionController::Base.prepend_view_path File.join(File.dirname(__FILE__), "../views")
      end
      
      def index
        @experiments = Abongo.all_tests.map{|e| {'participants' => 0, 'conversions' => 0}.merge(e)}
        render :template => 'dashboard/index'
      end

      def end_experiment
        @alternative = Abongo.get_alternative(params[:id])
        @experiment = Abongo.get_test(@alternative['test'])
        Abongo.end_experiment! @experiment['name'], @alternative['content']
        redirect_to :back
      end
    end
  end
end
