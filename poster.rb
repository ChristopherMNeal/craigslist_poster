#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'

email = 'christopher.m.neal@gmail.com'
password = "Gina'sbottomisfurry"

loop do
  driver = Selenium::WebDriver.for :chrome
  driver.navigate.to 'https://accounts.craigslist.org/login/home'

  driver.find_element(:id, 'inputEmailHandle').send_keys email
  driver.find_element(:id, 'inputPassword').send_keys password
  driver.find_element(:id, 'login').click
  sleep(1)

  driver.find_element(:css, "button[type='submit'][value='go']").click

  sleep(1)

  driver.find_element(:xpath, "//input[@type='radio' and @name='n' and @value='1']").click

  driver.find_element(:xpath, "//input[@type='radio' and @name='id' and @value='fso']").click

  puts "Press Enter to continue..."
  gets

  driver.find_element(:id, "geographic_area").send_keys "Arbor Lodge, Portland"
  driver.find_element(:id, "postal_code").send_keys "97217"
  posting_signoff = <<~POSTING_SIGNOFF
    
    
    Feel free to text or call. I'm free just about anytime so just let me know when you'd like to come by!
    I'll take this listing down when it is sold.
  POSTING_SIGNOFF
  driver.find_element(:id, "PostingBody").send_keys posting_signoff

  # Select dropdown option (assuming the dropdown uses the Select UI element)
  # dropdown = Selenium::WebDriver::Support::Select.new(driver.find_element(:id, "YOUR_DROPDOWN_ID_HERE"))
  # dropdown.select_by_value("ui-id-6") # or dropdown.select_by_visible_text("excellent")

  driver.find_element(:id, "ui-id-1-button").click
  sleep(1) # consider using WebDriverWait instead
  driver.find_element(:id, "ui-id-6").click

  driver.find_element(:name, "see_my_other").click
  driver.find_element(:name, "delivery_available").click
  driver.find_element(:name, "show_phone_ok").click
  driver.find_element(:name, "contact_phone_ok").click
  driver.find_element(:name, "contact_text_ok").click
  driver.find_element(:name, "contact_phone").send_keys "8504851398"
  driver.find_element(:name, "contact_name").send_keys "Chris"
  driver.find_element(:name, "show_address_ok").click
  driver.find_element(:name, "xstreet0").send_keys "Interstate"
  driver.find_element(:name, "xstreet1").send_keys "Webster"
  driver.find_element(:name, "city").send_keys "Portland"

  puts "Press 'q' to quit or any other key to repeat..."
  input = gets.chomp
  break if input == 'q'
end
driver.quit
