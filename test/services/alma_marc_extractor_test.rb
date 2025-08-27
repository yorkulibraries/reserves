# frozen_string_literal: true

require "test_helper"

class AlmaMarcExtractorTest < ActiveSupport::TestCase
  MARC_NS = 'http://www.loc.gov/MARC21/slim'

  # ---- helpers -------------------------------------------------------------

  def marc_record_xml(ns: true, inner:)
    ns_decl = ns ? %( xmlns="#{MARC_NS}") : ""
    %(<record#{ns_decl}>#{inner}</record>)
  end

  def df(tag, subs = {})
    subs_xml = subs.map { |code, val| %(<subfield code="#{code}">#{val}</subfield>) }.join
    %(<datafield tag="#{tag}" ind1=" " ind2=" ">#{subs_xml}</datafield>)
  end

  # ---- unit tests ----------------------------------------------------------

  test "clean_isbd_title removes trailing ISBD punctuation and extra spacing" do
    {
      " My title ;  " => "My title",
      "Title : /"     => "Title",
      "Title,  "      => "Title",
      "  Foo  =   "   => "Foo",
      "Bar : baz"     => "Bar : baz" # not trailing, so keep
    }.each do |raw, cleaned|
      assert_equal cleaned, AlmaMarcExtractor.clean_isbd_title(raw), "Failed for #{raw.inspect}"
    end
  end

  test "normalize_from_marcxml builds title from 245 a b n p and ignores c" do
    xml = marc_record_xml(
      ns: false, # <— IMPORTANT: no MARC namespace so XPath matches
      inner: [
        df("245", "a" => "Great book", "b" => " : a subtitle :", "n" => "pt. 1", "p" => "episode 2", "c" => "Ignored / author"),
        df("100", "a" => "Doe, John"),
        df("700", "a" => "Smith, Jane"),
        df("264", "b" => "Big Publisher", "c" => "2019.")
      ].join
    )

    got = AlmaMarcExtractor.normalize_from_marcxml(xml)

    # Internal colons are preserved; only trailing ISBD punctuation is removed.
    assert_equal "Great book : a subtitle : pt. 1 episode 2", got[:title]
    assert_equal "Doe, John, Smith, Jane",                    got[:author]
    assert_equal "Big Publisher",                             got[:publisher]
    assert_equal "2019",                                      got[:publication_date]
    assert_nil   got[:edition],                               "edition should be nil when 250$a absent"
  end

  test "normalize_from_marcxml uses 260 when 264 is absent and extracts year" do
    xml = marc_record_xml(
      ns: false,
      inner: [
        df("245", "a" => "T"),
        df("260", "b" => "Legacy Pub", "c" => "[1998]")
      ].join
    )
  
    got = AlmaMarcExtractor.normalize_from_marcxml(xml)
    assert_equal "Legacy Pub", got[:publisher]
    assert_equal "1998",       got[:publication_date]
  end  

  test "normalize_from_marcxml limits added authors to the first 700 and falls back to 110 if 100 missing" do
    xml = marc_record_xml(
      ns: false,
      inner: [
        df("245", "a" => "T"),
        df("110", "a" => "Acme Corporation"),
        df("700", "a" => "First Added"),
        df("700", "a" => "Second Added")
      ].join
    )

    got = AlmaMarcExtractor.normalize_from_marcxml(xml)
    assert_equal "Acme Corporation, First Added", got[:author]
  end

  test "normalize_from_marcxml normalizes ISBNs from 020$a and 020$z, dedupes, and splits primary vs other" do
    xml = marc_record_xml(
      ns: false,
      inner: [
        df("245", "a" => "T"),
        df("020", "a" => "978-0-123456-47-2 (pbk.)"),
        df("020", "z" => "0-321-14653-x"),
        df("020", "a" => "978 0 123456 47 2")
      ].join
    )

    got = AlmaMarcExtractor.normalize_from_marcxml(xml)
    assert_equal "9780123456472", got[:isbn]
    assert_equal "032114653X",    got[:other_isbn_issn]
  end

  test "normalize_from_marcxml works when namespaces are removed (no MARC namespace)" do
    inner = [
      df("245", "a" => "Title  ", "b" => "  : subtitle  "),
      df("100", "a" => "Author")
    ].join

    without_ns = marc_record_xml(ns: false, inner: inner)
    got = AlmaMarcExtractor.normalize_from_marcxml(without_ns)

    # Internal colon is preserved; extra spaces are squeezed.
    assert_equal "Title : subtitle", got[:title]
    assert_equal "Author",           got[:author]
  end

  test "normalize_from_bib_json passes through to MARC when 'anies' is present (uses first element)" do
    marc = marc_record_xml(
      ns: false, # <— IMPORTANT: provide a non-namespaced record so extractor can read it
      inner: [
        df("245", "a" => "From MARC"),
        df("100", "a" => "M. Author")
      ].join
    )

    json = { "anies" => [marc, "<record>ignored</record>"] }
    got  = AlmaMarcExtractor.normalize_from_bib_json(json)

    assert_equal "From MARC", got[:title]
    assert_equal "M. Author", got[:author]
  end

  test "normalize_from_bib_json extracts simple fields and cleans ISBD punctuation" do
    json = {
      "title" => "Hello world : ",
      "author" => "Jane Roe",
      "publication" => {
        "publisher" => "Nice Press",
        "date" => "2021"
      }
    }

    got = AlmaMarcExtractor.normalize_from_bib_json(json)

    assert_equal "Hello world", got[:title]          # cleaned trailing colon
    assert_equal "Jane Roe",    got[:author]
    assert_equal "Nice Press",  got[:publisher]
    assert_equal "2021",        got[:publication_date]
    refute got.key?(:isbn),     "isbn should be absent when not provided"
  end

  test "normalize_from_bib_json falls back to date_of_publication when publication.date is missing" do
    json = {
      "title" => "T",
      "author" => "A",
      "publication" => { "publisher" => "P" },
      "date_of_publication" => "1999"
    }

    got = AlmaMarcExtractor.normalize_from_bib_json(json)
    assert_equal "1999", got[:publication_date]
  end
end
