Jeff's Own HP-15C Simulator
---------------------------

This is a fork of the `HP-15C <https://hp-15c-simulator.de/>`_ to fix one single bug: that keyboard input is lost.

From Torsten's `FAQ <https://hp-15c-simulator.de/FAQ>`_:

   > If I rapidly type a sequence of numbers, the entered keyboard number(s) are ignored. For example, if I type 123 quickly, the 2 is missed and I get 13 on the display.

   >  While a key on the computer keyboard is being pressed, all other key presses are ignored. When you pressed the , you were still holding down the . This is exactly how the real HP-15C behaves. 

A slow-motion video of the bug in his emulation,

A slow-motion video of the bug not present in an authentic HP-12C calculator.

I reached out to Torsten Manz in many successive e-mails, but he strongly suggests that, although he gets several requests to fix it, that it is an intentional design for exacting emulated behavior.

However, I suggest users should be allowed to use more than 1 finger to enter digits into the computer emulated version of the keyboard, and, more importantly, that discarding keyboard input is a terrible bug for any computer calculator program, and should never be done under any circumstances.

     Date: Sun, 17 Aug 2025 16:29:44 -0400
     From: "Jeff Quast" <contact@jeffquast.com>
     To: info@HP-15C-Simulator.de
     Greetings!
     
     I discovered that keyboard input is lost your beautiful HP-15C emulator when typing too quickly! 
     Typing "1010101010" with two different hands and fingers rapidly often displays only "111110" or 
     so. I have done my best to fix this bug and I present it to you humbly:
     
     In HP-15C.tcl v5.0.01, proc key_press at L9041 begins by handling active GUI buttons, *only* if 
     any other key is not already currently active, eventually calling dispatch_key to process it.
     
```
     >  if {[lindex [.gui gettags pressed] 0] eq ""} {
     >     # process GUI button stuff
     >     # USER mode stuff
     >     
     >     dispatch_key $code
     >   }
```
     
     Combined with the timer defined at L9086, "after 30", in proc key_release to release the visual
     GUI button, this effectively skips processing of any subsequent keystrokes for 30ms after each 
     keypress. Changing the value of "after 30" to 300 or larger makes the defective behavior more 
     clear.
     
     The fix is to move USER mode processing and dispatch_key call outside of this 'if' statement, so
     that keystrokes are always acted upon regardless of GUI state. With this, I cannot lose a keystroke,
     even under artificially induced 300ms delays, patch attached.
     
     I hope this helps and finds you well.
     
     Cheers,
     Jeff Quast
     contact@jeffquast.com
