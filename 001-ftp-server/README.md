## File Transfer Protocol Server Implementation in Ruby
### How to run
    ruby myftp.rb -p 23333 --host=127.0.0.1 --dir=~/tmp
`Ruby 2.2` and `Ruby 2.3` supported.
### Implementation Details
Command supported:

* USER/PASS
* LIST
* CWD
* PWD
* PASV
* RETR
* STOR
* QUIT


Other features:
* Utilized `OptionParser` and `Logger`
* Multi-thread Supported


### To do
- [ ] Permission for reading and writing files
- [ ] Path restriction
- [ ] Other FTP commands, such as `delete`, `mkdir`, `mput`, and `mget`
- [ ] User authentication
- [ ] IPV6 support
