local months = {Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12}

function formatTranscript(transcript)
	local header = transcript:find('\n')
	local body = transcript:find('\n', header + 1)

	local day, month, year, author = transcript:sub(header, body - 1):match('Published (%d+) (%a+) (%d+) by (.+)')

	return {
		title = transcript:sub(0, header - 1),
		author = author,
		time = os.time({
			day = day,
			month = months[month:sub(1, 3)],
			year = year
		}),
		data = transcript:sub(body):gsub('[%z\1-\127\194-\244][\128-\191]*', {
			['Á'] = 'A', ['É'] = 'E', ['Í'] = 'I', ['Ó'] = 'O', ['Ú'] = 'U',
			['á'] = 'a', ['é'] = 'e', ['í'] = 'i', ['ó'] = 'o', ['ú'] = 'u'
		}):gsub('[^%w%s]', ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' '):lower()
	}
end

function get(url, cb)
	require('https').request(url, function(res)
		local body = ''
		res:on('data', function(chunk)
			body = body .. chunk
		end)
		res:on('end', function()
			cb(res.statusCode ~= 404 and body)
		end)
	end):done()
end

function Download(url, success, fail, finish)
	get(('https://swaruu.org/download/transcripts/%s/%s/txt'):format('es', url), function(transcript)
		if transcript then
			success(transcript)
			finish()
		else
			get(('https://swaruu.org/download/transcripts/%s/%s/txt'):format('en', url), function(transcript)
				if transcript then
					success(transcript)
				else
					fail()
				end
				finish()
			end)
		end
	end)
end

function loop(cb)
	cb(function()
		loop(cb)
	end)
end

if os.execute('cls') or os.execute('clear') then
	print('## Swaruu Scrapper v1.0.0 ##')
	print()
end
print('- Downloading Transcripts...')
print()
get('https://swaruu.org/transcripts/?author=', function(data)
	local database, transcripts, queue, db = require('json').decode(require('fs').readFileSync('transcripts.json') or '{}'), {}, {}, 0
	for transcript in data:gmatch('><a href="/transcripts/(.-)"') do
		table.insert(transcripts, transcript)
		if not database[transcript] then
			table.insert(queue, transcript)
		else
			db = db + 1
		end
	end
	local diff = #transcripts - db
	print(('- Transcripts Downloaded! %s/%s'):format(db, #transcripts))
	print()
	if #queue > 0 then
		io.write(('=> %s Transcripts missing, want to update? y/n '):format(#queue))
		if (io.read() or 'n'):lower() == 'y' then
			print()
			print('Download Started!')
			print()
			loop(function(cb)
				local url = queue[#queue]
				if not url then
					require('fs').writeFileSync('transcripts.json', require('json').encode(database))
					print()
					print('Download Finished!')
					io.read()
				end
				Download(url, function(transcript)
					db = db + 1
					database[url] = formatTranscript(transcript)
					print(('%s/%s - %s Downloaded'):format(diff - #queue + 1, diff, url))
				end, function()
					print(('Transcript not found! %s'):format(url))
				end, function()
					table.remove(queue, #queue)
					cb()
				end)
			end)
		end
	end
end)