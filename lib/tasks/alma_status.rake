# frozen_string_literal: true

namespace :alma do
  desc 'Enqueue background jobs to synchronize request statuses with Alma'
  task sync_request_statuses: :environment do
    AlmaStatusSweepJob.perform_now
    puts 'Enqueued AlmaStatusSweepJob'
  end
end
