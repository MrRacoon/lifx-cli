
## LIFX-Client

Create the lifx object

    lifxObj = require 'lifx-api'

A color parser

    colorParser = require 'parse-color'

Require the fs library for file handling

    fs      = require 'fs'


## Command Line Argument Parsing

    opts = require 'node-getopt'
        .create [
            ['t' ,  'token=ARG'      ,  'the token in plainText'],
            [''  ,  'tokenFile=ARG'  ,  'the file that houses the lifx token in json format'],
            [''  ,  'toggle[=ARG]'   ,  'toggle the power of the bulbs'],
            [''  ,  'on[=SELECTOR]'  ,  'turn on the lights'],
            [''  ,  'off[=ARG]'      ,  'turn off the lights'],
            ['s' ,  'status'         ,  'show the status of the lights'],
            [''  ,  'color=ARG'      ,  'set color (blue, red, pink...)'],
            [''  ,  'hue=ARG'        ,  'set color using hue (0-360)'],
            [''  ,  'rgb=ARG'        ,  'set color using rgb (#RRGGBB)'],
            [''  ,  'kelvin=ARG'     ,  'set kelvin (2500-9000)'],
            [''  ,  'brightness=ARG' ,  'set brightness (0.0-1.0)'],
            [''  ,  'saturation=ARG' ,  'set saturation (0.0-1.0)'],
            [''  ,  'brightnessUp'   ,  'increase the brightness'],
            [''  ,  'brightnessDown' ,  'decrease the brightness'],
            [''  ,  'kelvinUp'       ,  'increase the kelvin'],
            [''  ,  'kelvinDown'     ,  'decrease the kelvin'],
            [''  ,  'saturationUp'   ,  'increase the saturation'],
            [''  ,  'saturationDown' ,  'decrease the saturation'],
            [''  ,  'logFile=ARG'    ,  'specify a log file to use (default: /tmp/lifx-cli.log)' ],
            ['h' ,  'help'           ,  'display this help'],
            ['v' ,  'verbose'        ,  'Log out verbose messages to the screen' ]
        ]
        .bindHelp()
        .parseSystem()

I like me a good `console.log` alias. Here we decorate it with things like
verbosity checking and logging to a file in tmp (or some other file specified
by the `--logFile` flag)

    writeToLogFile = (args...) ->
        logFile = o.logFile or '/tmp/lifx-cli.log'
        str     = args
            .concat ['\n']
            .join ' '
        fs.appendFile logFile, str

    log = (args...) ->
        addTime = [new Date()].concat(args)
        writeToLogFile addTime
        if verbose
            console.log.apply null, addTime

Make an alias to the options for convinience, and also check and set the
verbosity level of the app.

    o       = opts.options
    log o

    verbose = o.verbose
    log "verbose mode is set to #{verbose}"

## Getting the token

Check to see if a token was specified in the arguments. If not, let's look for
it on disk. Check to see if the user specified a file to look in, otherwise
default to `~/.lifx_token`

    if o.token?
        token = o.token
    else
        home         = process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE
        fileLocation = o.tokenFile or home + '/.lifx_token'

Make an attempt to open the file and log the error if the action is
unseuccessful. Without the token this app is useless, so if an error occurs, we
will immediatly halt execution.

        try
            fileContents = fs.readFileSync fileLocation
        catch err
            log err
            return

At this point the file exists, so let's see if it is JSON, and if so, get the
token property from the parsed object. Otherwise, assume that the contents of
the file was the raw token and clean it up a bit.

        try
            tokenObj = JSON.parse fileContents
            token    = tokenObj.token
        catch e
            token    = fileContents
                .replace /\r?\n|\r/, ''
                .replace /\w/, ''

Finally, initialize the lifx object wit our token. Now we are ready to send out
some instructions!

    lifx = new lifxObj token

## Handy functions

Get and set the status of the lights

    getStatus = (cb=log) ->
        log "Getting Status"
        lifx.listLights 'all', cb

Turn the lights on or off

    power = (selector, state, duration=1.0, cb=log) ->
        if (selector == '')
            selector = "all"
        if state?
            nex = if state then "on" else "off"
            log "turning bulbs #{nex}"
            lifx.setPower selector, nex, duration, cb
        else
            log "toggling bulbs"
            lifx.togglePower selector, cb

Set a property of a bulb

    setProp = (prop, sel="all", dur=1.0, power=true, cb=log) ->
        log "Setting bulb(s) #{sel} to state #{prop}"
        lifx.setColor sel, prop, dur, power, cb

    setHue = (prop, sel="all", dur=1.0, power=true, cb=log) ->
        setProp "hue:#{prop}", sel, dur, power, cb

    setBrightness = (prop, sel="all", dur=1.0, power=true, cb=log) ->
        setProp "brightness:#{prop}", sel, dur, power, cb

    setKelvin = (prop, sel="all", dur=1.0, power=true, cb=log) ->
        setProp "kelvin:#{prop}", sel, dur, power, cb

    setSaturation = (prop, sel="all", dur=1.0, power=true, cb=log) ->
        setProp "saturation:#{prop}", sel, dur, power, cb

## Putting all the logic together

Toggle the lights on/off

    if ! (o.toggle == undefined)
        power o.toggle

