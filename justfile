alias r := run
alias b := build
alias t := test
alias w := watch

run:
    zig build run

build: 
    zig build
  
clean:
    zig build --pristine
    
test: 
    zig test src/tests.zig

# sucks this doesn't work for tests
watch: 
    zig build --watch
