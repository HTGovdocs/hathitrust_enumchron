require 'parslet'

module HT
  module Atoms
    include Parslet
    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
    rule(:dot) { str('.') }
    rule(:dot?) { dot.maybe }
    rule(:digit) { match('\d') }
    rule(:digits) { digit.repeat(1) }
    rule(:digits?) { digit.repeat(0) }
    rule(:letter) { match('[a-z]') }
    rule(:letters) { letter.repeat(1) }
    rule(:letters?) { letter.repeat(0) }
    rule(:dash) { str('-') }
    rule(:slash) { str('/') }
    rule(:lparen) { str('(') }
    rule(:rparen) { str(')') }
    rule(:colon) { str(':') }
    rule(:plus) { str('+') }
    rule(:comma) { str(',') }
    
    rule(:list_comma) { space? >> comma >> space? }
        
  end
end

# Build up a range-or-single based on the passed
# in rule to determine what an atom on either side of
# the range might look like (e.g., if you want digits ,
# pass in a digit)

class HT::Range < Parslet::Parser
  include HT::Atoms
  
  rule(:range_sep_str) { dash }
  rule(:range_sep) { space? >> range_sep_str >> space? }
  rule(:strict_range) { base.as(:start) >> range_sep >> base.as(:end) }
  rule(:range)   { strict_range.as(:range) | base.as(:single) }
  root :range
  
  def initialize(base)
    super()
    self.class.rule(:base) { base }
  end
end


class HT::List < Parslet::Parser
  include HT::Atoms
  
  def initialize(list_sep, list_component)
    super()
    self.class.rule(:list_sep) { list_sep }
    self.class.rule(:list_component) { list_component }
  end
  
  rule(:list)  {  list_component >> (list_sep >> list_component).repeat}
  root :list
end


class HT::TaggedList < Parslet::Parser
  include HT::Atoms
  
  def initialize(tag_name, tag_strings, list_parser=nil)
    super()
    tag_strings.sort! {|a,b| b.length <=> a.length }
    tags = str(tag_strings.shift)
    while !tag_strings.empty?
      tags = tags | str(tag_strings.shift)
    end
    self.class.rule(:tag) { tags }   
    
    list_type = list_parser || self.default_list
    self.class.rule(:list) { list_type }
    self.class.rule(:tagged_list) { tag >> dot? >> space? >> list.as(tag_name.to_sym) }
  end
  
  rule(:drange) { HT::Range.new(digits) }
  rule(:lrange) { HT::Range.new(letter) }
  
  rule(:dlist)  { HT::List.new(list_comma, drange).as(:digits) }
  rule(:llist)  { HT::List.new(list_comma, lrange).as(:letters) }
  rule(:default_list) { dlist | llist }
  
  
  
  root :tagged_list
end
  


class HT::Year < Parslet::Parser
  include HT::Atoms
  rule(:year)   { (str('1') | str('2')) >> digit.repeat(3,3) }
  rule(:yrange) { HT::Range.new(year)   }
  rule(:iyear)  { HT::List.new(list_comma, yrange) }
  rule(:tyear)  { HT::TaggedList.new(:tyear, %w[years year yrs yr], self.iyear)}
end  

class V < Parslet::Parser
  include HT::Atoms
  rule(:volume) { HT::TaggedList.new(:volume, %w[volumes volume vols vol v v])}
  rule(:number) { HT::TaggedList.new(:number, %w[numbers number nums num nos no ns n numbs numb])}
  rule(:part)   { HT::TaggedList.new(:part, %w[parts part pts pt ps p])}
  
  rule(:iyear)  { HT::Year.new.iyear.as(:iyear) }
  rule(:tyear)  { HT::Year.new.tyear }
  
  rule(:comp) { volume | tyear | number | part | tyear | iyear }
  rule(:ec_delim) { space? >> (str(',')|str(':')) >> space? | space }
  rule(:ecs) { (comp >> (ec_delim >> comp).repeat(0)).repeat(0).as(:ec) }
  root(:ecs)
  
end

    
    
if __FILE__ == $0
  p = V.new
  puts p.parse('v 3')
  # puts p.parse('v. 3-11, 22')
  puts p.parse('no 3, vol. 11 part  1990')
  
end
    

__END__

module HT::Range
  include Parslet
  rule(:strict_range) { base.as(:start) >> range_dash >> base.as(:end) }
  rule(:range)   { strict_range.as(:range) | base.as(:single) }
end

module HT::List
  include Parslet
  rule(:list)  {  range_or_single >> (list_comma >> range_or_single).repeat}
end

module HT::RangeList
  include Parslet
  include 
  

class HT::Digits
  include Parslet
  include HT::Atoms
  include HT::RangeList
  rule(:base) { digits }
end

class HT::Letters
  include Parslet
  include HT::Atoms
  include HT::RangeList
  rule(:base) { letters }
end


class HT::Listable < Parslet::Parser
  include HT::Atoms
  
  def initialize(*strtags)
    super()
    strtags.sort! {|a,b| b.length <=> a.length }
    tags = str(strtags.shift)
    while !strtags.empty?
      tags = tags | str(strtags.shift)
    end
    self.class.rule(:tag) { tags }    
  end
  rule(:dlist) { HT::Digits.new.list.as(:digits)}
  rule(:llist) { HT::Letters.new.list.as(:letters) }  
  rule(:vlist) { dlist | llist }
  rule(:tagged_list) { tag >> dot? >> space? >> vlist.as(:volume) }
  
  root :tagged_list
end


class HT::Volume < Parslet::Parser
  def self.new
    HT::Listable.new('volumes', 'volume', 'vols', 'vol', 'v') 
  end
end


class HT:T < Parslet::Parser
  rule(:volume) { HT::Listable.new('volumes', 'volume', 'vols', 'vol', 'v') }
  rule(:number) { HT::Listable.new('numbers', 'number', 'nums', 'num', 'nos', 'no', 'ns', 'n', 'nmbrs', 'nmbr')}
  
  rule(:vn) { (volume | number) >> ()}


# class HT::Volume < Parslet::Parser
#   include HT::Atoms
#
#   root :volume
#
#   rule(:dlist) { HT::Digits.new.list.as(:digits)}
#   rule(:llist) { HT::Letters.new.list.as(:letters) }
#
#   rule(:volstr) {
#     str('volumes') |
#     str('volume')  |
#     str('vols')    |
#     str('vol')     |
#     str('vs')      |
#     str('v')
#   }
#
#   rule(:vlist) { dlist | llist }
#   rule(:volume) { volstr >> dot? >> space? >> vlist.as(:volume) }
# end




