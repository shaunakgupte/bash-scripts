# bash-tester
Bash script to test programs

usage: tester.sh [-h] [-n count] [-t timeout] [-o output_dir] /path/to/tests/file

	-n count       Global Iteration count (Default = 1, Infinite = 0)
	-t timeout     Global Timeout in seconds (Default = 0, Infinite = 0)
	-o output_dir  Path to output directory
	
	The global iteration count and timeout can be overridden for individual tests
	in the test vectors file.

*Format of the Test Vectors File:*
```
# This is a comment
# This test fails
test=>sleep 10
timeout=>5

# This test passes
test=>sleep 4
timeout=>5
count=>3

# You can write your own programs/scripts to verify the program output
# It should return proper error codes to detect failure

# This will fail
test=>touch log.txt
verify=>ls log.txt1

# This will pass
test=>touch log.txt2
verify=>ls log.txt2
```
