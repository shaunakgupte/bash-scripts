# bash-tester
Bash script to test programs

usage: tester.sh [-h] [-n count] [-t timeout] -f <Tests File>

  -n count       Global Iteration count (Default = 1, Infinite = 0)
  -t timeout     Global Timeout in seconds (Default = 1, Infinite = 0)
  -f <file>      File that contains the test vectors

  The global iteration count and timeout can be overridden for individual tests
  in the test vectors file.

Report bugs to: Shaunak Gupte <gupte.shaunak@gmail.com>

Format of the Test Vectors File:

# This is a comment
    test=>./myprogram
    timeout=>10
    count=>2

# The following test will pass
    test=>sleep 10
    timeout=>11

# The following test will fail
    test=>sleep 10
    timeout=>7

    test=>./myprogram3
    count=>5