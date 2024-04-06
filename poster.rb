#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'byebug'
require 'json'
require 'dotenv'
Dotenv.load
Dotenv.require_keys("PASSWORD", "EMAIL", "SHORT_WAIT_SECONDS", "LONG_WAIT_SECONDS", "ZIP_CODE")

# Required Login:
EMAIL = ENV['EMAIL']
PASSWORD = ENV['PASSWORD']

# Configs
AUTO_REPEAT = ENV['AUTO_REPEAT'] == 'true'
THROTTLE_POST_SECONDS = ENV['THROTTLE_POST_RATE'] || 60 * 10 # 10 minutes default
AUTOMATICALLY_CONFIRM_MAP = ENV['AUTOMATICALLY_CONFIRM_MAP'] == 'true'
USE_PREV_POST_AS_TEMPLATE = ENV['USE_PREV_POST_AS_TEMPLATE'] == 'true'
SHORT_WAIT_SECONDS = ENV['SHORT_WAIT_SECONDS']&.to_i || 3
LONG_WAIT_SECONDS = ENV['LONG_WAIT_SECONDS']&.to_i || 10

# City info
CITY_NAME = ENV['CITY_NAME'] || ''
STATE_ABBR = ENV['STATE_ABBR'] || ''
CITY_FOR_SELECT_BY = ENV['CITY_FOR_SELECT_BY'] || '' # Optional, see .env file

# Posting location
NEIGHBORHOOD = ENV['NEIGHBORHOOD'] || ''
CITY_NAME_FOR_FORM = ENV['CITY_NAME_FOR_FORM'] || "#{CITY_NAME}, #{STATE_ABBR}"
ZIP_CODE = ENV['ZIP_CODE'] || ''

# Posting body
POSTING_TITLE = ENV['POSTING_TITLE'] || ''
DEFAULT_PRICE = ENV['DEFAULT_PRICE'] || ''
POST_BODY = ENV['POST_BODY'] || ''

# Constants for drop downs on new post form
LANGUAGES = %w[- affrikaans català dansk deutsh english espanol suomi français italiano nederlands norsk português
               svenska filipino türkçe 中文 日本語 한국말 русский tiâng viêt].freeze
LANGUAGE = ENV['LANGUAGE'] || LANGUAGES[5]
CONDITIONS = ['-', 'new', 'like new', 'excellent', 'good', 'fair', 'salvage'].freeze
CONDITION = ENV['CONDITION'] || 'good'

# Checkboxes
SEE_MY_OTHER = ENV['SEE_MY_OTHER'] == 'true'
CRYPTO_PAYMENT = ENV['CRYPTO_PAYMENT'] == 'true'
DELIVERY_AVAIL = ENV['DELIVERY_AVAIL'] == 'true'

# Phone info: If SHOW_PHONE is true, the following fields can be filled out
SHOW_PHONE = ENV['SHOW_PHONE'] == 'true'
CONTACT_BY_PHONE = ENV['CONTACT_BY_PHONE'] == 'true'
CONTACT_BY_TEXT = ENV['CONTACT_BY_TEXT'] == 'true'
PHONE_NUMBER = ENV['PHONE_NUMBER'] || ''
PHONE_CONTACT_NAME = ENV['PHONE_CONTACT_NAME'] || ''

# Address info: If SHOW_ADDRESS is true, the following fields can be filled out
SHOW_ADDRESS = ENV['SHOW_ADDRESS'] == 'true'
MAP_STREET = ENV['MAP_STREET'] || ''
MAP_CROSS_STREET = ENV['MAP_CROSS_STREET'] || ''

@driver = Selenium::WebDriver.for :chrome
short_wait = Selenium::WebDriver::Wait.new(timeout: SHORT_WAIT_SECONDS)
long_wait = Selenium::WebDriver::Wait.new(timeout: LONG_WAIT_SECONDS)

def wait_and_find(wait, klass, value, purpose = 'unknown', click: false)
  element = wait.until { @driver.find_element(klass, value) }
  element.click if click
  element
rescue Selenium::WebDriver::Error::TimeoutError
  wait_for_input("Error finding #{purpose} element from #{klass}: #{value}. Navigate to the correct page and press Enter.")
  nil
end

def wait_and_find_elements(wait, klass, value)
  wait.until { @driver.find_elements(klass, value).any? }
  @driver.find_elements(klass, value)
