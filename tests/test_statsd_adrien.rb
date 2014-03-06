# Load the dogstats module.
require '../lib/statsd'

# Create a stats instance.
statsd = Statsd.new('localhost', 8125)

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

nb = 20
for i in 0..nb
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

# Create several events
nb_events = 10
text_index = ' Agent submit'
test_text = "Test#{text_index}"
j = 0
while true
	statsd.event("Ruby Title #{j} #{test_text}", "Ruby Text #{j} #{test_text}", :hostname => hostnames.sample, :aggregation_key => aggregation_keys.sample, :priority => prioritys.sample,:alert_type => alert_types.sample, :tags => [tagss.sample,tagss.sample])
	j = j + 1
	sleep(10)
end
