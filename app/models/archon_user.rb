Archon.record_type(:user) do
  plural 'users'
  corresponding_record_type :user
  
  def self.transform(rec)
    return nil unless (rec['IsAdminUser'] == '1')
    obj = super
    obj.email = rec['Email']
    # ASpace comes with an 'admin' user out of the box
    obj.username = rec['Login'] == 'admin' ? '_admin' : rec['Login']
    obj.name = rec['DisplayName']
    obj.first_name = rec["FirstName"]
    obj.last_name = rec['LastName']

    yield obj
  end
end