rescue Selenium::WebDriver::Error::TimeoutError
  puts "Could not find any elements with #{klass}: #{value}"
end

def wait_for_input(message)
  puts message
  $stdin.gets
end

def login(short_wait, long_wait)
  @driver.navigate.to 'https://accounts.craigslist.org/login/home'

  wait_and_find(short_wait, :id, 'inputEmailHandle', 'email field')&.send_keys EMAIL
  wait_and_find(short_wait, :id, 'inputPassword', 'password field')&.send_keys PASSWORD

  wait_and_find(long_wait, :id, 'login', 'login button', click: true)
rescue Selenium::WebDriver::Error::NoSuchElementError
  wait_for_input('Trouble logging in. Plz help and press Enter.')

end

def select_city_from_dropdown(wait) # rubocop:disable Metrics
  cities_file = File.read('cities.json')
  cities_data = JSON.parse(cities_file)

  city_option = cities_data['cities'].find do |city|
    city['name'].downcase == CITY_FOR_SELECT_BY.downcase ||
      city['name'].downcase == "#{CITY_NAME.downcase}, #{STATE_ABBR.downcase}" ||
      city['name'].downcase == CITY_NAME.downcase
  end

  if city_option
    select_element = wait_and_find(wait, :id, 'ui-id-1', 'city dropdown')
    select_list = Selenium::WebDriver::Support::Select.new(select_element)
    begin
      select_list.select_by(:value, city_option['value'])
    rescue Selenium::WebDriver::Error::NoSuchElementError
      begin
        select_list.select_by(:text, city_option['name'])
      rescue Selenium::WebDriver::Error::NoSuchElementError
        puts 'City not found in the dropdown.'
      end
    end
  else
    puts 'City not found in the JSON file.'
  end
end

# Begin script
login(short_wait, long_wait)

begin
  wait_and_find(short_wait, :link_text, "home of #{EMAIL}", 'email link')
rescue Selenium::WebDriver::Error::NoSuchElementError
  wait_for_input('Login failed or not on the expected page. Please navigate to the correct page and press Enter.')
end


