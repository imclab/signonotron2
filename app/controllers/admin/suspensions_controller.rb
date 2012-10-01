class Admin::SuspensionsController < Admin::BaseController
  before_filter :set_user

  respond_to :html

  def edit
  end

  def update
    if params[:user][:suspended] == "1"
      @user.suspend!(params[:user][:reason_for_suspension])
      results = SuspensionUpdater.new(@user, @user.applications_used).attempt
      @successes, @failures = results[:successes], results[:failures]
    else
      @user.unsuspend!
      redirect_to admin_users_path
    end
    state = @user.suspended? ? "Suspended" : "Active"
    flash[:notice] = "#{@user.name} is now #{state}"
  end

  private
    def set_user
      @user = User.find(params[:id])
    end
end
