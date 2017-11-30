class UsersController < ApplicationController
  require 'csv'

  # Serves users list (GET /users)
  def index
    @users = User.all
  end

  # Action for bulk user upload through CSV with headers (POST /users/bulk)
  def bulk_upload
    begin
      create_success, create_failed = bulk_create_from_csv
      filename = create_backup_csv create_success, create_failed

      # Display deatils of success and failure case in view
      bkp_link = "<a href='/#{filename.split("/").last}' download='true'>here</a>"
      flash[:success] = "#{create_success.count} #{'users'.pluralize(create_success.count)} uploaded successfully" if create_success.present?
      flash[:error] = "Failed to upload #{create_failed.count} #{'user'.pluralize(create_failed.count)}. Details #{bkp_link}" if create_failed.present?

      redirect_back(fallback_location: root_path)
    rescue => e
      Rails.logger.warn e.message
      Rails.logger.warn e.backtrace()
      flash[:error] = e.message
      redirect_to root_path
    end
  end

  private
  # Create users individually for each row to gather validation errors
  # Wrap a transaction block to revert changes in case of error
  def bulk_create_from_csv
    users = []
    errors = []
    User.transaction do
      user_params.map do |user_param|
         user = User.new user_param.to_h
         (user.save ? users : errors) << user
       end
    end

    return users, errors
  end

  # Creates a backup csv with status of each entry for bulk user upload
  # Can be made genric and moved to service klass
  def create_backup_csv users, errors
    filename = "#{Rails.root}/public/users_#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.csv"
    CSV.open(filename, "w") do |csv|
      csv << [ 'Name', 'Date', 'Number', 'Description', 'Status', 'Remarks']
      errors.each do |user|
        csv << [ user.name, user.date, user.number, user.description, 'Failed', user.errors.full_messages.join(', ')]
      end
      users.each do |user|
        csv << [ user.name, user.date, user.number, user.description, 'Success', "id: #{user.id}"]
      end
    end

    filename
  end

  def user_params
    raise 'No file found' if params[:users_csv].blank?
    raise 'Unsupported file format' unless params[:users_csv].content_type == 'text/csv'
    user_params = CSV.parse params[:users_csv].read, headers: true
    raise 'No user found' if user_params.first.blank?
    user_params
  end

end
