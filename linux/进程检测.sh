#!/bin/sh
while true
do
        tts=`ps -aux | grep ttsServer | grep -v grep`;
        if [ "$tts" == "" ]; then
                sleep 1;
                echo "no nmon process";
                echo "挂了！";
        else
                echo "process exsits";
                echo "活着呢！";
		break;
        fi
done
