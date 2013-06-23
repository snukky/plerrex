class Array
  def include_any_of?(ary)
    !(self & ary).empty?
  end
end
