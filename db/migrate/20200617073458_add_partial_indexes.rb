class AddPartialIndexes < ActiveRecord::Migration[6.0]
  def change
    # experimental - need to benchmark
    add_index :tracks, :key, where: "(key IS NULL)"
    add_index :tracks, :audio_features_last_checked, where: "(audio_features_last_checked IS NULL)"
  end
end
