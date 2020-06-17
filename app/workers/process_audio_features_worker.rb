class ProcessAudioFeaturesWorker
  include Sidekiq::Worker

  sidekiq_options lock: :while_executing, on_conflict: :reject

  def perform
    # NOTE after we add index for key/audio_features_last_checked = nil it may
    # be faster for 2 separate queries. extra allocations, but maybe worth it.
    # none of this is tested or sanity checked but hey- what are some extra
    # strokes?
    #
    # 1)
    # nil_tracks = Track.where(key: nil).where(audio_features_last_checked: nil).pluck(:id, :spotify_id).to_h
    # old_tracks = Track.where(key: nil).where("audio_features_last_checked < ?", 72.hours.ago).pluck(:id, :spotify_id).to_h
    # ids = nil_tracks.keys + old_tracks.keys
    # Track.where(id: ids).update_all(audio_features_last_checked: Time.now)
    # spotify_ids = nil_tracks.values + old_tracks.values

    # NOTE second approach. let's write some ugly sql and return the spotify_ids
    # at the same time
    # 2)
    #sql = <<~SQL
      #UPDATE tracks SET 
        #audio_features_last_checked = ? 
      #WHERE key IS NULL AND (audio_features_last_checked < ?  OR audio_features_last_checked IS NULL)
      #RETURNING spotify_ids
    #SQL
    #track_spotify_ids = ActiveRecord::Base.connection.execute(sql, Time.now.strftime("%F %T"))

    tracks = Track.where(key: nil).where("audio_features_last_checked < ? OR audio_features_last_checked IS NULL", 72.hours.ago)

    # lets update all at once instead of batches of 90
    tracks.update_all(audio_features_last_checked: Time.now)

    # queue in batches
    tracks.pluck(:spotify_id).each_slice(90) do |slice|
      AudioFeaturesWorker.set(queue: :slow).perform_async(slice)
    end
  end
end
