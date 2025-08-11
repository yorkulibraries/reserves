class AlmaCourseService
  include HTTParty

  def initialize
    raise 'Setting.alma_apikey not set' if Setting.alma_apikey.nil? || Setting.alma_apikey.empty?
    raise 'Setting.alma_region not set' if Setting.alma_region.nil? || Setting.alma_region.empty?
    @api_key = Setting.alma_apikey
    self.class.base_uri Setting.alma_region + '/almaws/v1'
  end

  def get_bib(mms_id)
    get_action("bibs/#{mms_id}")
  end

  def get_nz_bibs(mms_id)
    get_action("bibs", { :nz_mms_id => mms_id})
  end

  def get_cz_bibs(mms_id)
    get_action("bibs", { :cz_mms_id => mms_id})
  end

  def get_course(course_id)
    get_action("courses/#{course_id}")
  end

  def search_course(q)
    get_action("courses", { :q => q })
  end

  def create_course(course)
    post_action("courses", course)
  end

  def update_course(course_id, course)
    put_action("courses/#{course_id}", course)
  end

  def get_reading_lists(course_id)
    get_action("courses/#{course_id}/reading-lists")
  end

  def create_reading_list(course_id, reading_list)
    post_action("courses/#{course_id}/reading-lists", reading_list)
  end

  def update_reading_list(course_id, reading_list_id, reading_list)
    put_action("courses/#{course_id}/reading-lists/#{reading_list_id}", reading_list)
  end

  def get_citations(course_id, reading_list_id)
    get_action("courses/#{course_id}/reading-lists/#{reading_list_id}/citations")
  end

  def get_citation(course_id, reading_list_id, citation_id)
    get_action("courses/#{course_id}/reading-lists/#{reading_list_id}/citations/#{citation_id}")
  end

  def create_citation(course_id, reading_list_id, citation)
    post_action("courses/#{course_id}/reading-lists/#{reading_list_id}/citations", citation)
  end

  def update_citation(course_id, reading_list_id, citation_id, citation)
    put_action("courses/#{course_id}/reading-lists/#{reading_list_id}/citations/#{citation_id}", citation)
  end

  def new_course
    {
      "code": "",
      "name": "",
      "section": "",
      "academic_department": {
        "value": ""
      },
      "school_faculty": {
        "value": ""
      },
      "processing_department": {
        "value": "YOR_CR"
      },
      "term": [
        {
          "value": "FW"
        }
      ],
      "status": "ACTIVE",
      "start_date": "",
      "end_date": "",
      "weekly_hours": "",
      "participants": "",
      "year": "",
      "instructor": [
        {
          "primary_id": "",
          "first_name": "",
          "last_name": ""
        }
      ],
      "campus": [
        {
          "campus_code": {
            "value": ""
          },
          "campus_participants": ""
        }
      ],
      "searchable_ids": {
        "searchable_id": ""
      },
      "notes": [
        {
          "content": "",
          "type": ""
        }
      ]
    }
  end

  def new_citation
    {
      "status": {
        "value": "BeingPrepared"
      },
      "copyrights_status": {
        "value": "NOTDETERMINED"
      },
      "type": {
        "value": "BK"
      },
      "secondary_type": {
        "value": "BK"
      },
      "metadata": {
        "title": "",
        "author": "",
        "publisher": "",
        "publication_date": "",
        "edition": "",
        "isbn": "",
        "issn": "",
        "mms_id": "",
        "additional_person_name": "",
        "place_of_publication": "",
        "call_number": "",
        "note": "",
        "journal_title": "",
        "article_title": "",
        "issue": "",
        "editor": "",
        "chapter": "",
        "chapter_title": "",
        "chapter_author": "",
        "year": "",
        "pages": "",
        "source": "",
        "series_title_number": "",
        "pmid": "",
        "doi": "",
        "volume": "",
        "start_page": "",
        "end_page": "",
        "start_page2": "",
        "end_page2": "",
        "start_page3": "",
        "end_page3": "",
        "start_page4": "",
        "end_page4": "",
        "start_page5": "",
        "end_page5": "",
        "start_page6": "",
        "end_page6": "",
        "start_page7": "",
        "end_page7": "",
        "start_page8": "",
        "end_page8": "",
        "start_page9": "",
        "end_page9": "",
        "start_page10": "",
        "end_page10": "",
        "author_initials": "",
        "part": "",
        "additional_title": "",
        "additional_author": ""
      },
      "open_url": "",
      "public_note": "",
      "sticker_price": "",
      "source1": "",
      "source2": "",
      "source3": "",
      "source4": "",
      "source5": "",
      "source6": "",
      "source7": "",
      "source8": "",
      "source9": "",
      "source10": "",
      "link_to_pdf": ""
    }
  end

  def extract_mms_id(url)
    match = url.match(/alma(\d{18})/)
    match ? match[1] : nil
  end

  def citations_from_string(s)
    alma_types = { 'book' => 'BK' }
    citations = []
    metadata = AnyStyle.parse s
    metadata.each do |m|
      c = new_citation
      c[:metadata][:title] = m[:title]&.first || ''
      c[:metadata][:publisher] = m[:publisher]&.first || ''
      c[:metadata][:publication_date] = m[:date]&.first || ''
      c[:metadata][:edition] = m[:edition]&.first || ''
      c[:metadata][:place_of_publication] = m[:location]&.first || ''

      if m[:author]&.any?
        c[:metadata][:author] = [m[:author][0][:family], m[:author][0][:given]].compact.join(', ')
      end

      if m[:author]&.length&.> 1
        c[:metadata][:additional_person_name] = [m[:author][1][:family], m[:author][1][:given]].compact.join(', ')
      end
      citations.push c
    end
    citations
  end

  def create_citations_from_string(course_id, reading_list_id, s)
    citations = citations_from_string(s)
    citations.map do |c|
      create_citation(course_id, reading_list_id, c)
    end
  end

  def citation_from_mms_id(mms_id)
    c = new_citation
    result = get_bib(mms_id)
    if result[:success]
      m = result[:data]
    else
      result = get_nz_bibs(mms_id)
      if result[:success]
        m = result[:data][:bib][0]
      else
        result = get_cz_bibs(mms_id)
        m = result[:data][:bib][0] if result[:success]
      end
    end

    if !m.nil?
      c[:metadata][:title] = m[:title] || ''
      c[:metadata][:author] = m[:author] || ''
      c[:metadata][:publisher] = m[:publisher_const] || ''
      c[:metadata][:publication_date] = m[:date_of_publication] || ''
      c[:metadata][:edition] = m[:complete_edition] || ''
      c[:metadata][:place_of_publication] = m[:place_of_publication] || ''
      c[:metadata][:isbn] = m[:isbn] || ''
      c[:metadata][:issn] = m[:issn] || ''
      c[:metadata][:mms_id] = m[:mms_id] || ''
    end
    c
  end

  def create_citation_from_mms_id(course_id, reading_list_id, mms_id)
    c = citation_from_mms_id(mms_id)
    create_citation(course_id, reading_list_id, c)
  end

  private

  def get_action(action, params = {})
    response = self.class.get(
      "/#{action}",
      query: { apikey: @api_key }.merge(params),
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      }
    )
    process_response(response)
  end

  def post_action(action, data)
    response = self.class.post(
      "/#{action}?apikey=#{@api_key}",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: data.to_json
    )
    process_response(response)
  end

  def put_action(action, data)
    response = self.class.put(
      "/#{action}?apikey=#{@api_key}",
      headers: {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
      },
      body: data.to_json
    )
    process_response(response)
  end

  def process_response(response)
    if response.success?
      begin
        { success: true, data: JSON.parse(response.body).deep_symbolize_keys }
      rescue JSON::ParserError
        { success: false, error: response.code, message: 'Invalid JSON in successful response', details: { error: 'Invalid JSON response' } }
      end
    else
      details = if response.body.nil? || response.body.empty?
                  { error: 'Empty or nil response body' }
                else
                  begin
                    JSON.parse(response.body).deep_symbolize_keys
                  rescue JSON::ParserError
                    { error: 'Invalid JSON response' }
                  end
                end
      { success: false, error: response.code, message: response.message, details: details }
    end
  end
end