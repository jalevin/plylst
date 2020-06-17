class RecentlyStreamedWorker
  include Sidekiq::Worker

  sidekiq_options lock: :while_executing, on_conflict: :reject

  # FIXME skylight doesn't like number of allocations. Let's microoptimize! (not tested)
  def perform(user_id)
    user = User.find_by(id: user_id, active: true)
    return unless user
    
    spotify = RSpotify::User.new(user.settings.to_hash)

    begin
      recent_track_ids = Array.new
      spotify.recently_played(limit: 50).each do |track|
        recent_track_ids.push([track.id, track.played_at])
      end
    rescue RestClient::Unauthorized, RestClient::BadRequest => e
      user.increment!(:authorization_fails)

      # Deactivate user if we don't have the right permissions and if their authorization has failed a crap ton of times
      user.update_attribute(:active, false) if user.authorization_fails >= 10
    end

    SaveTracksWorker.perform_async(user.id, recent_track_ids, 'streamed') if recent_track_ids.present?
  end
end
