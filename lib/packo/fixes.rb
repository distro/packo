#--
# The license and code on this file belongs and are the one of the projects they're patching
#++

require 'blockenspiel'

module Blockenspiel
  module Unmixer
    def self.unmix(obj_, mod_)  # :nodoc:
      last_super_ = obj_.singleton_class
      this_super_ = last_super_.direct_superclass
      while this_super_
        if (this_super_ == mod_ || this_super_.respond_to?(:module) && this_super_.module == mod_)
          _reset_method_cache(obj_)
          last_super_.superclass = this_super_.direct_superclass
          _reset_method_cache(obj_)
          return
        else
          last_super_ = this_super_
          this_super_ = this_super_.direct_superclass
        end 
      end 
      nil 
    end 
  end
end
