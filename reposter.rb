#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'byebug'

email = 'christopher.m.neal@gmail.com'
password = 'ThatShannonAdkinsisonepieceoface!'

def integer?(input)
  !!input.match(/\A-?\d+\z/)
end

def calculate_price(original_price, percent_discount, flat_discount, manual_reprice)
  if percent_discount && original_price > 8.0
    discounted_price = (original_price * 0.9).round
    discounted_price += 1 unless discounted_price.even?
    discounted_price
  elsif flat_discount && original_price > 8.0
    original_price - flat_discount
  elsif manual_reprice
    puts 'Enter new price or press enter to keep the same price:'
    new_price = $stdin.gets.chomp
    if integer?(new_price)
      new_price.to_i
    else
      original_price
    end
  else
    original_price
  end
end

percent_discount = nil
flat_discount = nil
manual_reprice = nil
if ARGV.length == 1
  case ARGV[0]
  when /^\d+%$/
    percent_discount = ARGV[0].match(/(\d+)/)[1].to_i
  when /^\d+\$$/
    flat_discount = ARGV[0].match(/(\d+)/)[1].to_i
  when 'Y'
    manual_reprice = true
  when 'N'
    manual_reprice = false
  else
    puts 'Would you like to change the prices?'
    puts 'Reply Y/N/percentage/flat amount'
    reply = $stdin.gets.chomp
    case reply
    when 'Y'
      manual_reprice = true
    when 'N'
      manual_reprice = false
    else
      percent_discount = reply.to_i
    end
  end
else
  puts 'Would you like to change the prices?'
  puts 'Reply Y/N/percentage/flat amount'
  reply = $stdin.gets.chomp
  case reply
  when 'Y'
    manual_reprice = true
  when 'N'
    manual_reprice = false
  else
    percent_discount = reply.to_i
  end
end

driver = Selenium::WebDriver.for :chrome
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

current_page = 1
post_count = 0
sleep_duration = 420
loop do
  # Try to find all renew forms
  renew_forms = driver.find_elements(xpath: "//form[@class='manage renew']")
  # If no renew forms are found on the current page
  if renew_forms.empty?
    begin
      # Wait until the next page link is present
      next_page_link = wait.until do
        driver.find_element(:xpath, "//a[@href='?filter_page=#{current_page + 1}&show_tab=postings']")
      end

      # If the link is found and it's clickable, click it
      break unless next_page_link&.enabled? && next_page_link&.displayed?

      next_page_link.click
      current_page += 1
      next # Continue to the next iteration of the loop without executing the rest of the code below
    rescue Selenium::WebDriver::Error::TimeoutError
      break # If waiting for the next page link times out, break the loop
    end
  end

  parent_div = renew_forms.first.find_element(xpath: './..')

  delete_buttons = parent_div.find_elements(xpath: ".//input[@value='delete']")

  visible_delete_buttons = delete_buttons.select(&:displayed?)

  if visible_delete_buttons.any?
    visible_delete_buttons.first.click
  else
    current_page += 1 # go to next page
  end

  driver.find_element(:xpath, "//input[@value='Repost this Posting']").click

  begin
    price_element = wait.until { driver.find_element(:name, 'price') }
  rescue Selenium::WebDriver::Error::TimeoutError
    nil
  end

  if price_element
    original_price = price_element.attribute('value').to_i

    price_to_set = calculate_price(original_price, percent_discount, flat_discount, manual_reprice)

    unless price_to_set == original_price
      price_element.clear
      price_element.send_keys price_to_set.to_s
    end
  end

  continue_button = wait.until do
    driver.find_element(:xpath, "//button[@value='continue']")
  end
  continue_button.click

  publish_button = wait.until do
    driver.find_element(:xpath, "//button[@value='Continue']")
  end
  publish_button.click
  post_count += 1

  begin
    element = wait.until { driver.find_element(:xpath, "//p[contains(text(), 'You are posting too rapidly')]") }
    puts "Uh oh. I'm going too fast... sleep duration is now #{(sleep_duration / 60).to_s}"
    sleep_duration += 60
    post_count = 5
  rescue Selenium::WebDriver::Error::TimeoutError
    # If the element is not found, this block will be executed
    puts 'Successfully reposted!'
  end

  if post_count >= 5
    puts "Sleeping until #{Time.now + sleep_duration}"
    sleep(sleep_duration)
    post_count = 0
  end

  driver.navigate.to "https://accounts.craigslist.org/login/home?filter_page=#{current_page}&show_tab=postings"
end

driver.quit
puts 'Done!'
