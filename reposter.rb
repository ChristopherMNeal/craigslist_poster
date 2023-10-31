#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'nokogiri'
require 'csv'
require 'byebug'

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
  renew_form = wait.until {
    driver.find_element(xpath: "//form[@class='manage renew']")
  }

  parent_div = renew_form.find_element(xpath: "./..")

  delete_buttons = parent_div.find_elements(xpath: ".//input[@value='delete']")

  visible_delete_buttons = delete_buttons.select(&:displayed?)

  if visible_delete_buttons.any?
    visible_delete_buttons.first.click
  else
    current_page += 1 # go to next page
  end

  driver.find_element(:xpath, "//input[@value='Repost this Posting']").click

  original_price = driver.find_element(:name, 'price').attribute('value').to_i

  if lower_price? && original_price > 8.0
    discounted_price = (original_price * 0.9).round
    discounted_price += 1 unless discounted_price.even?
    price_to_set = discounted_price
  else
    price_to_set = original_price
  end

  driver.find_element(:name, 'price').send_keys price_to_set.to_s

  driver.find_element(:class, 'managebtn').click
  <input type="submit" name="go" value="Repost this Posting" class="managebtn">


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
