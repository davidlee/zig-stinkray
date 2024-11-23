alias r := run
alias b := build
alias t := test
alias w := watch

run:
    zig build run

build: 
    zig build
  
test: 
    zig build test 

watch: 
    zig build --watch
