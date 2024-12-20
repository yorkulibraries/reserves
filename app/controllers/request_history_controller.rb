# frozen_string_literal: true

class RequestHistoryController < ApplicationController
  before_action :set_request
  authorize_resource User
  # skip_authorization_check

  def index 
    associated_audits = @request.associated_audits.where.not(associated_type: 'item')

    request_audits = @request.audits.where(auditable_type: 'Request', associated_id: nil, associated_type: nil)

    @audits = (associated_audits + request_audits).sort_by(&:created_at)

    @audits_grouped = @audits.reverse.group_by { |audit| audit.created_at.at_beginning_of_day }

    @users = User.all
    @locations = Location.active

    render partial: 'history_log', layout: false if request.xhr?
  end

  def item_history
    item_id = params[:item_id]
    @audits = @request.audits.where(associated_type: 'item', associated_id: item_id.to_i).order(created_at: :desc)
  
    @audits_grouped = @audits.reverse.group_by { |a| a.created_at.at_beginning_of_day }
    
    @users = User.all
    @locations = Location.active

    render partial: 'history_log', layout: false if request.xhr?
  end
  


  def create
    # @aud = Audited::Adapters::ActiveRecord::Audit.new
    @item_id = params[:item_id]
    @aud = Audited::Audit.new
    @aud.action = 'note'
    @aud.user = current_user
    @aud.auditable = @request
    @aud.audited_changes = 'Note Added'
    @aud.comment = params[:audit_comment]

    if @item_id.present?
      @aud.associated_id = @item_id
      @aud.associated_type = "item"
    end


    respond_to do |format|
      redirect_path = @item_id.present? ? item_history_request_path(@request, item_id: @item_id) : history_request_path(@request)
      if @aud.comment.blank?
        format.html { redirect_to redirect_path, alert: 'Note is blank. Nothing updated' }
        format.js
      elsif @aud.comment.length > 255
        format.html { redirect_to redirect_path, alert: 'Note is more than 255 characters!' }
        format.js
      elsif @aud.save
        format.html { redirect_to redirect_path, notice: 'Note saved' }
        format.js
      else
        format.html { redirect_to redirect_path, alert: 'Note not saved. Please contact application administrator' }
      end
    end
  end

  private

  def set_request
    @request = Request.find(params[:id])
  end
end
