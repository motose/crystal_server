require "http/server"
require "mysql"
require "ecr"
require "uri"

# DB Record Structure
record ZipRow, zipcode : String, prefectures : String, city : String, town : String

# HTML Template Definition
class IndexView
  def initialize(@rows : Array(ZipRow), @q_addr : String, @q_zip : String)
  end

  ECR.def_to_s "src/index.ecr"
end

# Database connection URL
DB_URL = "mysql://cocozip:BB4-QerHVORyNIzr@localhost/zipcode_db"

server = HTTP::Server.new do |context|
  params = context.request.query_params
  q_addr = params["addr"]? || ""
  q_zip = params["q"]? || ""
  rows = [] of ZipRow

  # Database Search Logic
  if !q_addr.empty? || !q_zip.empty?
    DB.open(DB_URL) do |db|
      if !q_addr.empty?
        # Address search: combine pref + city + town and use LIKE %query%
        query = "SELECT zipcode, prefectures, city, town FROM zipcode 
                 WHERE CONCAT(prefectures, city, town) LIKE ? LIMIT 50"
        db.query query, "%#{q_addr}%" do |rs|
          rs.each do
            rows << ZipRow.new(rs.read(String), rs.read(String), rs.read(String), rs.read(String))
          end
        end
      elsif !q_zip.empty?
        # Zipcode search: forward match LIKE query%
        query = "SELECT zipcode, prefectures, city, town FROM zipcode 
                 WHERE zipcode LIKE ? LIMIT 50"
        db.query query, "#{q_zip}%" do |rs|
          rs.each do
            rows << ZipRow.new(rs.read(String), rs.read(String), rs.read(String), rs.read(String))
          end
        end
      end
    end
  end

  context.response.content_type = "text/html"
  view = IndexView.new(rows, q_addr, q_zip)
  context.response.print view.to_s
end

address = "127.0.0.1"
port = 8113
puts "Crystal DB Service is running on http://#{address}:#{port}"
server.listen(address, port)
