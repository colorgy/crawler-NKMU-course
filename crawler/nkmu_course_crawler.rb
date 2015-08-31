require 'nokogiri'
require 'httpclient'
require 'pry'
require 'json'

require 'thread'
require 'thwait'


class NkmuCourseCrawler

  DAYS={
    "一" => "1",
    "二" => "2",
    "三" => "3",
    "四" => "4",
    "五" => "5",
    "六" => "6"
  }

  def initialize year: nil, term: nil
    @year = year
    @term = term
  end

  def courses
    @courses=[]
    @threads=[]

    res1 = clnt.post("http://info.nkmu.edu.tw/nkmu/perchk.jsp", {
      uid: 'guest',
      pwd:  '123',
      sys_name: 'webweb'
    })
    
    res2 = clnt.post "http://info.nkmu.edu.tw/nkmu/fnc.jsp", {
      fncid: 'AG202'
    }

    res3 = clnt.post "http://info.nkmu.edu.tw/nkmu/ag_pro/ag202.jsp?", {
      'arg01': @year-1911,
      'arg02': @term,
      'arg03': 'guest',
      'arg04': '',
      'arg05': '',
      'arg06': '',      
      'fncid': 'AG202'
    }

    res4 = clnt.post "http://info.nkmu.edu.tw/nkmu/ag_pro/ag202.jsp?", {
      'yms_yms': "#{@year-1911}\##{@term}",
      'dgr_id': '%',
      'unt_id': '%',
      'clyear': '',
      'sub_name': '',
      'teacher': '',
      'week': '%',
      'period': '%',
      'yms_year': @year-1911,
      'yms_sms': @term,
      'reading': 'reading'
    }

    @courses_list = Nokogiri::HTML(res4.body)
    
    @courses_list_trs=@courses_list.css('table').last.css('tr')[2..-1]

    @courses_list_trs.each_with_index do | row, index|
      sleep(1) until (
        @threads.delete_if { |t| !t.status };  # remove dead (ended) threads
        @threads.count < 20 ;
      )

      @threads << Thread.new do
        table_data = row.css('td')

        course_divisional = table_data[0].text.strip
        course_department  = table_data[1].text.strip
        course_class = table_data[2].text.strip
        course_general_code = table_data[3].text.strip
        course_name = table_data[4].text.strip
        course_credits = table_data[5].text.strip.to_i
        course_hours = table_data[6].text.strip.to_i
        course_require = table_data[7].text.strip
        course_lecturer = table_data[8].text.strip
        course_classroom = table_data[9].text.strip
        course_time=table_data[11].text.strip

        #Analyize string of course_time.
        course_day_period=[]
        course_time.scan(/\(.\)[^\(]+/).each do |i|
          course_day_period << i.match(/\((?<day>.)\)(?<period>.*)/)
        end

        course_days = []
        course_periods = []
        course_day_period.each do |i|
          (i[:period].split("-").first..i[:period].split("-").last).each do |k|
            course_days << DAYS[i[:day]]
            course_periods << k
          end
        end

        courses = {
          :divisional => course_divisional,
          :department => course_department,
          :class => course_class,
          :general_code => course_general_code,
          :name => course_name,
          :credits => course_credits,
          :hours => course_hours,
          :require => course_require,
          :lecturer => course_lecturer,
          :classroom => course_classroom,
          
          :day_1 => course_days[0],
          :day_2 => course_days[1],
          :day_3 => course_days[2],
          :day_4 => course_days[3],
          :day_5 => course_days[4],
          :day_6 => course_days[5],
          :day_7 => course_days[6],
          :day_8 => course_days[7],
          :day_9 => course_days[8],

          :period_1 => course_periods[0],
          :period_2 => course_periods[1],
          :period_3 => course_periods[2],
          :period_4 => course_periods[3],
          :period_5 => course_periods[4],
          :period_6 => course_periods[5],
          :period_7 => course_periods[6],
          :period_8 => course_periods[7],
          :period_9 => course_periods[8],

        }
        @courses << courses
        print '|'
      end #end thread
    end #end each tr
    ThreadsWait.all_waits(*@threads)
    binding.pry
    return @courses
  end #end courses

  def clnt
    @http_client ||= HTTPClient.new
  end
end

cwl = NkmuCourseCrawler.new(year: 2014, term: 1)
File.write('courses.json', JSON.pretty_generate(cwl.courses))