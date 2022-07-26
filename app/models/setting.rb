class Setting < RailsSettings::CachedSettings

  def self.fiscal_date

    d = Date.parse(Setting.reports_fiscal_year_start)

    if d > Date.today
      return d - 1.year
    else
      return d
    end

  end
end
