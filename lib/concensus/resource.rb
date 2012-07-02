require "httparty"
require "zip/zip"
require "geo_ruby"
require "geo_ruby/shp"

module Concensus  
  class Resource
    
    attr_accessor :geometry, :name, :state, :year
  
    include HTTParty
    
    def initialize(name, geometry, state)
      @name = name
      @geometry = geometry
      @state = state
      @year = Concensus::configuration.year
    end
    
    def self.get_and_unzip(uri)
      safe_filename = uri.gsub("/", "_").gsub(".zip", "")
      zipped_file_path = "#{Concensus::configuration.tmp_dir}/#{safe_filename}.zip"
      
      if !File.exists?(zipped_file_path)
        zipped_file = File.new(zipped_file_path, "w")
        zipped_file.write(HTTParty.get(Concensus::configuration.root_url + uri))
      end
      
      if !already_unzipped?(zipped_file_path)
        unzipped_files = Zip::ZipFile.open(zipped_file_path)
      
        unzipped_files.each do |x|
          file = File.new(Concensus::configuration.tmp_dir + safe_filename + file_extension(x.to_s), "w")
          file.write(x.get_input_stream.read)
          file.close
        end
      end
      
      return "#{Concensus::configuration.tmp_dir}#{safe_filename}.shp"
    end

    def self.process_find(shp_file_path, identifier, state, name = nil)
      
      # Prevent annoying georuby error messages
      previous_stderr, $stderr = $stderr, StringIO.new
      
      if name
        GeoRuby::Shp4r::ShpFile.open(shp_file_path) do |shp|
           matched_shape = shp.find {|x| x.data[identifier].match(name) }
           raise StandardError if !matched_shape
           return Resource.new(matched_shape.data[identifier], matched_shape.geometry, state)
        end
      else
        places = []
        GeoRuby::Shp4r::ShpFile.open(shp_file_path).each do |shp|
          places << Resource.new(shp.data[identifier], shp.geometry, state)
        end
        return places
      end
      
      # Restore previous value of stderr
      $stderr.string
      $stderr = previous_stderr
    end

    def self.state_code_to_id(state_code)
      Concensus::configuration.census_state_ids[state_code]
    end
    
    def self.already_unzipped?(zipped_file_path)
      file_path_without_extension = filename_without_extension(zipped_file_path)
      File.exists?("#{file_path_without_extension}.shp") &&
      File.exists?("#{file_path_without_extension}.dbf") &&
      File.exists?("#{file_path_without_extension}.shx")
    end
    
    def self.filename_without_extension(filename)
      filename.gsub(/\.[a-z]*$/, "")
    end
    
    def self.file_extension(filename)
      filename[/\.[a-z]*$/]
    end
    
  end
end