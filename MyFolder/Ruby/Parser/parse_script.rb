require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'csv'

start_time = Time.now

def write_to_csv(product_title, product_price, product_image_url, file_name)
  CSV.open(file_name, 'a+') do |csv| # "a+" Read-write, starts at end of file if file exists, otherwise creates a new file for reading and writing.
    csv << [product_title, product_price, product_image_url]
  end
end

def get_page_info(page)
  products_count = page.xpath('//*[@id="center_column"]/div[1]/div/div[2]/h1/small').text.gsub(/\D/, '').to_i # get total products count
  products_per_page = page.xpath('//*[@id="nb_item"]/option[@selected = "selected"]/@value').to_s.to_i  # Transform Nokogiri::XML::NodeSet to integer or .first.value.to_i
  total_pages_count = products_count / products_per_page + 1 # integer / integer + 1
  [products_count, products_per_page, total_pages_count]
end

def check_availability(url)
  unless Net::HTTP.get_response(URI(url)).code.match(/20\d{1}$/)
    puts 'Page is unavalible'
    exit
  end
end

def validate_args(url)
  if ARGV.size != 2
    puts 'Invalid count of parameters. Usage: "ruby parse_script.rb URL FILE_NAME"'
    exit
  end

  unless url.match(/https?:\/\/[\S]+/)
    puts 'Invalid URL. It should be "http://www.example.com" or "https://example.com"'
    exit
  end

  # No needs to check file_name
end  

def get_args
  [ARGV.first, ARGV.last + '.csv']
end

def parse
  url, file_name = get_args
  validate_args(url)
  check_availability(url)
  
  File.delete(file_name) if File.exist?(file_name)
  
  puts 'Start parsing'

  page = Nokogiri::HTML(open(url))
  products_count, products_per_page, total_pages_count = get_page_info(page)
  result = {}

  (1..total_pages_count).map do |page_number|
    page.xpath('//a[@class="product_img_link"]/@href').map do |link_to_product|
      # check_availability(link_to_product)  # very expensive ~ 0.4 sec for each url
      product_page = Net::HTTP.get_response(URI.parse(link_to_product)).body
      
      product_title = Nokogiri::HTML(product_page).xpath('//h1[@class="nombre_producto"]/text()').to_s.strip
      product_image_url = Nokogiri::HTML(product_page).xpath('//*[@id="bigpic"]/@src')
      product_price = Nokogiri::HTML(product_page).xpath('////span[@class="attribute_price"]/text()').to_s.strip.to_f
      product_weight = Nokogiri::HTML(product_page).xpath('//span[@class="attribute_name"]')

      if product_weight.size > 1
        product_weight.to_a.map do |weight|
          write_to_csv(product_title + ' - ' + weight, product_price, product_image_url, file_name)
        end

        next
      end

      write_to_csv(product_title, product_price, product_image_url, file_name)
    end
  end

  puts 'Finish parsing'
end

parse

print 'Total time: ', Time.now - start_time, " sec.\n"