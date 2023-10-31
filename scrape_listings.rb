#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'nokogiri'
require 'csv'
require 'byebug'
require 'fileutils'
require 'dotenv'

Dotenv.load
Dotenv.require_keys("PASSWORD", "EMAIL")

# Required Login:
EMAIL = ENV['EMAIL']
PASSWORD = ENV['PASSWORD']

# check if there's an image folder
unless Dir.exist?('images')
  puts 'Creating images folder.'
  Dir.mkdir('images')
end

# check if there are existing images
existing_images = Dir.glob('images/*.png').select { |file| File.file?(file) }
if existing_images.count.positive?
  puts "Found #{existing_images.count} existing images. Destroy them?"
  if %w[y yes].include?($stdin.gets.chomp.downcase)
    existing_images.each do |file|
      FileUtils.rm(file)
    end
  else
    puts 'Not destroying existing images.'
  end
else
  puts 'No existing images found, moving on.'
end

# Set up ChromeDriver to run in headless mode
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless') # Use headless mode
options.add_argument('--disable-gpu') # Applicable for Windows OS
options.add_argument('--no-sandbox') # Bypass sandboxing; may be required in some environments # options.add_argument('--window-size=1050x1168') # Optional, set a default window size
# options.add_argument('--window-size=375,812') # iPhone X
options.add_argument('--window-size=375,600') # custom
# mobile_emulation = {
#   "deviceMetrics" => { "width" => 375, "height" => 812, "pixelRatio" => 3 },
#   "userAgent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1"
# }
mobile_emulation = { 'deviceName' => 'iPhone XR' }
options.add_emulation(mobile_emulation: mobile_emulation)
driver = Selenium::WebDriver.for(:chrome, options: options)

wait = Selenium::WebDriver::Wait.new(timeout: 10) # waits for max 10 seconds
driver.navigate.to 'https://accounts.craigslist.org/login/home'

driver.find_element(:id, 'inputEmailHandle').send_keys email
driver.find_element(:id, 'inputPassword').send_keys password

begin
  login_button = wait.until { driver.find_element(:id, 'login') }
  login_button.click
rescue Selenium::WebDriver::Error::NoSuchElementError
  puts 'Login failed. Please try manually and press Enter.'
  $stdin.gets
end

begin
  driver.find_element(:link_text, "home of #{email}")
rescue Selenium::WebDriver::Error::NoSuchElementError
  puts 'Login failed or not on the expected page. Please navigate to the correct page and press Enter.'
  $stdin.gets
end

csv_data = []
txt_data = []
price_updates = []

paginator_text = driver.find_element(:id, 'paginator1').text
total_postings_match = paginator_text.match(/postings \d+ - \d+ of (\d+) total/)
total_postings = total_postings_match[1].to_i if total_postings_match

current_page = 1

