module APIClient
  class LinkedIn < APIClient::OAuth
    def initialize(auth, options={})
      super(auth)

      @client = ::LinkedIn::Client.new( SETTINGS['auth_credentials']['linkedin']['key'],
                                        SETTINGS['auth_credentials']['linkedin']['secret'] )
      @client.authorize_from_access(@auth.access_token, @auth.access_token_secret)
    end

    def search(query, options = {})
      @client
        .search(:keywords => query, :count => (options[:limit] || DEFAULT_LIMIT))\
        .people
        .all
        .map{|li_user|
          self.person_from(li_user)
        }.reject{|p| p.name == "Private"}
     rescue ::LinkedIn::Unauthorized => e
       raise APIAuthenticationError, e.inspect
    end

    def get(id)
      li_user = @client.profile(:id => id, :fields => [:id, :first_name, :last_name, :headline, :picture_url, :public_profile_url, :location])
      self.person_from(li_user) if li_user.present?
    rescue ::LinkedIn::Unauthorized => e
      raise APIAuthenticationError, e.inspect
    end

    def picture_url_for(li_user)
      if li_user.picture_url.present?
        li_user.picture_url
      else
        @client.profile(:id => li_user.id, :fields => ['picture_url']).picture_url
      end
    end

    def person_from(li_user)
      user = @client.profile(:id => li_user.id,:fields => ['picture_url', 'headline', 'public_profile_url', 'location'])
      Person.new( :name                   => [li_user.first_name, li_user.last_name].reject{|n| n.blank? }.join(' '),
                  :bio                    => user.headline,
                  :photo_import_url       => user.picture_url,
                  :url                    => user.public_profile_url,
                  :location               => user.location.try(:name) ) \
                  .tap{|person|
                    person.imported_from_provider = 'linkedin'
                    person.imported_from_id       = li_user.id
                  }
    end
  end
end
