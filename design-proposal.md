---
title: "Design Proposal"
author: Heming Zhu
email: u6740827
---

I am gonna kinda rip off the pixel game published in 1976, Snake.

The scene my assignment 2 will issue is: A "snake" with one bit wide, but n bits long exhibits on the led grid; when the button A is bushed, a "fruit" is dropped at random location on the led grid, and the snake will navigate itself to the location of that fruit. When the snake collide with the fruit, the snake will grow itself one bit longer, and eliminate the fruit.

Button B can be pressed anytime, pressing the button will let user take a "closer look" to the snake, displaying the stat of the snake, the status have five level, every time a fruit is ate by the snake one level is increased. The status is displayed in a graphical manner .

To realise above ambition I have at least able to implement following low level features:

Frame Render System - displaying pictures arithmatically, calculate picture generating seed, framing display

I would need the ability to display a whole picture only by a or few ".word" hex numbers, that is displaying pictures arithmatically

I would need to calculate what will the next frame of picture be, base on previous and current situation (since a moving line is sort of a generative pattern, which previous situation matters)

I would need to use systick to create a frame refreshing manner, that display my constantly evolving picture.
