class ChorusIndexer < ChorusWorker
  def thread_pool_size
    if !ChorusConfig.instance['indexer_threads'].nil?
      ChorusConfig.instance['indexer_threads'].to_i
    else
      1
    end
  end
end