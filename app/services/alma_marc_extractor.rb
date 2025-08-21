class AlmaMarcExtractor
    NS = { "m" => "http://www.loc.gov/MARC21/slim" }
  
    def self.normalize_from_bib_json(json)
      if json["anies"].present?
        xml = Array(json["anies"]).first.to_s
        return normalize_from_marcxml(xml)
      end
  
      {
        title:            clean_isbd_title(json["title"]),
        author:           json["author"],
        publisher:        json.dig("publication", "publisher"),
        publication_date: json.dig("publication", "date") || json["date_of_publication"]
      }.compact_blank
    end
  
    def self.normalize_from_marcxml(xml)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces! if doc.root&.namespace&.href != NS["m"]
  
      sf  = ->(tag, code) { doc.at_xpath("//datafield[@tag='#{tag}']/subfield[@code='#{code}']")&.text&.strip }
      sfs = ->(tag, code) { doc.xpath("//datafield[@tag='#{tag}']/subfield[@code='#{code}']").map { _1.text.strip }.presence }
  
      # ---- TITLE (245 $a $b $n $p), ignore $c entirely ----
      t_a  = sf.call("245", "a")
      t_b  = sf.call("245", "b")
      t_ns = sfs.call("245", "n") || []
      t_ps = sfs.call("245", "p") || []
      raw_title = [t_a, t_b, *t_ns, *t_ps].compact.join(" ").squeeze(" ")
      title     = clean_isbd_title(raw_title)
  
      main_author = sf.call("100", "a") || sf.call("110", "a")
      added_auths = (sfs.call("700", "a") || [])
      author      = ([main_author] + added_auths.take(1)).compact.join(", ")
  
      publisher = sf.call("264", "b") || sf.call("260", "b")
      pub_date  = sf.call("264", "c") || sf.call("260", "c")
      year      = pub_date.to_s[/\b(1[89]\d{2}|20\d{2}|21\d{2})\b/]
  
      edition = sf.call("250", "a")
  
      isbns_a = sfs.call("020", "a") || []
      isbns_z = sfs.call("020", "z") || []
      norm = ->(s) { s.gsub(/[^0-9Xx]/, "").upcase }
      all  = (isbns_a + isbns_z).map { |s| norm.call(s) }.reject(&:blank?).uniq
      isbn = all.first
      other = all.drop(1).presence&.join(", ")
  
      {
        title:            title.presence,
        author:           author.presence,
        publisher:        publisher.presence,
        publication_date: year.presence,
        edition:          edition.presence,
        isbn:             isbn,
        other_isbn_issn:  other
      }.compact
    end
  
    # Remove trailing ISBD punctuation that only appears because we’re omitting $c
    def self.clean_isbd_title(s)
      return if s.blank?
      s.strip
       .gsub(/\s+/, " ")
       .sub(/\s*\/\s*\z/, "")        # trailing slash before $c
       .sub(/\s*[:;=,]\s*\z/, "")    # dangling colon/semicolon/equal/comma
       .strip
    end
end  