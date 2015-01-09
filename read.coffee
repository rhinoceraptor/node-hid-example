hid = require('node-hid')
fs = require('fs')

# Get character mapping from the JSON file synchronously
map = JSON.parse(fs.readFileSync('char_map.json'))

# Set up the magstripe device, exit if none or more than one are plugged in
device_array = hid.devices('0x0801', '0x0001')

# Exit if we have none or more than one reader plugged in
if device_array.length > 1
  console.log 'More than one magstripe reader is plugged in!'
  process.exit(1)
else if device_array.length is 0
  console.log 'No magstripe reader is plugged in!'
  process.exit(1)

device = device_array[0]
magstripe = new hid.HID(device.path)

# Register data event callback
magstripe.on('data', (data) ->
  # Every other data array will be all 0x00 bytes, skip them
  if data? and data[2] isnt '0' and data[2] isnt 0
    card_builder(data, (card) ->
      console.log card
      card_builder('done')
    )
)

# Register error callback
magstripe.on('error', (err) ->
  console.log err
  process.exit(1)
)

# Used to store the current card string in memory
card = ''

# Accumulator function for building the string contained on the card track
card_builder = (data, callback) ->
  if data is 'done'
    card = ''
  # The Magtek reader sends 0x58 in the third byte in the array when it is
  # done with the current track. In the manual, this maps to KEYPAD_ENTER.
  if map.lower[String(data[2])] is 'KEYPAD_ENTER'
    callback(card)
  else
    # The first byte in the array is the shift byte. If it is 0x00, we have a
    # lower case character. If it is 0x02, we have an upper case character.
    # The third byte in the array is the character index that we will look up
    # in the JSON mapping, copied from the Magtek manual. Your reader may vary.
    if data[0] is 0
      card += map.lower[String(data[2])]
    else if data[0] is 2
      card += map.upper[String(data[2])]
