#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'nokogiri'
require 'csv'

email = 'christopher.m.neal@gmail.com'
password = "Gina'sbottomisfurry"

driver = Selenium::WebDriver.for :chrome
wait = Selenium::WebDriver::Wait.new(timeout: 10) # waits for max 10 seconds
driver.navigate.to 'https://accounts.craigslist.org/login/home'

driver.find_element(:id, 'inputEmailHandle').send_keys email
driver.find_element(:id, 'inputPassword').send_keys password
driver.find_element(:id, 'login').click
sleep(1)

begin
  driver.find_element(:link_text, "home of #{email}")
rescue Selenium::WebDriver::Error::NoSuchElementError
  puts "Login failed or not on the expected page."
  driver.quit
  exit
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
    description = description_element.text.gsub(/\s+/, ' ').strip if description_element

    link_element = driver.find_element(:css, "p > a[target='_blank']")
    url = link_element.attribute("href") if link_element

    image_element = driver.find_element(:css, "div.slide.first.visible > img")
    image_url = image_element.attribute("src") if image_element

    # Avoid writing to CSV and TXT if one of the elements is nil
    missing_elements = []
    missing_elements << 'Title' if title.nil?
    missing_elements << 'Price' if price.nil?
    missing_elements << 'Description' if description.nil?

    if missing_elements.any?
      error_message = "ERROR: Page: #{current_page}, Element: #{index}, Missing: #{missing_elements.join(', ')}"
      puts error_message
    else
      csv_data << [Date.today.strftime('%m-%d'), nil, title, price, url, description]
      txt_data << [title, price_with_dollar, description]
    end

    driver.navigate.back
    wait.until { driver.find_element(:css, 'form.manage.display') }
  end

  begin
    # Wait until the next page link is present
    next_page_link = wait.until {
      driver.find_element(:xpath, "//a[@href='?filter_page=#{current_page + 1}&show_tab=postings']")
    }

    # If the link is found and it's clickable, click it
    if next_page_link&.enabled? && next_page_link.displayed?
      next_page_link.click
      current_page += 1
    else
      break
    end

  rescue Selenium::WebDriver::Error::TimeoutError
    break
  end
end
# Save to CSV
CSV.open('/Users/christopherneal/Desktop/craigslist_poster/scraped_data.csv', 'wb') do |csv|
  csv << ['Date Added', 'Claimed By', 'Title', 'Price', 'URL', 'Description']
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
