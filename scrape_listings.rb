#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'nokogiri'
require 'csv'
require 'byebug'

# Set up ChromeDriver to run in headless mode
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless') # Use headless mode
options.add_argument('--disable-gpu') # Applicable for Windows OS
options.add_argument('--no-sandbox') # Bypass sandboxing; may be required in some environments
options.add_argument('--window-size=1280x800') # Optional, set a default window size

email = 'christopher.m.neal@gmail.com'
password = 'ThatShannonAdkinsisonepieceoface!'

driver = Selenium::WebDriver.for :chrome, options: options
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
    title_element = parsed_page.at_css('#titletextonly')
    title = title_element.text if title_element

    price_element = parsed_page.at_css('.price')
    price_with_dollar = if price_element
                          price_element.text
                        else
                          '$0'
                        end
    price = price_with_dollar.gsub('$', '') if price_with_dollar

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
      csv_data << [Date.today.strftime('%m-%d'), title, price, url, csv_description]
      txt_data << [title, price_with_dollar, text_description]
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

driver.quit
puts 'Done!'
puts "\nHere are the titties:"
titles = CSV.read('/Users/christopherneal/Desktop/craigslist_poster/scraped_data.csv', headers: true).map { |row| row['Title'] }.sort
puts titles.map.with_index { |title, i| " #{i + 1}. #{title}"}

duplicates = titles.group_by { |e| e }
                   .select { |_k, v| v.size > 1 }
                   .keys
if duplicates.count.positive?
  puts "Warning! There are #{duplicates.count} duplicates:"
  puts duplicates.map { |duplicate| "  #{titles.count(duplicate)} postings of '#{duplicate}'"}
end
