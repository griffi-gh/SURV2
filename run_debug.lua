os.execute('start luajit server.lua')       --run server
os.execute('start love . --connect=127.0.0.1:42069 --user=OBOBO1 --pass=test')--run games
os.execute('start love . --connect=127.0.0.1:42069 --user=OBOBO2 --pass=test')
--os.execute('start love . --connect=127.0.0.1:42069 --user=OBOBO3 --pass=test')
--loadfile'run_debug.lua'() to run