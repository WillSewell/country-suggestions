# Module to hold the pure, logical, functions
# Also redefinitions of existing classes

class Array
  # A similarity coefficient
  def jaccard_index other_array
    inter = self & other_array
    union = self | other_array
    inter.length.to_f / union.length
  end
end

module Logic
  def compute_rankings user_countries, similarities_and_countries
    # For each country of the other user, increase the rank of
    # that country based on the similarity
    rankings_and_max = similarities_and_countries.reduce([Hash.new(0), 0]) do |acc, similarity_and_countries|

      # Pair unpacking for readability
      similarity = similarity_and_countries[0]
      other_user_countries = similarity_and_countries[1]
      country_rankings = acc[0]
      max_ranking = acc[1]

      if similarity > 0
        other_user_countries.each do |other_user_country|
          # Don't bother suggesting countries they have already clicked
          unless user_countries.include? other_user_country
            country_rankings[other_user_country] += similarity
            max_ranking = [country_rankings[other_user_country], max_ranking].max
          end
        end
      end

      [country_rankings, max_ranking]
    end

    normalise_rankings rankings_and_max[0], rankings_and_max[1]
  end

  def normalise_rankings rankings, max_ranking
    Hash[rankings.map { |country, rank| [country, rank / max_ranking ] }]
  end
end
