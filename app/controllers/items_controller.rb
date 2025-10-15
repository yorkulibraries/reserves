# frozen_string_literal: true

class ItemsController < ApplicationController
  before_action :set_request
  before_action :set_item, except: %i[index new create]
  authorize_resource

  def index
    @items = if params[:status] == Item::STATUS_DELETED
               @request.items.deleted
             else
               @request.items.active
             end

    @notes = {}

    @items.each do |item|
      @notes[item.id] = Audited::Audit.where(
        auditable_id: @request.id,
        auditable_type: "Request",
        associated_id: item.id,
        associated_type: "item",
        action: "note"
      )
    end  
  end

  def show
    respond_to do |format|
      format.html
      format.js
    end
  end

  def new
    @item   = @request.items.new
    type    = params[:type].presence&.downcase || Item::TYPE_BOOK
    @item.item_type = type
  
    # normalize source; default Book → citation if none passed
    @source = normalized_source(params[:source])
    @source ||= "citation" if @item.item_type == Item::TYPE_BOOK
  
    respond_to do |format|
      format.html
      format.js
    end
  end  

  def edit
    if @item.item_type == Item::TYPE_BOOK
      @source = normalized_source(params[:source]) || normalized_source(@item.metadata_source)
    end

    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @item = @request.items.new(item_params)
    @item.status = Item::STATUS_NOT_READY
    @item.audit_comment = "Added Item: #{@item.title}"
  
    respond_to do |format|
      # ---- Server-side fallback for "Citation" flow ----
      raw_citation = (params[:raw_citation].presence || params.dig(:item, :raw_citation)).to_s.strip
  
      if @item.item_type == Item::TYPE_BOOK && raw_citation.present?
        # If client didn't set metadata_source, assume manual for citation flow
        manual_val = defined?(Item::METADATA_MANUAL) ? Item::METADATA_MANUAL : "manual"
        @item.metadata_source = manual_val if @item.metadata_source.blank?
  
        if @item.metadata_source.to_s == manual_val.to_s
          begin
            entry  = AnyStyleService.parse(raw_citation)
            mapped = CitationMapper.new(entry).to_item_attributes
  
            # fill only blanks (never overwrite what the user typed)
            mapped.each do |attr, val|
              next if val.blank?
              @item[attr] = val if @item.send(attr).blank?
            end
          rescue => e
            Rails.logger.error("[AnyStyle] parse error: #{e.class}: #{e.message}")
            # continue without mapped fields
          end
  
          unless @item.description.to_s.include?(raw_citation)
            @item.description = [@item.description.presence, raw_citation].compact.join("\n\n")
          end
        end
      end
  
      if @item.save
        if @request.status == Request::INPROGRESS
          @request.update(
            status: Request::OPEN,
            audit_comment: 'Status changed to OPEN after item was added'
          )
        end
        @request.reload
        RequestMailer.new_item_notification(@request, @item).deliver_later
  
        AddCitationJob.perform_later(@item.id, current_user.id)
        # Alma::AlmaSync.sync_item(@item, current_user)
  
        @notes = {}
        @notes[@item.id] = Audited::Audit.where(
          auditable_id: @request.id,
          auditable_type: "Request",
          associated_id: @item.id,
          associated_type: "Item",
          action: "note"
        )
  
        format.html { redirect_to [@request, @item], notice: 'Item was successfully created.' }
        format.js
      else
        format.html { render action: 'new' }
        format.js
      end
    end
  end  

  def update
    respond_to do |format|
      @item.audit_comment = "Updated Item: #{@item.title}"

      if @item.update(item_params)
        AddCitationJob.perform_later(@item.id, current_user.id) if current_user
        format.html { redirect_to [@request, @item], notice: 'Item was successfully updated.' }
        format.js
      else
        format.html { render action: 'edit' }
        format.js
      end
    end
  end

  # DELETE /items/1
  # DELETE /items/1.json
  def destroy
    @item.audit_comment = "Item #{@item.title} removed from request"
  
    if @item.alma_citation_id.present?
      success = Alma::ReadingList.delete_citation(
        course_id:       @request.alma_course_id,
        reading_list_id: @request.alma_reading_list_id,
        citation_id:     @item.alma_citation_id
      )
  
      if success
        @item.update_column(:alma_citation_id, nil)
      else
        Rails.logger.warn("⚠️ Failed to delete citation in Alma for Item##{@item.id}")
      end
    end
  
    @item.destroy
    @request.reload
    respond_to do |format|
      format.html { redirect_to @request }
      format.js
    end
  end

  ## ADDITIONAL ACTIONS ##
  def change_status
    status = params[:status]
    @item.status = Item::STATUS_NOT_READY if @item.status.blank?

    # Toggle between ready or not ready.
    case @item.status
    when Item::STATUS_NOT_READY
      @item.status = Item::STATUS_READY
    when Item::STATUS_READY
      @item.status = Item::STATUS_NOT_READY
    end

    @item.status = Item::STATUS_DELETED if status == Item::STATUS_DELETED && @request.status == Request::REMOVED

    @item.audit_comment = "#{@item.title} status changed to #{@item.status}"

    @item.save(validate: false)

    @notes_by_item = {}
    @notes_by_item[@item.id] = Audited::Audit.where(
      auditable_id: @request.id,
      auditable_type: "Request",
      associated_id: @item.id,
      associated_type: "Item",
      action: "note"
    )

    @notes = @notes_by_item || {}

    respond_to do |format|
      format.html { redirect_to @request, notice: "Item status changed to #{status}" }
      format.js
    end
  end

  def barcode; end

  private

  def normalized_source(raw)
    value = raw.to_s.strip.downcase
    case value
    when "citation", "manual"
      "citation"
    when "primo", "solr", "search", "worldcat"
      "primo"
    when "alma"
      "alma"
    else
      nil
    end
  end

  def set_request
    @request = Request.find(params[:request_id])
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_item
    @item = @request.items.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def item_params
    item_attributes = %i[id title author description callnumber isbn other_isbn_issn publication_date edition publisher loan_period provided_by_requestor
                         metadata_source metadata_source_id _destroy request_id item_type copyright_options other_copyright_options url format map_index_num
                         page_number physical_copy_required journal_title issue volume ils_barcode]

    params.require(:item).permit(item_attributes)
  end
end
