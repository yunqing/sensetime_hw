## Simple Rake Parser in Ruby
### Implementation Details
* support keywords `desc` and `task`

### How to Run
Example:

    ./simplerake.rb -T
    ./simplerake.rb test/test1.rake
    ./simplerake.rb test/test1.rake test2

Use `-h` to get help message.
### To Do
* [ ] handle dependency loop
* [ ] draw graphs of dependency
