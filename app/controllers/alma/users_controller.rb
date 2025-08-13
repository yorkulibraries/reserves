class Alma::UsersController < ApplicationController
    def lookup_by_name
        first_name = params[:first_name].gsub(/[^A-Za-z\s]/, '')
        last_name  = params[:last_name].gsub(/[^A-Za-z\s]/, '')
        users = Alma::User.find_by_name(first_name: first_name, last_name: last_name) || []
        
        render json: users.map { |u|
            {
                name: "#{u['first_name']} #{u['last_name']}",
                email: u.dig('contact_info', 'email', 0, 'email_address'),
                primary_id: u['primary_id']
            }
        }
    end
end