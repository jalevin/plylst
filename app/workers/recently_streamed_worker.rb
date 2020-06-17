class RecentlyStreamedWorker
  include Sidekiq::Worker

  sidekiq_options lock: :while_executing, on_conflict: :reject

  # FIXME skylight doesn't like number of allocations. Let's microoptimize! (not tested)
  # let's change the code path so that if we don't find the user or have an
  # error we exit immediately.
  def perform(user_id)
    # only get attributes we need
    return unless (user = User.find_by(id: user_id, active: true).select(:id, :authorization_fails))
    spotify = RSpotify::User.new(user.settings.to_hash)

    begin
      recent_track_ids = []
      spotify.recently_played(limit: 50).each do |track|
        recent_track_ids.push([track.id, track.played_at])
      end
      SaveTracksWorker.perform_async(user.id, recent_track_ids, "streamed") if recent_track_ids.any?
    rescue RestClient::Unauthorized, RestClient::BadRequest
      user.increment!(:authorization_fails)

      # Deactivate user if we don't have the right permissions and if their authorization has failed a crap ton of times
      user.update_attribute(:active, false) if user.authorization_fails >= 10
    end
  end
end
