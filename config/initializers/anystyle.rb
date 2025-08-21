require "anystyle"
require "anystyle/data"

Rails.application.config.to_prepare do
  AnyStyleService.parser
end
