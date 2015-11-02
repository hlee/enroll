class WelcomeController < ApplicationController
  skip_before_filter :require_login
  respond_to :js, only: [:test]

  def index

  end

  def form_template
  	# created for generic form template access at '/templates/form-template'
  end

  def test
    respond_with "hello"
  end
end
