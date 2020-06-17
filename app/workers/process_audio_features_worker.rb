class ProcessAudioFeaturesWorker
  include Sidekiq::Worker

  sidekiq_options lock: :while_executing, on_conflict: :reject

  def perform
    # FIXME This query + job is gonna wreck. n+1. 
    # This is a good case for a subselect.
    # Look at what indexes are actually being used. 
    # 
    # Might be worth it to create a separate job that queries
    # each of these conditions and updates an arbitrary column
    # to mark for update- then we can avoid expensive query and n+1
    Track.where(key: nil).where('audio_features_last_checked < ? OR audio_features_last_checked IS NULL', 72.hours.ago).pluck(:spotify_id).each_slice(90) do |slice|
      Track.where(spotify_id: slice).update_all(audio_features_last_checked: Time.now)
      AudioFeaturesWorker.set(queue: :slow).perform_async(slice)
    end
  end
end
