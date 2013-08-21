Archon.record_type(:content) do
  plural 'content'

  def self.endpoint(start = 1)
    raise "Collection not specified" unless @cid
    "/?p=#{path}&batch_start=#{start}&cid=#{@cid}"
  end


  def self.set(collection_id)
    @cid = collection_id.to_s
    raise "Argument error" unless @cid =~ /[0-9]+/
    self
  end

end
