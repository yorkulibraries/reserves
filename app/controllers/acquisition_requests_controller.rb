# frozen_string_literal: true

class AcquisitionRequestsController < ApplicationController
  before_action :set_request, only: %i[show edit update destroy change_status send_to_acquisitions]
  authorize_resource

  def index
    @acquisition_requests = AcquisitionRequest.open.order('created_at desc')
    @recently_acquired = AcquisitionRequest.acquired.limit(200).order('acquired_at desc')
    @recently_cancelled = AcquisitionRequest.cancelled.limit(200).order('cancelled_at desc')

    if current_user.role != User::MANAGER_ROLE
      @acquisition_requests = @acquisition_requests.by_location(current_user.location_id)
      @recently_acquired = @recently_acquired.by_location(current_user.location_id)
      @recently_cancelled = @recently_cancelled.by_location(current_user.location_id)
    end
  end

  def show
    @item = @acquisition_request.item
    @request = @item.request

    @audits = @acquisition_request.audits
    @audits_grouped = @audits.reverse.group_by { |a| a.created_at.at_beginning_of_day }

    @users = User.all
    @locations = Location.active
  end

  def new
    @acquisition_request = AcquisitionRequest.new
    @item = Item.find(params[:item_id])
    @request = @item.request
  end

  def edit; end

  def create
    @acquisition_request = AcquisitionRequest.new(acquisition_request_params)
    @acquisition_request.audit_comment = "Created an acquisition item for #{@acquisition_request.item.title}"
    @acquisition_request.item = Item.find(acquisition_request_params[:item_id])
    @acquisition_request.requested_by = current_user
    @acquisition_request.location = @acquisition_request.item.request.reserve_location

    respond_to do |format|
      if @acquisition_request.save
        
        @notes = {}
        @notes[@acquisition_request.item.id] = Audited::Audit.where(
          auditable_id: @acquisition_request.item.request.id,
          auditable_type: "Request",
          associated_id: @acquisition_request.item.id,
          associated_type: "Item",
          action: "note"
        )

        format.html do
          redirect_to acquisition_request_path(@acquisition_request),
                      notice: 'Acquisition Request was successfully created.'
        end
        format.js
      else
        format.html { render action: 'new' }
        format.js
      end
    end
  end

  def update
    @acquisition_request.audit_comment = "Updated an acquisition request for #{@acquisition_request.item.title}"
    respond_to do |format|
      if @acquisition_request.update(acquisition_request_params)
        format.html do
          redirect_to acquisition_request_path(@acquisition_request),
                      notice: 'Acquisition Request was successfully updated.'
        end
        format.js
      else
        format.html { render action: 'edit' }
        format.js
      end
    end
  end

  def destroy
    @acquisition_request.audit_comment = "Removed acquisition_request #{@acquisition_request.item.title}"
    @acquisition_request.destroy
    respond_to do |format|
      format.html { redirect_to acquisition_requests_url }
      format.js
    end
  end

  ### CHANGE STATUS ###
  def change_status
    case params[:status]
    when AcquisitionRequest::STATUS_ACQUIRED
      @acquisition_request.status = AcquisitionRequest::STATUS_ACQUIRED
      @acquisition_request.acquired_at = Time.now
      @acquisition_request.acquired_by = current_user
      @acquisition_request.audit_comment = "Changed status to #{AcquisitionRequest::STATUS_ACQUIRED}"

      result = @acquisition_request.update(acquisition_request_params)

    when AcquisitionRequest::STATUS_CANCELLED
      @acquisition_request.status = AcquisitionRequest::STATUS_CANCELLED
      @acquisition_request.cancelled_at = Time.now
      @acquisition_request.cancelled_by = current_user
      @acquisition_request.audit_comment = "Changed status to #{AcquisitionRequest::STATUS_CANCELLED}"

      result = @acquisition_request.update(acquisition_request_params)
    end

    redirect_to acquisition_request_path(@acquisition_request)
  end

  def send_to_acquisitions
    @acquisition_request.audit_comment = "Sent email to #{params[:which].humanize}. CC: #{current_user.email}"
    @acquisition_request.acquisition_notes = params[:acquisition_notes]
    @acquisition_request.save(validate: false)

    @acquisition_request.email_to(params[:which], current_user)
    # AcquisitionsMailer.send_acquisition_request(@acquisition_request, current_user, params[:bookstore]).deliver_later

    redirect_to acquisition_request_path(@acquisition_request), notice: "Sent request to #{params[:which].humanize}"
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_request
    @acquisition_request = AcquisitionRequest.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def acquisition_request_params
    params.require(:acquisition_request).permit(:item_id, :acquisition_reason,
                                                :cancellation_reason, :acquisition_notes, :acquisition_source_type, :acquisition_source_name)
  end
end
