Jeff's Own HP-15C Simulator
---------------------------

This is a fork of the HP-15C emulator found at https://hp-15c-simulator.de/, it fixes single bug, that keyboard input is LOST when typing too fast.
  
From Torsten's `FAQ <https://hp-15c-simulator.de/FAQ>`_:

   > If I rapidly type a sequence of numbers, the entered keyboard number(s) are ignored. For example, if I type 123 quickly, the 2 is missed and I get 13 on the display.

   >  While a key on the computer keyboard is being pressed, all other key presses are ignored. When you pressed the , you were still holding down the . This is exactly how the real HP-15C behaves. 

While I'm sure it is true, that *simultanous* keypresses are ignored on the real calculator, this very good HP emulator ignores *successive* inputs when typed "too quickly".

Here is a slow-motion video of the bug in the emulator,

And a slow motion video of a REAL HP-12C where the bug is not present.

In any case, the author, Torsten Manz disagrees, replying to my bugfix submission,

> I had several requests to change this or to make it at least optional. This is not on my prio list, because I want to stick as close as possible to the original HP-15C. 

Below is my e-mail to Torsten Manz, which contains a detailed description of the bug and the fix enclosed in this repository.

> Date: Sun, 17 Aug 2025 16:29:44 -0400
> From: "Jeff Quast" <contact@jeffquast.com>
> To: info@HP-15C-Simulator.de
> Greetings!
> 
> I discovered that keyboard input is lost your beautiful HP-15C emulator when typing too quickly! 
> Typing "1010101010" with two different hands and fingers rapidly often displays only "111110" or 
> so. I have done my best to fix this bug and I present it to you humbly:
> 
> In HP-15C.tcl v5.0.01, proc key_press at L9041 begins by handling active GUI buttons, *only* if 
> any other key is not already currently active, eventually calling dispatch_key to process it.
> 
> >  if {[lindex [.gui gettags pressed] 0] eq ""} {
> >     # process GUI button stuff
> >     # USER mode stuff
> >     
> >     dispatch_key $code
> >   }
> 
> Combined with the timer defined at L9086, "after 30", in proc key_release to release the visual
> GUI button, this effectively skips processing of any subsequent keystrokes for 30ms after each 
> keypress. Changing the value of "after 30" to 300 or larger makes the defective behavior more 
> clear.
> 
> The fix is to move USER mode processing and dispatch_key call outside of this 'if' statement, so
> that keystrokes are always acted upon regardless of GUI state. With this, I cannot lose a keystroke,
> even under artificially induced 300ms delays, patch attached.
> 
> I hope this helps and finds you well.
> 
> Cheers,
> Jeff Quast
> contact@jeffquast.com
