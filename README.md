legion
======

An experiment in swarm intelligence written in Ruby

Requirements
------------
1. Gosu
```
sudo gem install gosu
```
Note: you may also need to install additional packages to get Gosu up and running. Follow instructions
located at https://github.com/jlnr/gosu/wiki/

Information
-----------
This was originally a project I did in Scheme way back in Freshman year in college.  I thought it was so cool that I wanted to redo it in Ruby so that I could learn more about the language.  I kept some Scheme-like characteristics in this rewrite, namely the Posn class.  Scheme has built in support for cartesian vectors and I tried to recreate this in Ruby.  I realize it would probably have been more efficient to just use an array, but I felt like this way was more interesting.

It's great fun watching the critters swarm together, break off, and form again, I highly recommend just sitting and watching.  The weights are pretty well balanced as they are, but go ahead and play around with them if you want.
