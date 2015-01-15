require 'em-hiredis'

class Model
  def initialize
    @redis = EM::Hiredis.connect
  end

  def get_all_users
    @redis.keys("*").callback { |keys| yield keys }
  end

  # Get all selected countries for a given user
  def get_selected user
    @redis.smembers(user).callback { |members| yield members }
  end

  # Add, or delete a country, and then compute and send rankings
  def update_country user, country, isSelected
    if isSelected
      deferrable = @redis.sadd user, country
    else
      deferrable = @redis.srem user, country
    end

    deferrable.callback do
      get_selected(user) { |user_countries| yield user_countries }
    end
  end

  def get_similarity user, user_countries, other_user
    if other_user == user.to_s
      # We don't care about the similarity of the current user to themselves
      # Just return a dummy value with similarity 0 so it is not counted
      yield [0, []]
    else
      # For each other user, compute the similarity using the Jaccard index
      @redis.smembers(other_user).callback do |other_countries|
        similarity = user_countries.jaccard_index other_countries
        yield [similarity, other_countries]
      end
    end
  end
end
