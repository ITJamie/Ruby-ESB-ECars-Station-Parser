# Dealing with ESB Irelands Crazy kml file which contains the status of their chargers
# @ESBIreland if you ever plan on creating an API call me. This shit is insane!


require 'net/http'
require 'uri'
require "awesome_print"
require "json"
require 'active_support/all'
require 'time'


debugenabled=false
repeatloop=10
currentloop=0

while currentloop < repeatloop
	ap "loop #{currentloop} of upto #{repeatloop}"
	uri = URI.parse("http://esb.ie/electric-cars/kml/charging-locations.kml")
	response = Net::HTTP.get_response(uri)


	ap 'Response code from esb kml: '+response.code
	ap 'KML was created: '+response['last-modified']


	temptimestamp=Time.parse(response['last-modified']).to_i
	ap 'temptimestamp '+temptimestamp.to_s
	currenttimestamp=Time.now.to_i
	ap 'currenttimestamp '+currenttimestamp.to_s
	timedifference= currenttimestamp - temptimestamp
	ap 'timedifference '+timedifference.to_s
	if (timedifference > 300)
		ap 'time difference is bigger than 5 minutes'
	else
		ap 'time difference is less than 5 minutes'
		break
	end
	currentloop+1
end

abort('response was not as expected') if (response.code.to_str != "200")

styleHash=Hash.from_xml(response.body)['kml']['Document']['Style']
placemarksHash=Hash.from_xml(response.body)['kml']['Document']['Placemark']

#placemarksHash

if (placemarksHash.count < 1)
	abort("Didnt get enough objects")
end

#### processor for 
CleanArrayOfLocations = Array.new
print "About to parse #{placemarksHash.count} items\n "
placemarksHash.each_with_index do |item, itemindex|
	print "parsing item: "+itemindex.to_s+"\n"
	if !( item['description'].include?'pale coloured icon'  ) #ignore items that esb dont monitor
		tempLocationHash = Hash.new
		ap item if debugenabled
		ap itemindex if debugenabled
		olddescription = item['description'].gsub(/<\/?[^>]*>/, "").remove("Instructional Video","Google Map")
		print olddescription if debugenabled
		stationsfound = Array.new
		openingHours = "" #setting blank values for this station
		parkingStatus = "" #setting blank values for this station
		stationid = "" #setting blank values for this station
		olddescription.each_line do |line|
			if line.include?('CP:')
				temphash = Hash.new #create a hash to hold all status and type of station
				stationline=line.split('CP:')
				bracketcontent=stationline[0].scan(/\(([^\)]+)\)/)
				temphash[:StationStatus] = bracketcontent.last.first #set status of station

				if (stationid == "") #check if stationid has been set yet
					stationIDRough=stationline[1]
					if stationIDRough.include?(' ')
						stationid = stationIDRough.split(' ')[0].remove("\n")
					else
						stationid = stationIDRough.split('<BR>')[0].remove("\n")
					end
					print 'station id is '+stationid+"\n" if debugenabled
				end

				roughbracketcontent = stationline[0].split('(')

				if roughbracketcontent.count >2 #if there is more than 1 set of brackets
					print "Found two or more brackets\n" if debugenabled
					ap roughbracketcontent if debugenabled
					temphash[:StationType] = roughbracketcontent[0]+roughbracketcontent[1].remove(')')

				elsif roughbracketcontent.count == 2
					temphash[:StationType] = roughbracketcontent[0]

				elsif roughbracketcontent.count == 1
					abort("Something fucked up happened!\n")
				end
				stationsfound.push(temphash)
			end
			if ( line.include?('Opening Hours') || line.include?('Mon-') || line.include?('24 hour access') )
				openingHours = line.remove("\n")
			end
			if ( line.include?('parking') || line.include?('Parking') )
				parkingStatus = line.remove("\n")
			end
		end # end of description line loop
		ap stationsfound if debugenabled
		tempLocationHash[:stationID]=stationid
		tempLocationHash[:name]=item['name']
		tempLocationHash[:latlong]=item['Point']['coordinates']
		tempLocationHash[:OpeningHours]=openingHours
		tempLocationHash[:parkingInfo]=parkingStatus
		tempLocationHash[:chargers]=stationsfound
		tempLocationHash[:origionaldescription] = olddescription
		if (stationsfound.count > 0) #if we found stations with a CP number they will be in this array
			CleanArrayOfLocations.push(tempLocationHash)
		end
		print "Found #{stationsfound.count} station(s) in item: "+itemindex.to_s+"\n"
	else # end of if station is not monitored ( pale coloured icon )
		print "No monitorable stations in item: "+itemindex.to_s+"\n"
	end # end of if station is not monitored ( pale coloured icon )
end

print "\ngot to end\n"

#ap CleanArrayOfLocations


