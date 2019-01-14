require "selenium-webdriver"
require "nokogiri"
require "scanf"

module NomadicCrawler
  class Crawler
    SLEEP_TIME=3

    attr_reader :target_site
    attr_accessor :driver, :year, :semester

    def initialize(target_site)
      @target_site = target_site

      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless')
      @driver = Selenium::WebDriver.for :chrome, options: options
      
      @driver.navigate.to @target_site
    end

    def fill_in_the_form
      select_tag = Selenium::WebDriver::Support::Select.new(@driver.find_element tag_name: 'select')
      select_tag.select_by(:index, 0)
      year, semester = select_tag.selected_options[0].property(:value).scanf "%4d%1d"

      checkbox_xpath = '//*[@id="select_abeek"]/tbody/tr[2]/td/form/input[2]'
      checkbox    = @driver.find_element xpath: checkbox_xpath
      checkbox.click
      sleep(SLEEP_TIME)

      radio_xpath  = '//*[@id="select_abeek"]/tbody/tr[2]/td/form/input[4]'
      radio_button = @driver.find_element xpath: radio_xpath
      radio_button.click
      sleep(SLEEP_TIME)

      @year = year
      @semester = semester
    end

    def crawl_courses_list(course_category_info)
      courses_list = []
      
      response = HTTParty.post(ENV['COURSE_LIST_SITE'], course_category_info)
      html_doc = Nokogiri.HTML(response.body)
      course_codes_list = html_doc.css('#select_list > tbody > tr > td:nth-child(5)').map do |course_id|
        course_code, course_division = course_id.scanf "%d-%d"
        { course_code: course_code, course_id: course_id }
      end

      courses_list 

      return course_codes_list
    end

    def parse_abstruse_link(text)
      campus, category, department, grade = text.scanf "javascript:gocn4001(%d,%d,'%[^']',%d)"
      return {
        year: @year,
        semester: @semester,
        campus: campus,
        category: category,
        department: department,
        grade: grade,
        is_abeek: 1,
        p_2014: "on",
        p_2016: 2016
      }
    end

    def request_latest_semester_curriculum
      submit_xpath = '//*[@id="select_abeek"]/tbody/tr[2]/td/form/input[7]'
      submit_button = @driver.find_element xpath: submit_xpath
      submit_button.click

      sleep(SLEEP_TIME)

      element = @driver.find_element id: 'table_seoul'
      html_doc = Nokogiri.HTML(@driver.page_source)
      course_category_parameters = html_doc.css("#table_seoul > tbody > tr > td > a").map do |html|
        parse_abstruse_link html.attr('href')
      end      

      courses_list = []
      course_category_parameters.each do |course_category|
        crawled_list = crawl_courses_list(course_category)
        courses_list = [*courses_list, *crawled_list]
      end

      return element
    end


  end
end