class CitationMapper
  def initialize(entry)
    @e = entry.transform_keys { |k| k.to_s.tr("-", "_") }
  end

  def to_item_attributes
    {
      title:              title,
      author:             author_string,
      publication_date:   year,
      publisher:          field("publisher"),
      edition:            edition,                 # ← NEW
      isbn:               isbn_one,
      other_isbn_issn:    isbn_others_string
    }.compact_blank
  end

  private

  def field(name) = @e[name]

  def title
    field("title") || field("chapter_title") || field("container_title")
  end

  def year
    field("year") || field("date") || dig_issued_year
  end

  def dig_issued_year
    issued = field("issued")
    return unless issued
    if issued.is_a?(Hash) && (parts = issued["date-parts"]).is_a?(Array)
      parts.first&.first&.to_s
    else
      issued.to_s
    end
  end

  def author_string
    # Try author/authors/editor variants; sometimes AnyStyle yields strings, sometimes CSL arrays
    a = field("author") || field("authors") || field("editor")
    return if a.blank?

    if a.is_a?(Array)
      a.map do |v|
        if v.is_a?(Hash)
          [v["given"], v["family"]].compact.join(" ")
        else
          v.to_s
        end
      end.join(", ")
    elsif a.is_a?(Hash)
      [a["given"], a["family"]].compact.join(" ")
    else
      a.to_s
    end
  end

  def edition
    # Often present as "edition"; sometimes AnyStyle sticks it into "note" or "genre".
    field("edition") || pick_edition_like(field("note")) || pick_edition_like(field("genre"))
  end

  def pick_edition_like(val)
    return unless val.present?
    s = Array(val).join(" ")
    m = s.match(/[^.]*edition[^.]*/i)
    m && m[0].strip
  end

  def isbns
    v = field("isbn")
    v.is_a?(Array) ? v : Array(v).compact
  end

  def isbn_one = isbns.first

  def isbn_others_string
    rest = isbns.drop(1)
    rest.empty? ? nil : rest.join(", ")
  end
end