count = 0
throttle_start_time = Time.now
loop do
  begin
    wait_and_find(short_wait, :partial_link_text, EMAIL, 'email link')
  rescue Selenium::WebDriver::Error::TimeoutError
    login(short_wait, long_wait)
  end

  # Add select for city here too from `new_posting_in_cities.json` ?
  wait_and_find(short_wait, :css, "button[type='submit'][value='go']", 'new posting in button', click: true)
  # Re-use selected data from your previous posting...?
  button_name = USE_PREV_POST_AS_TEMPLATE ? 'continue' : 'brand_new_post'
  wait_and_find(short_wait, :css, "button[type='submit'][name=#{button_name}][value='1']", 'use prev post', click: true)
  unless USE_PREV_POST_AS_TEMPLATE
    select_city_from_dropdown(short_wait)
    wait_and_find(short_wait, :css, "button[type='submit'][name='go']", 'continue after select city', click: true)
  end
  wait_and_find(short_wait, :css, "input[type='radio'][name='id'][value='fso']", 'for sale radio button', click: true)

  # unless already has value from previous post
  initial_button_states =
    wait_and_find_elements(short_wait, :css, 'input[type="radio"].json-form-input.id')&.map(&:selected?)

  wait_count = 0
  loop do
    # Re-fetching the elements to avoid stale references
    radio_buttons = @driver.find_elements(:css, 'input[type="radio"].json-form-input.id')
    current_states = radio_buttons&.map(&:selected?)
    break unless initial_button_states && current_states

    if initial_button_states != current_states
      puts 'A radio button was selected!'
      break
    end

    puts "waiting#{'.' * (wait_count / 6)}" if wait_count % 6 == 0
    sleep 0.5
    wait_count += 1
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    wait_for_input('Stale Element error from radio buttons. Press enter to fill out the boilerplate.')
    break
  end

  wait_and_find(short_wait, :id, 'geographic_area', 'neighborhood field')&.send_keys NEIGHBORHOOD # unless already has value from previous post
  wait_and_find(short_wait, :id, 'postal_code', 'zip code field')&.send_keys ZIP_CODE
  wait_and_find(short_wait, :id, 'PostingBody', 'posting body')&.send_keys POST_BODY
  wait_and_find(short_wait, :name, 'price', 'price field')&.send_keys DEFAULT_PRICE

  if CONDITION.present?
    wait_and_find(short_wait, :id, 'ui-id-1-button', 'open condition dropdown', click: true)
    condition_ui_id_number = CONDITIONS.find_index(CONDITION) + 3
    wait_and_find(short_wait, :id, "ui-id-#{condition_ui_id_number}", 'set condition', click: true)
  end

  if LANGUAGE.present?
    wait_and_find(short_wait, :id, 'ui-id-2-button', 'open language dropdown', click: true)
    language_ui_id_number = LANGUAGES.find_index(LANGUAGE) + 10
    wait_and_find(short_wait, :id, "ui-id-#{language_ui_id_number}", 'set language', click: true)
  end

  # Possibly any of these could be filled from a previous posting. Either way should rewrite it to be more dry.
  wait_and_find(short_wait, :name, 'see_my_other', 'see other posts box', click: true) if SEE_MY_OTHER
  wait_and_find(short_wait, :name, 'crypto_currency_ok', 'cryptocurrency ok box', click: true) if CRYPTO_PAYMENT
  wait_and_find(short_wait, :name, 'delivery_available', 'deliver available box', click: true) if DELIVERY_AVAIL
  if SHOW_PHONE
    wait_and_find(short_wait, :name, 'show_phone_ok', 'show phone number box', click: true)
    wait_and_find(short_wait, :name, 'contact_phone_ok', 'contact by phone box', click: true) if CONTACT_BY_PHONE
    wait_and_find(short_wait, :name, 'contact_text_ok', 'contact by text box', click: true) if CONTACT_BY_TEXT
    wait_and_find(short_wait, :name, 'contact_phone', 'phone number field')&.send_keys PHONE_NUMBER
    wait_and_find(short_wait, :name, 'contact_phone_extension', 'phone extension field')&.send_keys PHONE_EXTENSION
    wait_and_find(short_wait, :name, 'contact_name', 'phone contact name field')&.send_keys PHONE_CONTACT_NAME
  end
  if SHOW_ADDRESS
    wait_and_find(short_wait, :name, 'show_address_ok', 'show address box', click: true)
    wait_and_find(short_wait, :name, 'xstreet0', 'cross street 1')&.send_keys MAP_STREET
    wait_and_find(short_wait, :name, 'xstreet1', 'cross street 2')&.send_keys MAP_CROSS_STREET
    wait_and_find(short_wait, :name, 'city', 'city name')&.send_keys CITY_NAME_FOR_FORM
  end

  wait_for_input('Press Enter to continue...')

  begin
    wait_and_find(short_wait, :css, "button[type='submit'][name='go']", 'submit post', click: true)
    if AUTOMATICALLY_CONFIRM_MAP
      wait_and_find(short_wait, :css, '.continue.bigbutton', 'confirm map', click: true)
    else
      wait_for_input('Please confirm the map and press Enter to continue...')
    end

    wait_for_input('Add images and press Enter to continue...')

    wait_and_find(short_wait, :css, '.done.bigbutton', 'submit images', click: true)
    wait_and_find(short_wait, :xpath, "//button[@value='Continue']", 'publish', click: true)

    begin
      phone_verify_input = short_wait.until { @driver.find_element(:css, 'input.json-form-input[name="pn_number"]') }
      puts 'Uh oh. Phone verification time. Please enter the code and press Enter.'
      phone_verify_input&.send_keys PHONE_NUMBER
    rescue Selenium::WebDriver::Error::TimeoutError
      puts 'Published!'
    end
  rescue Selenium::WebDriver::Error::TimeoutError
    puts "Couldn't find the continue button. Press Enter when you're ready for the next post."
  end

  # Throttle posts to 5 every 10 minutes (or whatever the configuration is), otherwise Craigslist will show an error page.
  if count % 5 == 0 && Time.now - throttle_start_time < THROTTLE_POST_SECONDS
    puts "Throttling until #{(throttle_start_time + THROTTLE_POST_SECONDS).strftime('%H:%M:%S')}"
    sleep 1 until Time.now - throttle_start_time >= THROTTLE_POST_SECONDS
    throttle_start_time = Time.now
  end

  unless AUTO_REPEAT
    puts "Press 'q' to quit or any other key to repeat..."
    input = $stdin.gets.chomp
    break if input == 'q'
  end

  @driver.navigate.to 'https://accounts.craigslist.org/login/home'
end

@driver.quit
