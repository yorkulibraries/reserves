# lib/alma/reading_list_sync.rb
# frozen_string_literal: true

module Alma
    class ReadingListSync
        def self.sync!(request_id:, actor_id: nil)
            request = ::Request.find(request_id)
            actor   = actor_id.present? ? ::User.find_by(id: actor_id) : nil
            new(request, actor).sync!
        end

        def initialize(request, actor)
            @request   = request
            @actor     = actor
            @course_id = request.alma_course_id
            @list_id   = request.alma_reading_list_id
        end

        def sync!
            unless @course_id.present? && @list_id.present?
                Rails.logger.info("ReadingListSync: skip Request##{@request.id} (missing Alma IDs)")
                return { status: :skipped, added_local: 0, failed_local: 0, removed_local: 0, added_remote: 0 }
            end
            
            result = nil
            Rails.logger.tagged("ReadingListSync", "Request##{@request.id}") do
                fetch_result = fetch_alma_citations
                status       = fetch_result[:status]
                alma_citations = fetch_result[:citations] || []
                local_items    = @request.items.active.to_a
            
                # Repair legacy items that may have Alma codes in item_type
                normalize_existing_item_types!(local_items)
            
                case status
                when :not_found
                    alert_message = mark_request_as_missing!
                    result = {
                        status:        :alma_course_missing,
                        added_local:   0,
                        failed_local:  0,
                        removed_local: 0,
                        added_remote:  0,
                        alert:         alert_message
                    }
                    next
                when :error
                    result = {
                        status:        :error,
                        added_local:   0,
                        failed_local:  0,
                        removed_local: 0,
                        added_remote:  0
                    }
                    next
                end

                completion_notice = maybe_mark_request_completed

                alma_index  = index_alma(alma_citations)
                local_index = index_local(local_items)

                created_locals  = []
                failed_locals   = []
                removed_locals  = []
            
                # --- Alma → Local (create Items that exist only in Alma)
                ::ActiveRecord::Base.transaction do
                    alma_citations.each do |cit|
                        key = key_for_citation(cit)
                        next if local_index.key?(key)
                        item = build_item_from_citation(cit)
                        item.audit_comment = "Added from Alma sync (Request##{@request.id})"
            
                        begin
                            item.save!
                            local_index[key] = item
                            created_locals << item
                        rescue ActiveRecord::RecordInvalid => e
                            # Skip this item; collect failure info and continue
                            failed_locals << {
                                citation_id:   (dig_any(cit, %w[id citation.id]) || "(none)"),
                                title:         item.title,
                                errors:        item.errors.full_messages
                            }
                            Rails.logger.warn(
                                "ReadingListSync: skipping invalid item for Request##{@request.id} " \
                                "(citation #{failed_locals.last[:citation_id]}): #{e.record.errors.full_messages.join('; ')}"
                            )
                        end
                    end
                end
            
                # --- Local → Alma (create citations that exist only locally)
                local_items.each do |item|
                    key = key_for_item(item)
                    next if alma_index.key?(key)

                    if item.alma_citation_id.present?
                        removal_message = removal_comment_for(item)
                        Rails.logger.info("ReadingListSync: removing local Item##{item.id} (missing Alma citation #{item.alma_citation_id}) - #{removal_message}")
                        item.audit_comment = removal_message
                        item.destroy
                        removed_locals << item.id
                    else
                        Rails.logger.info("ReadingListSync: skipping remote citation for Item##{item.id} (awaiting async sync)")
                    end
                end
            
                Rails.logger.info(
                    "ReadingListSync done for Request##{@request.id} " \
                    "(alma→local: +#{created_locals.size}, failed: #{failed_locals.size}, local removals: #{removed_locals.size}, local→alma: +0)"
                )

                result = {
                    status:       :ok,
                    added_local:  created_locals.size,
                    failed_local: failed_locals.size,
                    removed_local: removed_locals.size,
                    added_remote: 0,
                    status_changed: false
                }
                if completion_notice.present?
                    result[:notice] = completion_notice
                    result[:status_changed] = true
                end
            end
            result || { status: :error, added_local: 0, failed_local: 0, removed_local: 0, added_remote: 0 }
            rescue => e
            Rails.logger.error("ReadingListSync error for Request##{@request.id}: #{e.class}: #{e.message}")
            { status: :error, added_local: 0, failed_local: 0, removed_local: 0, added_remote: 0 }
        end

        private

        # ---------- Fetch / Index ----------

        def fetch_alma_citations
            Alma::ReadingList.get_items_for_reading_list(@course_id, @list_id) || { status: :error, citations: [] }
        end

        def mark_request_as_missing!
            message = "Alma course missing as of #{Date.current}"

            ::ActiveRecord::Base.transaction do
                @request.audit_comment = message
                @request.update!(
                    alma_course_id: nil,
                    alma_reading_list_id: nil
                )

                @request.items.where.not(alma_citation_id: nil).find_each do |item|
                    item.audit_comment = message
                    item.update!(alma_citation_id: nil)
                end
            end

            Rails.logger.warn("ReadingListSync: Alma course missing for Request##{@request.id}; cleared Alma identifiers.")
            message
        rescue => e
            Rails.logger.error(
                "ReadingListSync: failed to mark Request##{@request.id} as missing Alma course: #{e.class}: #{e.message}"
            )
            message
        end

        def maybe_mark_request_completed
            details = Alma::ReadingList.get_reading_list(course_id: @course_id, reading_list_id: @list_id)
            return nil unless details[:status] == :ok

            raw_status = details[:data]['status']
            status_value =
                case raw_status
                when Hash then raw_status['value'] || raw_status['desc']
                else raw_status
                end

            return nil unless status_value.to_s.casecmp('Complete').zero?

            mark_request_completed! ? "Reading list is Complete in Alma. Request marked as completed." : nil
        end

        def mark_request_completed!
            return false if @request.status.in?([Request::COMPLETED, Request::CANCELLED, Request::REMOVED])

            @request.audit_comment = 'Marked completed automatically from Alma reading list status'

            attrs = { status: Request::COMPLETED }
            attrs[:completed_date] = Date.today if @request.completed_date.blank?

            updated = @request.update(attrs)
            if updated
                @request.reload
                notify_status_change!
            end
            updated
        rescue => e
            Rails.logger.error(
                "ReadingListSync: failed to mark Request##{@request.id} as completed: #{e.class}: #{e.message}"
            )
            false
        end

        def notify_status_change!
            candidate = [@actor, @request.assigned_to, @request.requester].compact.find { |user| user&.email.present? }
            candidate ||= User.admin.active.detect { |user| user.email.present? }

            unless candidate
                Rails.logger.warn(
                    "ReadingListSync: no valid user found to notify status change for Request##{@request.id}"
                )
                return
            end

            RequestMailer.status_change(@request, candidate).deliver_now
        rescue => e
            Rails.logger.error(
                "ReadingListSync: failed to enqueue status change email for Request##{@request.id}: #{e.class}: #{e.message}"
            )
        end

        def removal_comment_for(item)
            label = item.title.to_s.strip
            label = "Item##{item.id}" if label.blank?
            "Removed during Alma sync (citation missing remotely): #{label}"
        end

        def index_alma(citations)
            citations.each_with_object({}) { |c, h| h[key_for_citation(c)] = c }
        end

        def index_local(items)
            items.each_with_object({}) { |it, h| h[key_for_item(it)] = it }
        end

        # ---------- Matching (idempotent keys) ----------

        def key_for_citation(c)
            id = dig_any(c, %w[id citation.id])
            return id if id.present?
            normalize([alma_title(c), alma_author(c), alma_isbn(c)].join("|"))
        end

        def key_for_item(item)
            return item.alma_citation_id if item.alma_citation_id.present?
            normalize([
                item.title.to_s,
                (item.author.presence || item.try(:creator).to_s),
                (item.isbn.presence || item.try(:standard_number).to_s)
            ].join("|"))
        end

        # ---------- Build Item (Alma → Local) ----------

        def build_item_from_citation(c)
            internal_type = map_alma_type_to_internal(c)
            mms_id = extract_mms_id(c)
            source = mms_id.present? ? 'alma' : Item::METADATA_MANUAL

            @request.items.build(
                title:            alma_title(c),
                author:           alma_author(c),
                publisher:        alma_publisher(c),
                publication_date: alma_pub_date(c),
                isbn:             alma_isbn(c),
                other_isbn_issn:  alma_other_isbn_issn(c),
                loan_period:      "24 hours",
                callnumber:       alma_call_number(c),
                item_type:        internal_type,                  # internal app type (not BK/VM/etc.)
                format:           derive_format(internal_type, c),# satisfies model validations
                status:           ::Item::STATUS_NOT_READY,
                metadata_source:  source,
                metadata_source_id: mms_id,
                alma_citation_id: dig_any(c, %w[id citation.id])
            )
        end

        # ---------- Normalize existing rows ----------

        def normalize_existing_item_types!(items)
            items.each do |it|
                internal = coerce_internal_type(it.item_type, has_url: it.try(:url).present?)
                next if internal == it.item_type
                Rails.logger.info("Fixing legacy item_type #{it.item_type.inspect} → #{internal.inspect} for Item##{it.id}")
                it.update_columns(item_type: internal)
            end
        end

        def coerce_internal_type(value, has_url:)
            code = value.to_s.upcase
            case code
            when 'BK', 'BOOK', 'TEXT' then Item::TYPE_BOOK
            when 'VM', 'MULTIMEDIA', 'VIDEO', 'AUDIO', 'DVD', 'CD', 'STREAMING' then Item::TYPE_MULTIMEDIA
            when 'MAP', 'MP' then Item::TYPE_MAP
            when 'CR', 'SERIAL', 'JOURNAL', 'PERIODICAL' then has_url ? Item::TYPE_EJOURNAL : Item::TYPE_PRINT_PERIODICAL
            when 'EJOURNAL', 'E-JOURNAL' then Item::TYPE_EJOURNAL
            when '', nil then has_url ? Item::TYPE_EBOOK : Item::TYPE_BOOK
            else
                internal_known = [
                Item::TYPE_BOOK, Item::TYPE_EBOOK, Item::TYPE_MULTIMEDIA, Item::TYPE_MAP,
                Item::TYPE_PHOTOCOPY, Item::TYPE_COURSE_KIT, Item::TYPE_EJOURNAL, Item::TYPE_PRINT_PERIODICAL
                ].include?(value)
                internal_known ? value : (has_url ? Item::TYPE_EBOOK : Item::TYPE_BOOK)
            end
        end

        # ---------- Alma field extractors ----------
        def extract_mms_id(c)
            dig_any(c, %w[metadata.mms_id citation.metadata.mms_id]) ||
              dig_any(c, %w[metadata.source_record_id citation.metadata.source_record_id]) ||
              begin
                link = dig_any(c, %w[link])
                link.to_s[/mms_id=([^&]+)/, 1] if link
              end
        end

        def alma_title(c)
            dig_any(c, %w[metadata.title citation.metadata.title title]) || ""
        end

        def alma_author(c)
            primary = dig_any(c, %w[metadata.author citation.metadata.author author]).to_s.strip
            return primary unless primary.blank? || primary == "-"

            # Try common “additional person” / contributor fields (string/array/hash)
            candidates = [
                dig_any(c, %w[metadata.additional_person_name]),
                dig_any(c, %w[citation.metadata.additional_person_name]),
                dig_any(c, %w[additional_person_name]),
            ].compact

            name = extract_human_name(candidates)
            name || ""
        end

        # ---- helper ----
        def extract_human_name(val)
            case val
            when Array
                val.each do |v|
                n = extract_human_name(v)
                return n if n.present?
                end
                nil
            when Hash
                # look for common keys inside contributor-like hashes
                %w[name full_name value text].each do |k|
                    s = val[k] || val[k.to_sym]
                    s = s.to_s.strip
                    return s unless s.blank? || s == "-"
                end
                # scan nested values too
                extract_human_name(val.values)
            else
                s = val.to_s.strip
                return nil if s.blank? || s == "-"
                # split multi-name strings on common delimiters and take first non-blank
                s.split(/[;|,]/).map(&:strip).find { |piece| piece.present? && piece != "-" } || s
            end
        end

        def alma_publisher(c)
            dig_any(c, %w[metadata.publisher citation.metadata.publisher publisher]) || ""
        end

        def alma_pub_date(c)
            dig_any(c, %w[metadata.publication_date citation.metadata.publication_date year]) || ""
        end

        def alma_isbn(c)
            raw = dig_any(c, %w[metadata.isbn citation.metadata.isbn isbn])
            primary_isbn, _others = split_isbns(raw)
            primary_isbn
        end

        def alma_other_isbn_issn(c)
            raw = dig_any(c, %w[metadata.isbn citation.metadata.isbn isbn])
            _primary, others = split_isbns(raw)
            return nil if others.blank?
            others.join('; ')
        end

        # Returns [primary_digits_only, others_array_preserving_X]
        def split_isbns(raw)
            return [nil, []] if raw.blank?

            s = raw.to_s

            # 1) split on common delimiters
            parts = s.split(/[;,\|]/)

            # 2) also grab long digit/hyphen/X runs that might not be delimited
            parts += s.scan(/\d[\d\-\sXx]{8,}\w/)

            parts = parts.map(&:strip).reject(&:blank?)

            # Primary selection wants digits-only for model numeric validation
            primary_candidates = parts.map { |p| p.gsub(/[^0-9]/, '') }.reject(&:blank?)
            primary =
            primary_candidates.find { |v| v.length == 13 } ||
            primary_candidates.find { |v| v.length == 10 }

            others = parts.map { |p| p.gsub(/[^0-9Xx]/, '').upcase }
                        .select { |v|
                            (v.length == 13 && v =~ /^\d{13}$/) ||
                            (v.length == 10 && v =~ /^\d{9}[\dX]$/)
                        }
                        .uniq

            if primary.present?
                others.reject! { |v| v.gsub(/[^0-9]/, '') == primary }
            end

            [primary, others]
        end


        def normalize_isbn(raw)
            return nil if raw.blank?

            parts = raw.to_s.split(/[;,\|]/)

            parts += raw.to_s.scan(/\d[\d\-\s]{8,}\d/)

            candidates = parts
                .map { |p| p.gsub(/[^0-9]/, '') }
                .reject(&:blank?)

            candidates.find { |s| s.length == 13 } || candidates.find { |s| s.length == 10 }
        end      

        def alma_call_number(c)
            dig_any(c, %w[metadata.call_number citation.metadata.call_number call_number]) || ""
        end

        # Alma → internal app type for new items
        def map_alma_type_to_internal(c)
            raw     = dig_any(c, %w[defined_fields.type_attributes.attribute.value secondary_type.value type.value]).to_s.upcase
            has_url = has_url?(c)
            coerce_internal_type(raw, has_url: has_url)
        end

        # ---------- Format derivation (satisfy model validations) ----------

        def derive_format(internal_type, c)
            has_url = has_url?(c)
            raw_fmt = dig_any(c, %w[metadata.format citation.metadata.format format material_type carrier])&.to_s&.upcase

            case internal_type
            when Item::TYPE_BOOK
                has_url ? Item::FORMAT_EBOOK : Item::FORMAT_BOOK
            when Item::TYPE_EBOOK
                Item::FORMAT_EBOOK
            when Item::TYPE_MULTIMEDIA
                normalize_multimedia_format(raw_fmt) || (has_url ? Item::FORMAT_STREAMING : Item::FORMAT_DVD)
            when Item::TYPE_MAP
                Item::FORMAT_MAP
            when Item::TYPE_EJOURNAL, Item::TYPE_PRINT_PERIODICAL
                Item::FORMAT_ARTICLE
            when Item::TYPE_PHOTOCOPY, Item::TYPE_COURSE_KIT
                Item::FORMAT_OTHER
            else
                has_url ? Item::FORMAT_EBOOK : Item::FORMAT_BOOK
            end
        end

        def has_url?(c)
            dig_any(c, %w[link url metadata.url citation.link citation.url]).present?
        end

        def normalize_multimedia_format(raw)
            return nil if raw.blank?
            case raw
            when /DVD/        then Item::FORMAT_DVD
            when /\bCD\b/     then Item::FORMAT_CD
            when /VHS/        then Item::FORMAT_VHS
            when /\bLP\b/     then Item::FORMAT_LP
            when /STREAM/     then Item::FORMAT_STREAMING
            else
                nil
            end
        end

        # ---------- helpers ----------

        def normalize(s)
            s.to_s.downcase.squish
        end

        def dig_any(h, paths)
            paths.each do |path|
                value = dig_path(h, path)
                return value if value.present?
            end
            nil
        end

        def dig_path(obj, path)
            keys = path.split(".")
            cur  = obj
            keys.each do |k|
                return nil unless cur.is_a?(Hash)
                cur = cur[k] || cur[k.to_sym]
            end
            cur
        end
    end
end  
