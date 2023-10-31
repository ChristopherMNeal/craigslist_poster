#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'byebug'
require 'dotenv'

Dotenv.load
Dotenv.require_keys("PASSWORD", "EMAIL")

# Required Login:
EMAIL = ENV['EMAIL']
PASSWORD = ENV['PASSWORD']

def integer?(input)
  !!input.to_s.match(/\A-?\d+\z/)
end

def calculate_price(original_price, title, percent_discount, flat_discount, manual_reprice)
  if percent_discount && original_price >= 8
    discounted_price = (original_price * (1 - percent_discount.to_f/100)).round
    # discounted_price += 1 unless discounted_price.even?
    discounted_price
  elsif flat_discount && original_price >= 5
    original_price - flat_discount
  elsif manual_reprice
    puts 'Enter new price or press enter to keep the same price:'
    puts "#{title}: #{original_price}"
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
repost = false
if ARGV.length == 2
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
  case ARGV[1]
  when 'Y'
    repost = true
  when 'N'
    repost = false
  end
else
  puts 'Would you like to repost? (Y/N)'
  repost = $stdin.gets.chomp == 'Y'
  return unless repost

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

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless') # Use headless mode
options.add_argument('--disable-gpu') # Applicable for Windows OS
options.add_argument('--no-sandbox') # Bypass sandboxing; may be required in some environments
# options.add_argument('--window-size=1050x1168') # Optional, set a default window size
driver = Selenium::WebDriver.for(:chrome, options: options)
wait = Selenium::WebDriver::Wait.new(timeout: 5)
driver.navigate.to 'https://accounts.craigslist.org/login/home'

# def find_element(selector, web_driver: driver)
#   web_driver.find_element(selector)
# rescue Selenium::WebDriver::Error::NoSuchElementError => e
#   <<~ERRMSG
#     Could not find element, please select it and press Enter to continue.'
#       Selector: #{selector}
#       Line: #{caller_locations(1, 1)[0].lineno}
#       Error: #{e.message}
#   ERRMSG
#   $stdin.gets
# end