loop do
  active_postings = driver.find_elements(:css, 'td.buttons.active')
  number_of_active_postings = active_postings.count

  number_of_active_postings.times do |index|
    # Refetch active postings because the list might have gone stale
    active_postings = driver.find_elements(:css, 'td.buttons.active')

    current_button = wait.until do
      active_postings[index].find_element(:css, 'form.manage.display input.managebtn[value="display"]')
    end

    current_button.click

    # Capture the page's source and parse with Nokogiri
    page_source = driver.page_source
    parsed_page = Nokogiri::HTML(page_source)

    # Extract data using Nokogiri
    # title_element = parsed_page.at_css('#titletextonly')

    # Find the element using Selenium's methods, not Nokogiri
    title_element = driver.find_element(:id, 'titletextonly')
    title = title_element.text if title_element

    # Then execute the script to scroll to that element
    driver.execute_script('arguments[0].scrollIntoView(true);', title_element)

    driver.execute_script('window.scrollBy(0,-5)') # Scrolls up by 5 pixels
    image_name = title.gsub(/\s+/, '_').gsub(/[^\w.-]/, '').gsub(/_+/, '_').gsub(/^_+|_+$/, '')
    driver.save_screenshot("images/#{image_name}.png")

    price_element = parsed_page.at_css('.price')
    price_with_dollar = if price_element
                          price_element.text
                        else
                          '$0'
                        end
    price = price_with_dollar.gsub('$', '') if price_with_dollar
    friend_price = (price.to_f * 0.8).round(0)

    description_element = parsed_page.at_css('#postingbody')

    text_description = if description_element
                         description = description_element.text.strip.gsub(/\s+/, ' ')
                         description.gsub!('Feel free to text or call. ', '')
                         description
                       else
                         ''
                       end

    csv_description = text_description.gsub(
      /I'm free.*|Feel free.*|Payment.*|Mode of payment.*|Texting.*|Contact.*|For sale:/i, ''
    ).strip

    link_element = driver.find_element(:css, "p > a[target='_blank']")
    url = link_element.attribute('href') if link_element

    # image_element = driver.find_element(:css, 'div.slide.first.visible > img')
    # image_url = image_element.attribute('src') if image_element

    # Avoid writing to CSV and TXT if one of the elements is nil
    missing_elements = []
    missing_elements << 'Title' if title.nil?
    missing_elements << 'Price' if price.nil?
    missing_elements << 'Description' if csv_description.nil?

    if missing_elements.any?
      error_message = "ERROR: Page: #{current_page}, Element: #{index}, Missing: #{missing_elements.join(', ')}"
      puts error_message
    else
      csv_data << [Date.today.strftime('%m-%d'), title, friend_price, url, csv_description]
      txt_data << [title, price_with_dollar, text_description]
      price_updates << [title, price_with_dollar]
      puts txt_data
    end

    driver.navigate.back
    wait.until { driver.find_element(:css, 'form.manage.display') }
  end

  begin
    # Wait until the next page link is present
    next_page_link = wait.until do
      driver.find_element(:xpath, "//a[@href='?filter_page=#{current_page + 1}&show_tab=postings']")
    end

    # If the link is found and it's clickable, click it
    break unless next_page_link&.enabled? && next_page_link&.displayed?

    next_page_link.click
    current_page += 1
  rescue Selenium::WebDriver::Error::TimeoutError
    break
  end
end
# Save to CSV
CSV.open('/Users/christopherneal/Desktop/craigslist_poster/scraped_data.csv', 'wb') do |csv|
  csv << ['Date Updated', 'Title', 'Price', 'URL', 'Description']
  csv_data.each do |row|
    csv << row
  end
end

# Save to TXT
File.open('/Users/christopherneal/Desktop/craigslist_poster/scraped_data.txt', 'w') do |file|
  txt_data.each do |row|
    file.puts row.join("\n")
    file.puts
    file.puts '=============================='
    file.puts
  end
end
# Save to TXT
File.open('/Users/christopherneal/Desktop/craigslist_poster/price_updates.txt', 'w') do |file|
  price_updates.sort.each do |row|
    file.puts row.join(' ')
  end
end

driver.quit
puts 'Done!'
puts "\nHere are the titties:"
titles = CSV.read('/Users/christopherneal/Desktop/craigslist_poster/scraped_data.csv', headers: true).map do |row|
  row['Title']
end.sort
puts titles.map.with_index { |title, i| " #{i + 1}. #{title}" }

duplicates = titles.group_by { |e| e }
                   .select { |_k, v| v.size > 1 }
                   .keys
if duplicates.count.positive?
  puts "Warning! There are #{duplicates.count} duplicates:"
  puts duplicates.map { |duplicate| "  #{titles.count(duplicate)} postings of '#{duplicate}'" }
end



# How to screenshot just one element, if needed:
# require 'selenium-webdriver'
# require 'chunky_png'
#
# driver = Selenium::WebDriver.for :chrome
# driver.navigate.to 'http://example.com'
#
# # Find the element you want to take a screenshot of
# element = driver.find_element(:id, 'element_id') # Replace with your element's locator
#
# # Get the location and size of the element
# location = element.location
# size = element.size
#
# # Take a screenshot of the page
# driver.save_screenshot('page_screenshot.png')
#
# # Load the page screenshot with chunky_png
# image = ChunkyPNG::Image.from_file('page_screenshot.png')
#
# # Calculate dimensions
# top = location.y
# left = location.x
# right = location.x + size.width
# bottom = location.y + size.height
#
# # Crop the image to the size of the element
# element_image = image.crop(left, top, right - left, bottom - top)
#
# # Save the element's screenshot
# element_image.save('element_screenshot.png')
#
# driver.quit
