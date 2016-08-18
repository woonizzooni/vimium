KeyboardUtils =
  keyCodes:
    { ESC: 27, backspace: 8, deleteKey: 46, enter: 13, ctrlEnter: 10, space: 32, shiftKey: 16, ctrlKey: 17, f1: 112,
    f12: 123, tab: 9, downArrow: 40, upArrow: 38 }

  keyNames:
    { 37: "left", 38: "up", 39: "right", 40: "down", 32: "space" }

  # This is a mapping of the incorrect keyIdentifiers generated by Webkit on Windows during keydown events to
  # the correct identifiers, which are correctly generated on Mac. We require this mapping to properly handle
  # these keys on Windows. See https://bugs.webkit.org/show_bug.cgi?id=19906 for more details.
  keyIdentifierCorrectionMap:
    "U+00C0": ["U+0060", "U+007E"] # `~
    "U+00BD": ["U+002D", "U+005F"] # -_
    "U+00BB": ["U+003D", "U+002B"] # =+
    "U+00DB": ["U+005B", "U+007B"] # [{
    "U+00DD": ["U+005D", "U+007D"] # ]}
    "U+00DC": ["U+005C", "U+007C"] # \|
    "U+00BA": ["U+003B", "U+003A"] # ;:
    "U+00DE": ["U+0027", "U+0022"] # '"
    "U+00BC": ["U+002C", "U+003C"] # ,<
    "U+00BE": ["U+002E", "U+003E"] # .>
    "U+00BF": ["U+002F", "U+003F"] # /?

  init: ->
    if (navigator.userAgent.indexOf("Mac") != -1)
      @platform = "Mac"
    else if (navigator.userAgent.indexOf("Linux") != -1)
      @platform = "Linux"
    else
      @platform = "Windows"

  # We are migrating from using event.keyIdentifier to using event.key.  For some period of time, we must
  # support both.  This wrapper can be removed once Chrome 52 is considered too old to support.
  getKeyChar: (event) ->
    # We favor using event.keyIdentifier due to Chromium's currently (Chrome 51) incorrect implementataion of
    # event.key; see #2147.
    if event.keyIdentifier?
      @getKeyCharUsingKeyIdentifier event
    else
      @getKeyCharUsingKey event

  getKeyCharUsingKey: (event) ->
    if event.keyCode of @keyNames
      @keyNames[event.keyCode]
    else if event.key.length == 1
      event.key
    else if event.key.length == 2 and "F1" <= event.key <= "F9"
      event.key.toLowerCase() # F1 to F9.
    else if event.key.length == 3 and "F10" <= event.key <= "F12"
      event.key.toLowerCase() # F10 to F12.
    else if event.key.length > 3 and event.key in ["Backspace"]
      event.key.toLowerCase() # F10 to F12.
    else
      ""

  getKeyCharUsingKeyIdentifier: (event) ->
    # Not a letter
    if (event.keyIdentifier.slice(0, 2) != "U+")
      return @keyNames[event.keyCode] if (@keyNames[event.keyCode])
      # F-key
      if (event.keyCode >= @keyCodes.f1 && event.keyCode <= @keyCodes.f12)
        return "f" + (1 + event.keyCode - keyCodes.f1)
      return ""
    return "backspace" if event.keyIdentifier == "U+0008"

    keyIdentifier = event.keyIdentifier
    # On Windows, the keyIdentifiers for non-letter keys are incorrect. See
    # https://bugs.webkit.org/show_bug.cgi?id=19906 for more details.
    if ((@platform == "Windows" || @platform == "Linux") && @keyIdentifierCorrectionMap[keyIdentifier])
      correctedIdentifiers = @keyIdentifierCorrectionMap[keyIdentifier]
      keyIdentifier = if event.shiftKey then correctedIdentifiers[1] else correctedIdentifiers[0]
    unicodeKeyInHex = "0x" + keyIdentifier.substring(2)
    character = String.fromCharCode(parseInt(unicodeKeyInHex)).toLowerCase()
    if event.shiftKey then character.toUpperCase() else character

  isPrimaryModifierKey: (event) -> if (@platform == "Mac") then event.metaKey else event.ctrlKey

  isEscape: (event) ->
    # c-[ is mapped to ESC in Vim by default.
    (event.keyCode == @keyCodes.ESC) || (event.ctrlKey && @getKeyChar(event) == '[' and not event.metaKey)

  # TODO. This is probably a poor way of detecting printable characters.  However, it shouldn't incorrectly
  # identify any of chrome's own keyboard shortcuts as printable.
  isPrintable: (event) ->
    return false if event.metaKey or event.ctrlKey or event.altKey
    keyChar =
      if event.type == "keypress"
        String.fromCharCode event.charCode
      else
        @getKeyChar event
    keyChar.length == 1

  # Return the Vimium key representation for this keyboard event. Return a falsy value (the empty string or
  # undefined) when no Vimium representation is appropriate.
  getKeyCharString: (event) ->
    switch event.type
      when "keypress"
        # Ignore modifier keys by themselves.
        if 31 < event.keyCode
          String.fromCharCode event.charCode

      when "keydown"
        # Handle special keys and normal input keys with modifiers being pressed.
        keyChar = @getKeyChar event
        if 1 < keyChar.length or (keyChar.length == 1 and (event.metaKey or event.ctrlKey or event.altKey))
          modifiers = []

          keyChar = keyChar.toUpperCase() if event.shiftKey
          modifiers.push "m" if event.metaKey
          modifiers.push "c" if event.ctrlKey
          modifiers.push "a" if event.altKey

          keyChar = [modifiers..., keyChar].join "-"
          if 1 < keyChar.length then "<#{keyChar}>" else keyChar

KeyboardUtils.init()

root = exports ? window
root.KeyboardUtils = KeyboardUtils
# TODO(philc): A lot of code uses this keyCodes hash... maybe we shouldn't export it as a global.
root.keyCodes = KeyboardUtils.keyCodes
