# frozen_string_literal: true

require "test_helper"

class CitationMapperTest < ActiveSupport::TestCase
  # Small helper to build final attributes
  def map(entry)
    CitationMapper.new(entry).to_item_attributes
  end

  # ----------------------------
  # Key normalization
  # ----------------------------
  test "normalizes dash-keys to underscores" do
    attrs = map({ "container-title" => "Journal of Testing" })
    assert_equal "Journal of Testing", attrs[:title], "container-title should map to container_title fallback for title"
  end

  # ----------------------------
  # Title fallback
  # ----------------------------
  test "title prefers title over chapter_title over container_title" do
    attrs = map({
      "title"           => "Primary Title",
      "chapter_title"   => "Chapter Title",
      "container_title" => "Container Title"
    })
    assert_equal "Primary Title", attrs[:title]

    attrs2 = map({
      "chapter_title"   => "Chapter Title",
      "container_title" => "Container Title"
    })
    assert_equal "Chapter Title", attrs2[:title]

    attrs3 = map({ "container_title" => "Container Title" })
    assert_equal "Container Title", attrs3[:title]
  end

  test "title falls back to chapter-title when provided as dashed key" do
    attrs = map({ "chapter-title" => "Dashed Chapter" })
    assert_equal "Dashed Chapter", attrs[:title]
  end

  # ----------------------------
  # Year precedence and issued parsing
  # ----------------------------
  test "publication_date prefers year over date over issued" do
    attrs = map({
      "year"  => "2024",
      "date"  => "2023",
      "issued" => { "date-parts" => [[2022, 5, 1]] }
    })
    assert_equal "2024", attrs[:publication_date]
  end

  test "publication_date falls back to date when year missing" do
    attrs = map({
      "date"   => "2018",
      "issued" => { "date-parts" => [[2017]] }
    })
    assert_equal "2018", attrs[:publication_date]
  end

  test "publication_date uses issued[date-parts] when year and date are missing" do
    attrs = map({
      "issued" => { "date-parts" => [[2003, 12, 31]] }
    })
    assert_equal "2003", attrs[:publication_date]
  end

  test "publication_date uses issued as a plain string if not a date-parts hash" do
    attrs = map({ "issued" => "1999" })
    assert_equal "1999", attrs[:publication_date]
  end

  # ----------------------------
  # Author formatting
  # ----------------------------
  test "author formats array of CSL-name hashes" do
    attrs = map({
      "author" => [
        { "given" => "Ada",  "family" => "Lovelace" },
        { "given" => "Alan", "family" => "Turing" }
      ]
    })
    assert_equal "Ada Lovelace, Alan Turing", attrs[:author]
  end

  test "author formats array of strings" do
    attrs = map({ "authors" => ["Lovelace, Ada", "Turing, Alan"] })
    assert_equal "Lovelace, Ada, Turing, Alan", attrs[:author]
  end

  test "author formats single hash" do
    attrs = map({ "author" => { "given" => "Grace", "family" => "Hopper" } })
    assert_equal "Grace Hopper", attrs[:author]
  end

  test "author passes through single string" do
    attrs = map({ "editor" => "Doe, John" })
    assert_equal "Doe, John", attrs[:author]
  end

  test "author omitted when blank or empty" do
    [nil, "", [], {}].each do |v|
      attrs = map({ "author" => v })
      refute attrs.key?(:author), "author should be omitted for #{v.inspect}"
    end
  end

  # ----------------------------
  # Edition extraction
  # ----------------------------
  test "edition uses explicit edition field when present" do
    attrs = map({ "edition" => "Second edition" })
    assert_equal "Second edition", attrs[:edition]
  end

  test "edition is extracted from note text containing 'edition' (string)" do
    attrs = map({ "note" => "Includes index. Third edition, revised." })
    assert_equal "Third edition, revised", attrs[:edition]
  end

  test "edition is extracted from note array containing 'edition'" do
    attrs = map({
      "note" => ["Random note.", "Fourth edition expanded. More text."]
    })
    # Regex captures the sentence fragment containing 'edition' without trailing period
    assert_equal "Fourth edition expanded", attrs[:edition]
  end

  test "edition can be extracted from genre as well" do
    attrs = map({ "genre" => "Instructor copy. Fifth edition (international)" })
    assert_equal "Fifth edition (international)", attrs[:edition]
  end

  test "edition omitted when not present in edition/note/genre" do
    attrs = map({ "note" => "No version info here.", "genre" => "Thesis" })
    refute attrs.key?(:edition)
  end

  # ----------------------------
  # ISBN handling
  # ----------------------------
  test "isbn primary from single string value" do
    attrs = map({ "isbn" => "978-1-4028-9462-6" })
    assert_equal "978-1-4028-9462-6", attrs[:isbn]
    refute attrs.key?(:other_isbn_issn)
  end

  test "isbn splits first as primary and joins rest into other_isbn_issn" do
    attrs = map({ "isbn" => ["111", "222", "333"] })
    assert_equal "111", attrs[:isbn]
    assert_equal "222, 333", attrs[:other_isbn_issn]
  end

  test "isbn fields omitted when empty" do
    [nil, [], ""].each do |v|
      attrs = map({ "isbn" => v })
      refute attrs.key?(:isbn)
      refute attrs.key?(:other_isbn_issn)
    end
  end

  # ----------------------------
  # compact_blank behavior
  # ----------------------------
  test "to_item_attributes omits nil/blank fields" do
    attrs = map({
      "title"  => "Only Title",
      "author" => nil,
      "isbn"   => nil,
      "edition" => ""
    })
    assert_equal({ title: "Only Title" }, attrs)
  end
end
