require_relative 'logic'

describe Array, "#jaccard_index" do
  it "returns the abs value of the union over the abs value of the intersection" do
    arr1 = [1,2,3]
    arr2 = [1,2,4]
    jindex = arr1.jaccard_index arr2
    jindex.should eq(0.5)
  end

  it "returns 1 for the same arrays" do
    arr1 = [1,2]
    arr2 = [1,2]
    jindex = arr1.jaccard_index arr2
    jindex.should eq(1)
  end

  it "returns 0 for completely different arrays" do
    arr1 = [1,2]
    arr2 = [3,4]
    jindex = arr1.jaccard_index arr2
    jindex.should eq(0)
  end

  it "returns 1 for two empty arrays" do
    arr1 = [1,2]
    arr2 = [1,2]
    jindex = arr1.jaccard_index arr2
    jindex.should eq(1)
  end
end

describe Logic do
  class DummyClass
  end

  before(:all) do
    @dummy = DummyClass.new
    @dummy.extend Logic
  end

  describe "#compute_rankings" do
    it "returns a hash of country codes to rankings based on the similarities and countries of other users" do
      rankings = @dummy.compute_rankings(
        ["GB", "AU", "NZ"],
        [[0.3, ["GB", "TZ", "DK"]],
         [0.5, ["GB", "AU", "US"]]])
      rankings.should eq({"US" => 1, "TZ" => 0.6, "DK" => 0.6})
    end
  end

  describe "#normalise_rankings" do
    it "returns the input array, normalised to 0...1" do
      normalised = @dummy.normalise_rankings([5.0, 6.0, 7.0], 7.0)
      normalised.should eq([0, 0.5, 1])
    end
  end
end
