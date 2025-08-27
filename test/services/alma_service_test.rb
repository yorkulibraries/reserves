# frozen_string_literal: true

require "test_helper"

class AlmaServiceTest < ActiveSupport::TestCase
  # --------------------------
  # helpers
  # --------------------------

  def with_env(vars)
    old = {}
    vars.each do |k, v|
      old[k] = ENV.key?(k) ? ENV[k] : :__absent__
      v.nil? ? ENV.delete(k) : ENV[k] = v
    end
    yield
  ensure
    old.each do |k, v|
      v == :__absent__ ? ENV.delete(k) : ENV[k] = v
    end
  end

  def ensure_setting_constant
    return if Object.const_defined?(:Setting)
    Object.const_set(:Setting, Class.new)
    @created_setting_const = true
  end

  def remove_setting_constant_if_created
    Object.send(:remove_const, :Setting) if @created_setting_const
  end

  # --------------------------
  # config()
  # --------------------------

  test "config prefers Alma.configuration over Setting and ENV; maps region to host" do
    with_env("ALMA_API_KEY" => nil, "ALMA_REGION" => nil, "ALMA_API_HOST" => nil) do
      Alma.stubs(:respond_to?).with(:configuration).returns(true)
      Alma.stubs(:configuration).returns(OpenStruct.new(apikey: "CFG_KEY", region: "ca"))

      cfg = AlmaService.config
      assert_equal "CFG_KEY", cfg[:key]
      assert_equal "api-ca.hosted.exlibrisgroup.com", cfg[:host]
    end
  end

  test "config uses Setting when Alma.configuration is not available" do
    with_env("ALMA_API_KEY" => nil, "ALMA_REGION" => nil, "ALMA_API_HOST" => nil) do
      Alma.stubs(:respond_to?).with(:configuration).returns(false)

      ensure_setting_constant
      Setting.stubs(:alma_apikey).returns("SET_KEY")
      Setting.stubs(:alma_region).returns("na")

      cfg = AlmaService.config
      assert_equal "SET_KEY", cfg[:key]
      assert_equal "api-na.hosted.exlibrisgroup.com", cfg[:host]
    end
  ensure
    remove_setting_constant_if_created
  end

  test "config falls back to ENV when neither Alma.configuration nor Setting provide values" do
    with_env("ALMA_API_KEY" => "ENV_KEY", "ALMA_REGION" => "ca", "ALMA_API_HOST" => nil) do
      Alma.stubs(:respond_to?).with(:configuration).returns(false)

      # If Setting exists in your app, make it return blanks so ENV wins.
      if Object.const_defined?(:Setting)
        Setting.stubs(:alma_apikey).returns(nil)
        Setting.stubs(:alma_region).returns(nil)
      end

      cfg = AlmaService.config
      assert_equal "ENV_KEY", cfg[:key]
      assert_equal "api-ca.hosted.exlibrisgroup.com", cfg[:host]
    end
  end

  test "config respects explicit ALMA_API_HOST override" do
    with_env("ALMA_API_KEY" => "ENV_KEY", "ALMA_REGION" => "na", "ALMA_API_HOST" => "custom.host.example") do
      Alma.stubs(:respond_to?).with(:configuration).returns(false)
      if Object.const_defined?(:Setting)
        Setting.stubs(:alma_apikey).returns(nil)
        Setting.stubs(:alma_region).returns(nil)
      end

      cfg = AlmaService.config
      assert_equal "ENV_KEY", cfg[:key]
      assert_equal "custom.host.example", cfg[:host]
    end
  end

  # --------------------------
  # fetch_bib()
  # --------------------------

  test "fetch_bib raises when API key is missing" do
    AlmaService.stubs(:config).returns({ key: nil, host: "api-na.hosted.exlibrisgroup.com" })
    assert_raises(RuntimeError, "Missing ALMA_API_KEY") do
      AlmaService.fetch_bib("9912345678901234")
    end
  end

  test "fetch_bib builds HTTPS GET with escaped MMS ID, sets headers, uses read_timeout=15, and returns normalized hash" do
    host    = "api-ca.hosted.exlibrisgroup.com"
    key     = "sekret"
    mms_id  = "99/ABC 123"
    expected_uri = URI::HTTPS.build(
      host: host,
      path: "/almaws/v1/bibs/#{CGI.escape(mms_id)}",
      query: "view=full&expand=record"
    )

    AlmaService.stubs(:config).returns({ key: key, host: host })

    # Capture the GET request and verify URI + headers
    req = mock("request")
    req.expects(:[]=).with("Authorization", "apikey #{key}")
    req.expects(:[]=).with("Accept", "application/json")

    Net::HTTP::Get.expects(:new).with do |arg|
      arg.is_a?(URI) && arg.to_s == expected_uri.to_s
    end.returns(req)

    # Net::HTTP.start must use SSL and read_timeout=15
    fake_http = mock("http")
    response  = mock("response")
    response.stubs(:code).returns("200")
    response.stubs(:body).returns(%({ "title": "ok" }))

    Net::HTTP.expects(:start).with do |h, p, opts|
        h == host && p == 443 && opts.is_a?(Hash) && opts[:use_ssl] && opts[:read_timeout] == 15
    end.yields(fake_http).returns(response)

    fake_http.expects(:request).with(req).returns(response)

    # Normalizer receives parsed JSON
    AlmaMarcExtractor.expects(:normalize_from_bib_json).with({ "title" => "ok" }).returns({ title: "ok" })

    got = AlmaService.fetch_bib(mms_id)
    assert_equal({ title: "ok" }, got)
  end

  test "fetch_bib passes {} to normalizer when response body is invalid JSON" do
    host = "api-na.hosted.exlibrisgroup.com"
    AlmaService.stubs(:config).returns({ key: "k", host: host })

    req = mock("request").tap do |r|
      r.stubs(:[]=) # don't care about order here
    end
    Net::HTTP::Get.stubs(:new).returns(req)

    fake_http = mock("http")
    bad_json_response = mock("response")
    bad_json_response.stubs(:code).returns("200")
    bad_json_response.stubs(:body).returns("not-json")

    Net::HTTP.stubs(:start).yields(fake_http).returns(bad_json_response)
    fake_http.stubs(:request).with(req).returns(bad_json_response)

    AlmaMarcExtractor.expects(:normalize_from_bib_json).with({}).returns({})

    got = AlmaService.fetch_bib("99123")
    assert_equal({}, got)
  end

  test "fetch_bib raises on HTTP error codes (e.g., 404, 500)" do
    host = "api-na.hosted.exlibrisgroup.com"
    AlmaService.stubs(:config).returns({ key: "k", host: host })

    req = mock("request").tap { |r| r.stubs(:[]=) }
    Net::HTTP::Get.stubs(:new).returns(req)

    fake_http = mock("http")
    Net::HTTP.stubs(:start).yields(fake_http)

    [404, 500].each do |code|
        resp = mock("resp-#{code}")
        resp.stubs(:code).returns(code.to_s)
        resp.stubs(:body).returns("{}")
        fake_http.stubs(:request).with(req).returns(resp)
        
        # Re-stub start to return this iteration's response
        Net::HTTP.stubs(:start).yields(fake_http).returns(resp)
        
        err = assert_raises(RuntimeError) { AlmaService.fetch_bib("mms") }
        assert_equal "Alma #{code}", err.message
    end
  end
end
