require "http/server"
require "mysql"
require "uri"

DB_URL = "mysql://cocozip:BB4-QerHVORyNIzr@localhost/zipcode_db"

def format_zip(zip)
  "〒#{zip[0,3]}-#{zip[3,4]}"
end

def html_header
<<-HTML
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Crystal DB サービス</title>
</head>
<body>
<h1>Crystal DB サービス</h1>
HTML
end

def html_footer
"</body></html>"
end

server = HTTP::Server.new do |context|

  params = URI::Params.parse(context.request.query || "")

  addr = params["addr"]? || ""
  zip  = params["zip"]? || ""

  db = DB.open DB_URL

  rows = [] of Tuple(String,String,String,String)

  if addr != ""
    db.query "
      SELECT zipcode,prefectures,city,town
      FROM zipcode
      WHERE CONCAT(prefectures,city,town) LIKE ?
      LIMIT 50
    ", "%#{addr}%" do |rs|

      rs.each do
        rows << {
          rs.read(String),
          rs.read(String),
          rs.read(String),
          rs.read(String)
        }
      end
    end

  elsif zip != ""
    db.query "
      SELECT zipcode,prefectures,city,town
      FROM zipcode
      WHERE zipcode LIKE ?
      LIMIT 50
    ", "#{zip}%" do |rs|

      rs.each do
        rows << {
          rs.read(String),
          rs.read(String),
          rs.read(String),
          rs.read(String)
        }
      end
    end
  end

  db.close

  html = html_header

  html += "<form method='GET'>住所:<input name='addr'><button>住所検索</button></form>"
  html += "<form method='GET'>郵便番号:<input name='zip'><button>番号検索</button></form>"

  if rows.size > 0

    html += "<h2>検索結果</h2><table border=1>"

    rows.each do |r|
      zip,pref,city,town = r
      addr_full = "#{pref}#{city}#{town}"

      html += "<tr>"
      html += "<td>#{format_zip(zip)}</td>"
      html += "<td>#{addr_full}</td>"
      html += "</tr>"
    end

    html += "</table>"

  end

  html += html_footer

  context.response.content_type = "text/html"
  context.response.print html

end

server.bind_tcp "127.0.0.1", 8113

puts "Crystal DB Server running"
server.listen
