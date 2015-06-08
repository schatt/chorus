class ChorusIndexer < ChorusWorker
  def thread_pool_size
    ChorusConfig.instance['indexer_threads'].to_i
  end
end