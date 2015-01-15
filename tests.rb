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

  it "returns 0 for the completely different arrays" do
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
