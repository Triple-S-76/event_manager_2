require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

def clean_zipcode(zipcode)
  if zipcode.nil?
    zipcode = '00000'
  elsif zipcode.length > 5
    zipcode = zipcode[0..4]
  elsif zipcode.length < 5
    loop do
      zipcode.prepend('0')
      break if zipcode.length == 5
    end
  end
  zipcode
end

def clean_phone_numbers(number)
  new_number = number.gsub(/[-. ()]/, '')
  new_number = '0000000000' if new_number.length < 10
  new_number = new_number[1..-1] if new_number.length == 11 && new_number[0] == '1'
  new_number.insert(3, '-').insert(7, '-')
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    )
    legislators.officials
  rescue
    "WHEN YOU DON'T INCLUDE YOUR ZIPCODE YOU NEED TO FIND THEM YOURSELF!!"
  end

end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/- thanks_#{id} -.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def registration_target_hour_create_hash(regdate, registration_target_hour_hash)
  date = DateTime.strptime(regdate, '%m/%d/%d %H:%M')
  hour = date.hour
  registration_target_hour_hash[hour] = 0 if registration_target_hour_hash[hour].nil?
  registration_target_hour_hash[hour] += 1
end

def registration_target_day_create_hash(regdate, registration_target_day_hash)
  date = DateTime.strptime(regdate, '%m/%d/%d %H:%M')
  day = date.strftime('%A')
  registration_target_day_hash[day] = 0 if registration_target_day_hash[day].nil?
  registration_target_day_hash[day] += 1
end

registration_target_hour_hash = {}
registration_target_day_hash = {}

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_numbers(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  registration_target_hour_create_hash(row[:regdate], registration_target_hour_hash)
  registration_target_day_create_hash(row[:regdate], registration_target_day_hash)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

registration_target_hour_hash_sorted = registration_target_hour_hash.sort_by { |_key, value| value }
registration_target_hour_hash_sorted.reverse!
registration_target_hour_hash_sorted.each { |k, v| puts "Registration in hour #{k}: #{v}" }

registration_target_day_hash_sorted = registration_target_day_hash.sort_by { |_key, value| value }
registration_target_day_hash_sorted.reverse!
registration_target_day_hash_sorted.each { |k, v| puts "Registration on day #{k}: #{v}" }
