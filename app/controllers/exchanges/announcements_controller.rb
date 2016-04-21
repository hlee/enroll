class Exchanges::AnnouncementsController < ApplicationController
  before_action :check_hbx_staff_role

  def index
    @announcements = Announcement.current
  end

  def create
    @announcement = Announcement.new(announcement_params)
    if @announcement.save
      redirect_to exchanges_announcements_path, notice: 'Create Announcement Successful.'
    else
      redirect_to exchanges_announcements_path, notice: 'Create Announcement Failure.'
    end
  end

  def destroy
    @announcement = Announcement.find_by(id: params[:id])
    @announcement.destroy
    redirect_to exchanges_announcements_path, notice: 'Destroy Announcement Successful.'
  end

  private
  def announcement_params
    params.require(:announcement).permit(
      :content, :start_date, :end_date,
      :audiences => []
    )
  end

  def check_hbx_staff_role
    unless current_user.has_hbx_staff_role?
      redirect_to root_path, :flash => { :error => "You must be an HBX staff member" }
    end
  end
end
