# app/controllers/reports_controller.rb
# frozen_string_literal: true


class ReportsController < ApplicationController
  before_action :authorize_report_access
  before_action :authenticate_user!


  def index
    from = params[:from_date].present? ? Date.parse(params[:from_date]) : Date.today
    to   = params[:to_date].present? ? Date.parse(params[:to_date]) : Date.today


    scope = Submission.all
    scope = scope.where(created_at: from.beginning_of_day..to.end_of_day)


    # Estadísticas generales
    @total_submissions = scope.count
    @approved_submissions = scope.merge(Submission.completed).count
    @pending_submissions = scope.merge(Submission.pending_not_expired).count
    @expired_submissions = scope.merge(Submission.expired).count
    @rejected_submissions = scope.merge(Submission.declined).count
    @partially_completed_submissions = scope.merge(Submission.partially_completed_status).count
    @opened_submissions_es = scope.merge(Submission.opened_status).count
    @sent_submissions = scope.merge(Submission.sent_but_not_interacted).count


    # Gráfico de estado
    @status_data = {
      'Completado' => @approved_submissions,
      'Rechazado' => @rejected_submissions,
      'Expirado' => @expired_submissions,
      'Parcialmente Completado' => @partially_completed_submissions,
      'Enviado sin interaccion' => @sent_submissions,
      'Abierto' => @opened_submissions_es
    }


    # Gráfico anual
    start_of_year = Date.today.beginning_of_year
    end_of_current_month = Date.today.end_of_month
 
    scope_all = Submission.all


    @monthly_data = scope_all
      .group_by_month(:created_at, format: "%b %Y", range: start_of_year..end_of_current_month)
      .count


    date_range = from.beginning_of_day..to.end_of_day
   
    # Estadísticas por miembro
    @member_usage = User
      .joins("LEFT JOIN submissions ON submissions.created_by_user_id = users.id AND submissions.created_at BETWEEN '#{date_range.first}' AND '#{date_range.last}'")
      .group("users.id, users.first_name")
      .select(
        "users.id AS id",
        "users.first_name AS first_name",
        "users.last_name AS last_name",
        "COUNT(submissions.id) AS sent",
        "SUM(CASE WHEN submissions.id IN (#{Submission.completed.select(:id).to_sql}) THEN 1 ELSE 0 END) AS completed",
        "SUM(CASE WHEN submissions.id IN (#{Submission.declined.select(:id).to_sql}) THEN 1 ELSE 0 END) AS declined",
        "SUM(CASE WHEN submissions.id IN (#{Submission.expired.select(:id).to_sql}) THEN 1 ELSE 0 END) AS expired",
        "SUM(CASE WHEN submissions.id IN (#{Submission.opened_status.select(:id).to_sql}) THEN 1 ELSE 0 END) AS opened",
        "SUM(CASE WHEN submissions.id IN (#{Submission.partially_completed_status.select(:id).to_sql}) THEN 1 ELSE 0 END) AS partially_completed",
        "SUM(CASE WHEN submissions.id IN (#{Submission.archived.select(:id).to_sql}) THEN 1 ELSE 0 END) AS archived"
      )
      .where("users.role != 'viewer'")


    user_scope = Submission.where(created_by_user_id: current_user.id)
    user_scope = user_scope.where(created_at: from.beginning_of_day..to.end_of_day) if from && to


    @total_submissions_user = user_scope.count
    @approved_submissions_user = user_scope.merge(Submission.completed).count
    @pending_submissions_user = user_scope.merge(Submission.pending_not_expired).count
    @expired_submissions_user = user_scope.merge(Submission.expired).count
    @rejected_submissions_user = user_scope.merge(Submission.declined).count
    @partially_completed_submissions_user = user_scope.merge(Submission.partially_completed_status).count
    @opened_submissions_user = user_scope.merge(Submission.opened_status).count
    @sent_submissions_user = user_scope.merge(Submission.sent_but_not_interacted).count


    # Determinar datos individuales o por usuario seleccionado
    if params[:user_id].present?
      user_scope = Submission.where(created_by_user_id: params[:user_id])
      user_scope = user_scope.where(created_at: from.beginning_of_day..to.end_of_day) if from && to
      @total_submissions_user = user_scope.count
      @approved_submissions_user = user_scope.merge(Submission.completed).count
      @pending_submissions_user = user_scope.merge(Submission.pending_not_expired).count
      @expired_submissions_user = user_scope.merge(Submission.expired).count
      @rejected_submissions_user = user_scope.merge(Submission.declined).count
      @partially_completed_submissions_user = user_scope.merge(Submission.partially_completed_status).count
      @opened_submissions_user = user_scope.merge(Submission.opened_status).count
      @sent_submissions_user = user_scope.merge(Submission.sent_but_not_interacted).count
    elsif current_user.role != 'viewer'
      user_scope = Submission.where(created_by_user_id: current_user.id)
      user_scope = user_scope.where(created_at: from.beginning_of_day..to.end_of_day) if from && to
      @total_submissions_user = user_scope.count
      @approved_submissions_user = user_scope.merge(Submission.completed).count
      @pending_submissions_user = user_scope.merge(Submission.pending_not_expired).count
      @expired_submissions_user = user_scope.merge(Submission.expired).count
      @rejected_submissions_user = user_scope.merge(Submission.declined).count
      @partially_completed_submissions_user = user_scope.merge(Submission.partially_completed_status).count
      @opened_submissions_user = user_scope.merge(Submission.opened_status).count
      @sent_submissions_user = user_scope.merge(Submission.sent_but_not_interacted).count
    else
      @total_submissions_user = 0
      @approved_submissions_user = 0
      @pending_submissions_user = 0
      @expired_submissions_user = 0
      @rejected_submissions_user = 0
      @partially_completed_submissions_user = 0
      @opened_submissions_user = 0
      @sent_submissions_user = 0
    end


    @individual_usage = {
      'Completados' => @approved_submissions_user,
      'Rechazados' => @rejected_submissions_user,
      'Expirados' => @expired_submissions_user,
      'Parcialmente Completados' => @partially_completed_submissions_user,
      'Enviado sin interaccion' => @sent_submissions_user,
      'Abiertos' => @opened_submissions_user
    }
  end
 
  rescue_from CanCan::AccessDenied do |exception|
    Rails.logger.warn "🚫 AccessDenied: #{exception.message}"
    Rails.logger.warn "🔐 Usuario actual: #{current_user&.id}, rol: #{current_user&.role}"
    Rails.logger.info "🔐 Ejecutando autorización en ReportsController"
    Rails.logger.info "🧪 current_user: #{current_user.inspect}"
    Rails.logger.info "🔎 can?(:access, :reports) => #{can?(:access, :reports)}"
    redirect_to root_path, alert: exception.message
  end


  private


  def authorize_report_access
    Rails.logger.info "🔐 Ejecutando autorización en ReportsController"
    Rails.logger.info "🧪 current_user: #{current_user.inspect}"
    Rails.logger.info "🔎 can?(:access, :reports) => #{can?(:access, :reports)}"


    authorize! :access, :reports
  end
end
