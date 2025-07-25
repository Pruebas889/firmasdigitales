# frozen_string_literal: true

class UserConfigsController < ApplicationController
  before_action :load_user_config
  authorize_resource :user_config

  ALLOWED_KEYS = [
    UserConfig::RECEIVE_COMPLETED_EMAIL,
    UserConfig::SHOW_APP_TOUR
  ].freeze

  InvalidKey = Class.new(StandardError)

  def create
    @user_config.update!(user_config_params)

    head :ok
  end

  private

  def load_user_config
    raise InvalidKey unless ALLOWED_KEYS.include?(user_config_params[:key])

    @user_config =
      UserConfig.find_or_initialize_by(user: current_user, key: user_config_params[:key])
  end

  def user_config_params
    params.require(:user_config).permit(:key, :value, { value: {} }, { value: [] }).tap do |attrs|
      attrs[:value] = attrs[:value] == '1' if attrs[:value].in?(%w[1 0])
      attrs[:value] = attrs[:value] == 'true' if attrs[:value].in?(%w[true false])
    end
  end
end