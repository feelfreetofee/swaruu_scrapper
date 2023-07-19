local https = require('https')

function get(url, cb)
	https.request(url, function(res)
		local body = ''
		res:on('data', function(chunk)
			body = body .. chunk
		end)
		res:on('end', function()
			cb(res.statusCode ~= 404 and body)
		end)
	end):done()
end

local database, transcripts, queue, db, diff = require('json').decode(require('fs').readFileSync('transcripts.json') or '{}'), {}, {}, 0

function Download()
	local url = queue[#queue]
	get(('https://swaruu.org/download/transcripts/%s/%s/txt'):format('es', url), function(transcript)
		if transcript then
			formatTranscript(url, transcript)
		else
			get(('https://swaruu.org/download/transcripts/%s/%s/txt'):format('en', url), function(transcript)
				if transcript then
					formatTranscript(url, transcript)
				else
					print(('Transcript not found! %s'):format(url))
					table.remove(queue, #queue)
					if #queue > 0 then
						Download()
					else
						print()
						print('Download Finished!')
						io.read()
					end
				end
			end)
		end
	end)
end

local months = {Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12}

function formatTranscript(url, transcript)
	local header = transcript:find('\n')
	local body = transcript:find('\n', header + 1)

	local day, month, year, author = transcript:sub(header, body - 1):match('Published (%d+) (%a+) (%d+) by (.+)')

	database[url] = {
		title = transcript:sub(0, header - 1),
		author = author,
		time = os.time({
			day = day,
			month = months[month:sub(1, 3)],
			year = year
		}),
		data = transcript:sub(body):gsub('\n', ' '):gsub('%s+', ' '):gsub('[%z\1-\127\194-\244][\128-\191]*', {
			['Á'] = 'A', ['É'] = 'E', ['Í'] = 'I', ['Ó'] = 'O', ['Ú'] = 'U',
			['á'] = 'a', ['é'] = 'e', ['í'] = 'i', ['ó'] = 'o', ['ú'] = 'u'
		}):lower()
	}

	db = db + 1

	print(('%s/%s - %s Downloaded'):format(diff - #queue, diff, url))

	if #transcripts == db then
		require('fs').writeFileSync('transcripts.json', require('json').encode(database))
		print()
		print('Download Finished!')
		io.read()
	else
		table.remove(queue, #queue)
		Download()
	end
end

if os.execute('cls') or os.execute('clear') then
	print('## Swaruu Scrapper v1 ##')
	print()
end
print('- Downloading Transcripts...')
print()
get(('https://swaruu.org/transcripts/?author='):format(''), function(data)
	for transcript in data:gmatch('><a href="/transcripts/(.-)"') do
		table.insert(transcripts, transcript)
		if not database[transcript] then
			table.insert(queue, transcript)
		else
			db = db + 1
		end
	end
	diff = #transcripts - db
	print(('- Transcripts Downloaded! %s/%s'):format(db, #transcripts))
	print()
	if #queue > 0 then
		io.write(('=> %s Transcripts missing, want to update? y/n '):format(#queue))
		if (io.read() or 'n'):lower() == 'y' then
			print()
			print('Download Started!')
			print()
			Download()
		else
			print()
			print('Update Canceled!')
			io.read()
		end
	else
		print('Database Up to Date!')
		io.read()
	end
end)