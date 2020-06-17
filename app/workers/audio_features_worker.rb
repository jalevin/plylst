class AudioFeaturesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :slow, lock: :while_executing, on_conflict: :reject

  def perform(track_ids)
    # lets use a hash instead of array
    tracks = Track.where(spotify_id: track_ids, key: nil).pluck(:spotify_id, :id)

    # reject nil and blank since we're not gonna use those anyway
    spotify_tracks = RSpotify::AudioFeatures.find(tracks.values).reject! { |track| track.nil? }.uniq!

    # lets use a global time for all of these since we don't care much about
    # precision
    time = Time.now

    spotify_tracks.each do |spotify_track|
      track_id = tracks[spotify_track.id]
      Track.where(id: track_id).update_columns(
        acousticness: spotify_track.acousticness,
        danceability: spotify_track.danceability,
        energy: spotify_track.energy,
        instrumentalness: spotify_track.instrumentalness,
        key: spotify_track.key,
        liveness: spotify_track.liveness,
        loudness: spotify_track.loudness,
        mode: spotify_track.mode,
        speechiness: spotify_track.speechiness,
        tempo: spotify_track.tempo,
        time_signature: spotify_track.time_signature,
        valence: spotify_track.valence,
        audio_features_last_checked: time
      )
    end
  end
end
