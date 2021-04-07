os.execute('start luajit server.lua')       --run server
os.execute('start love . --connect=127.0.0.1:42069 --user=Boomer --pass=test')--run games
os.execute('start love . --connect=127.0.0.1:42069 --user=Steve --pass=hahaha')
--loadfile'run_debug.lua'()