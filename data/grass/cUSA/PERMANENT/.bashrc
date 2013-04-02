test -r ~/.alias && . ~/.alias
PS1='GRASS 6.4.2 (cUSA):\w > '
PROMPT_COMMAND="'/usr/lib/grass64/etc/prompt.sh'"
export PATH="/usr/lib/grass64/bin:/usr/lib/grass64/scripts:/home/nbest/.grass6/addons:/usr/local/apache-maven-2.2.1/bin:/opt/scidb/11.06/bin:/opt/scidb/11.06/share/scidb:/home/nbest/bin:/opt/scidb-0.7.5/bin:/opt/scidb-0.7.5/share/scidb:/usr/local/apache-maven-2.2.1/bin:/opt/scidb/11.06/bin:/opt/scidb/11.06/share/scidb:/home/nbest/bin:/opt/scidb-0.7.5/bin:/opt/scidb-0.7.5/share/scidb:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games"
export HOME="/home/nbest"
export GRASS_SHELL_PID=$$
trap "echo \"GUI issued an exit\"; exit" SIGQUIT