Power the lights on

    if ! (o.on == undefined)
        power o.on, on

Power the lights off

    if ! (o.off == undefined)
        power o.off, off

Get the status of the lights

    if ! (o.status == undefined)
        getStatus()

## State modifications

Below are high level interfaces to modify the current state by slight
differences. For instance, turning up the current brightness as opposed to
setting it to a specific value.

The payload from `getStatus` returns the following list of objects denoting a
bulbs current state:

```json
[
  {
      "id": "d3b2f2d97452",
      "uuid": "8fa5f072-af97-44ed-ae54-e70fd7bd9d20",
      "label": "Left Lamp",
      "connected": true,
      "power": "on",
      "color": {
            "hue": 250.0,
            "saturation": 0.5,
            "kelvin": 3500
          },
      "brightness": 0.5,
      "group": {
            "id": "1c8de82b81f445e7cfaafae49b259c71",
            "name": "Lounge"
          },
      "location": {
            "id": "1d6fe8ef0fde4c6d77b0012dc736662c",
            "name": "Home"
          },
      "last_seen": "2015-03-02T08:53:02.867+00:00",
      "seconds_since_seen": 0.002869418
    }
]

```

Couple functions to get information from a bulb, will come into play later

We first wrap get status with a higher order function to modify this payload.
We will expect that functions passed into it expect one bulb entry at a time.

    modify = (func) ->
        getStatus (payload) ->
            arr = JSON.parse payload
            arr.forEach(func)

    changeAttribute = (config, isAdd) ->
        (bulb) ->
            id  = bulb.id
            log "id is #{id}"

            cur = config.current bulb
            log "cur is #{cur}"

            if (isAdd)
                nex = cur + config.step
            else
                nex = cur - config.step

            log "nex is #{nex}"

            # If the config specifies that the range is circular, ignore bounds
            # and loop around
            if config.circular
                nex = nex % config.max
                log "circular nex is #{nex}"
            # Ensure that the nex value is within the configured bounds
            else if config.min < nex < config.max
                nex = nex
            # Otherwise if the stp was increasing, set nex to the maximum
            else if nex > config.max
                log "Hit Maximum bound"
                nex = config.max
            # Otherwise if the stp was dencreasing, set nex to the minimum
            else if nex < config.min
                log "Hit Minimum bound"
                nex = config.min
            else
                log "Not sure what is happening with the nex value, defaulting"
                nex = config.default


            config.change nex, id

Set attributes light color, brightness, etc... 

Brightness adjustments

    getBrightness = (bulb) -> bulb.brightness

    brightnessAdjustments =
        change : setBrightness
        current: getBrightness
        step   : 0.1
        min    : 0.0
        max    : 1.0

    if o.brightness?
        setBrightness o.brightness

    if o.brightnessUp?
        increaseBrightness = changeAttribute brightnessAdjustments, true
        modify increaseBrightness

    if o.brightnessDown?
        decreaseBrightness = changeAttribute brightnessAdjustments, false
        modify decreaseBrightness

Kelvin adjustments

    getKelvin = (bulb) -> bulb.color.kelvin

    kelvinAdjustments =
        change : setKelvin
        current: getKelvin
        step   : 500
        min    : 2500
        max    : 9000

    if o.kelvin?
        setKelvin o.kelvin

    if o.kelvinUp?
        increaseKelvin = changeAttribute kelvinAdjustments, true
        modify increaseKelvin

    if o.kelvinDown?
        decreaseKelvin = changeAttribute kelvinAdjustments, false
        modify decreaseKelvin

Color adjustments


Color Adjustments

    getHue = (bulb) -> bulb.color.hue

    # From HSL

    hslToHex = (hslVal) ->
        obj = colorParser "hsl(#{hslVal}, 100, 50)"
        log "Parsed hsl value #{hslVal} to hex value #{obj}"
        return obj?.hex

    # To HSL

    hexToHsl = (hexVal) ->
        obj = colorParser "##{hexVal}"
        log "Parsed hsl value #{hexVal} to hex value #{obj}"
        return obj?.hsl?[0]

    nameToHsl = (colorName) ->
        obj = colorParser colorName
        log "Parsed name value #{colorName} to hex value #{obj}"
        console.log obj
        return obj?.hsl?[0]

    hueAdjustments =
        change   : setHue
        current  : getHue
        step     : 45
        min      : 0
        max      : 360
        circular : true

    if o.rgb?
        setHue hexToHsl o.rgb

    if o.color?
        setHue nameToHsl o.color

    if o.hue?
        setHue o.hue

    if o.hueUp?
        increaseHue = changeAttribute hueAdjustments, true
        modify increaseHue

    if o.hueDown?
        decreaseHue = changeAttribute hueAdjustments, false
        modify decreaseHue

Saturation adjustments

    getSaturation = (bulb) -> bulb.color.saturation

    saturationAdjustments =
        change : setSaturation
        current: getSaturation
        step   : 0.1
        min    : 0.0
        max    : 1.0

    if o.saturation?
        setSaturation o.saturation

    if o.saturationUp?
        increaseSaturation = changeAttribute saturationAdjustments, true
        modify increaseSaturation

    if o.saturationDown?
        decreaseSaturation = changeAttribute saturationAdjustments, false
        modify decreaseSaturation

