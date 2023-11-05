#!/usr/bin/env ruby
# frozen_string_literal: true

require 'selenium-webdriver'
require 'byebug'

email = 'christopher.m.neal@gmail.com'
password = 'ThatShannonAdkinsisonepieceoface!'

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

loop do
  begin
    wait.until { driver.find_element(:partial_link_text, email) }
  rescue Selenium::WebDriver::Error::TimeoutError
    # If the above element is not found, we assume we're not logged in
    driver.navigate.to 'https://accounts.craigslist.org/login/home'
    email_field = wait.until { driver.find_element(:id, 'inputEmailHandle') }
    email_field.send_keys email

    driver.find_element(:id, 'inputPassword').send_keys password
    driver.find_element(:id, 'login').click
  end

  new_post = wait.until { driver.find_element(:css, "button[type='submit'][value='go']") }
  new_post.click

  driver.find_element(:xpath, "//input[@type='radio' and @name='n' and @value='1']").click
  driver.find_element(:xpath, "//input[@type='radio' and @name='id' and @value='fso']").click

  initial_radio_button_states = driver.find_elements(:css, 'input[type="radio"].json-form-input.id').map(&:selected?)

  loop do
    begin
      # Always refetch the elements to avoid stale references
      radio_buttons = Selenium::WebDriver::Wait.new(timeout: 15).until do
        driver.find_elements(:css, 'input[type="radio"].json-form-input.id')
      end

      current_states = radio_buttons.map(&:selected?)

      if initial_radio_button_states != current_states
        puts 'A radio button was selected!'
        break

        # Optionally, if you want to detect subsequent changes, update the initial states here
        # initial_radio_button_states = current_states.dup
      end

      sleep 0.5 # Wait before checking again

    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      # # If a stale element reference error occurs, simply retry in the next loop iteration
      # next
      puts 'Press enter to fill out the boilerplate.'
      $stdin.gets
      break
    end
  end


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

  next_button = wait.until { driver.find_element(:id, "ui-id-6") }
  next_button.click

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

  puts 'Press Enter to continue...'
  $stdin.gets

  begin
    continue_button = wait.until do
      driver.find_element(:xpath, "//button[@value='continue']")
    end
    continue_button.click

    continue_button = wait.until do
      driver.find_element(:css, ".continue.bigbutton")
      # <button class="continue bigbutton" type="submit">continue</button>
    end
    continue_button.click

    puts 'Add images and press Enter to continue...'
    $stdin.gets

    done_with_images = wait.until do
      driver.find_element(:css, ".done.bigbutton")
      # <button class="done bigbutton" tabindex="1" type="submit" name="go" value="Done with Images">done with images</button>
    end
    done_with_images.click

    publish_button = wait.until do
      driver.find_element(:xpath, "//button[@value='Continue']")
    end
    publish_button.click

    begin
      phone_verification_input = wait.until { driver.find_element(:css, 'input.json-form-input[name="pn_number"]') }
      puts 'Uh oh. Phone verification time. Please enter the code and press Enter.'
      phone_verification_input.send_keys '8504851398'
    rescue Selenium::WebDriver::Error::TimeoutError
      puts 'Published!'
    end
  rescue Selenium::WebDriver::Error::TimeoutError
    puts "Couldn't find the continue button. Press Enter when you're ready for the next post."
  end

  puts "Press 'q' to quit or any other key to repeat..."
  input = $stdin.gets.chomp
  break if input == 'q'

  driver.navigate.to 'https://accounts.craigslist.org/login/home'
end

driver.quit
