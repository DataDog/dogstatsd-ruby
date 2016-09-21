# Here, we generate random sets of parameters that can be passed when posting an event
# Title and text are compulsory but all the other ones are optional


# Load the dogstats module.
require '../lib/datadog/statsd'

# Create a stats instance.
statsd = Datadog::Statsd.new('localhost', 8125)

# Data to run random tests
titles = Array.new
texts =Array.new
alert_types = ['error','warning','info','success']
aggregation_keys = Array.new
source_type_names = Array.new
date_happeneds = Array.new
prioritys = ['low','normal']
tagss = Array.new
hostnames = Array.new

# Generate random or nil values for every type of parameter
# ONLY VALID VALUES (alert_type for instance only accepts a certain range of values)
20.times do |i|
	titles.push("Title_#{i}")
	texts.push("Text_#{i}")
	tagss.push("tag_#{i}")
	if i % 2 == 0
		aggregation_keys.push(nil)
		source_type_names.push(nil)
		date_happeneds.push(Time.now.to_i)
		hostnames.push(nil)
	else
		aggregation_keys.push("aggkey_#{i}")
		source_type_names.push("source_type_name_#{i}")
		date_happeneds.push(1393019472)
		hostnames.push("hostname_#{i}")
	end
end

# Create several events that use random values from the sets of values created above, every sleep_time seconds
text_index = ' Agent submit'
test_text = "Test#{text_index} \n 2nd line"
sleep_time = 10
nb_events = 4
j = 0
while true
	for i in 0..nb_events
		statsd.event("Title #{i} #{test_text}", "Ruby Text #{j} #{test_text}", :hostname => hostnames.sample, :aggregation_key => "|#NOT_TAG", :priority => prioritys.sample,:alert_type => alert_types.sample, :tags => ["before|pinguin"])
	end
	j = j + 1
	sleep(sleep_time)
end