begin
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
  current_listing = 1
  post_count = 0
  sleep_duration = 60 * 10

  # puts 'Press Enter to begin'
  # $stdin.gets
  # puts "Sleeping until #{Time.now + sleep_duration * 2}"
  # sleep(sleep_duration * 2)

  loop do
    pagination_links = driver.find_elements(:xpath, "//legend[@id='paginator1']/a")
    largest_page_number = pagination_links.map { |link| link.text.to_i }.max

    if current_page > largest_page_number
      break
    end

    listing_selector = if repost
                         # Try to find all renew forms
                         driver.find_elements(xpath: "//form[@class='manage renew']")
                       else
                         # Just repricing, so find all edit forms
                         driver.find_elements(xpath: "//input[@type='submit'][@name='go'][@value='edit'][contains(@class, 'managebtn')]")
                         # <input type="submit" name="go" value="edit" class="managebtn">
                       end
    if repost && listing_selector.count.positive?
      parent_div = listing_selector.first.find_element(xpath: './..')

      delete_buttons = parent_div.find_elements(xpath: ".//input[@value='delete']")

      visible_delete_buttons = delete_buttons.select(&:displayed?)

      if visible_delete_buttons.any?
        visible_delete_buttons.first.click
      else
        current_page += 1 # go to next page
        driver.navigate.to "https://accounts.craigslist.org/login/home?filter_page=#{current_page}&show_tab=postings"
        next
      end

      driver.find_element(:xpath, "//input[@value='Repost this Posting']").click
    elsif listing_selector.count >= current_listing
      listing_selector[0 - current_listing].click
      wait.until { driver.find_element(xpath: "//section[@id='previewButtons']//button[contains(@onclick, '?s=edit')]") }.click
      current_listing += 1
    else
      current_page += 1 # go to next page
      current_listing = 1
      driver.navigate.to "https://accounts.craigslist.org/login/home?filter_page=#{current_page}&show_tab=postings"
      next
    end

    begin
      price_element = wait.until { driver.find_element(:name, 'price') }
    rescue Selenium::WebDriver::Error::TimeoutError
      nil
    end

    if price_element
      original_price = price_element.attribute('value').to_i
      title_element = driver.find_element(:name, 'PostingTitle')
      title_text = title_element.attribute('value').gsub(/[\u{10000}-\u{10FFFF}]/, '')
      title_length = title_text.length
      body = driver.find_element(:name, 'PostingBody')
      body_message = body.attribute('value').gsub(/[\u{10000}-\u{10FFFF}]/, '')

      price_to_set = calculate_price(original_price, title_text, percent_discount, flat_discount, manual_reprice)
      puts "Reposting #{title_text} for $#{price_to_set}"

      if price_to_set != original_price
        price_element.clear
        price_element.send_keys price_to_set.to_s
        # percent_off = 100 - (price_to_set.to_f / original_price * 100).round

        # # black friday promotion
        # if price_to_set < original_price && percent_off.positive?
        #   sale_message = " - BlackFriday sale! - #{percent_off}% off!"
        #   sale_message = if title_length + sale_message.length > 70 && title_length + " - #{percent_off}% off!".length <= 70
        #                    " - #{percent_off}% off!"
        #   elsif title_length + " - #{percent_off}% off!".length > 70
        #     ''
        #   else
        #     sale_message
        #   end
        #   body_sale_message = "#{percent_off}% off through Monday, 11/27! Price was $#{original_price}.00\n\n"
        #
        #   body.clear
        #   body.send_keys body_sale_message + body_message
        #
        #   title_element.send_keys sale_message
        # end

        # remove black friday promotion
      # elsif title_text.split(' ').include?('BlackFriday')
      #   title_text = title_text.gsub(/ - BlackFriday.*/, '')
      # elsif title_text.match(/ - \d+\% off!/)
      #   title_text = title_text.gsub(/ - \d+\%.*/, '')
      #   title_element.clear
      #   title_element.send_keys title_text
      #   price_match = body_message.match(/Price was \$\d+/)
      #   price_string = price_match[0] # Extract the matched string
      #   price = price_string.split('$').last.to_i
      #   price_element.clear
      #   price_element.send_keys price.to_s
      #   body_message = body_message.gsub(%r{\d+% off through Monday, 11/27! Price was \$\d+\.00\n\n}, '')
      #   body.clear
      #   body.send_keys body_message
      #   puts "     Removed BlackFriday promotion from #{title_text}, new price is $#{price}"
      end
    end

    # puts 'Press Enter if everything looks good, or edit it then press enter'
    # $stdin.gets

    continue_button = wait.until do
      driver.find_element(:xpath, "//button[@value='continue']")
    end
    continue_button.click

    publish_button = wait.until do
      driver.find_element(:xpath, "//button[@value='Continue']")
    end
    publish_button.click
    post_count += 1

    if repost && !manual_reprice
      begin
        Selenium::WebDriver::Wait.new(timeout: 2).until { driver.find_element(:xpath, "//p[contains(text(), 'You are posting too rapidly')]") }
        puts "Uh oh. I'm going too fast... sleep duration is now #{sleep_duration / 60}"
        puts "*** #{title_text} *** was not reposted; please manually undelete."
        sleep_duration += 60
        post_count = 5
      rescue Selenium::WebDriver::Error::TimeoutError
        # If the element is not found, this block will be executed
        puts '     Successfully reposted!'
      end

      if post_count >= 5
        puts "Sleeping until #{Time.now + sleep_duration}"
        sleep(sleep_duration)
        post_count = 0
      end
    end

    driver.navigate.to "https://accounts.craigslist.org/login/home?filter_page=#{current_page}&show_tab=postings"
  end
rescue Selenium::WebDriver::Error::WebDriverError => e
    puts 'Webdriver error. Shutting down.'
    puts e.message
rescue Selenium::WebDriver::Error::NoSuchWindowError => e
  puts 'Window closed. Shutting down.'
  puts e.message
rescue Selenium::WebDriver::Error::UnhandledAlertError => e
  puts 'Alert detected. Shutting down.'
  puts e.message
rescue Selenium::WebDriver::Error::UnknownError => e
  puts 'Unknown error. Shutting down.'
  puts e.message
end

driver.quit
puts 'Done!'
