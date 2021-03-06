unless defined? $__rq_usage__
  module RQ 
#--{{{
    LIBDIR = File::dirname(File::expand_path(__FILE__)) + File::SEPARATOR unless
      defined? LIBDIR

    require LIBDIR + 'util'

    #
    # the reasons this is pulled off into it's own module are
    # * it's really big 
    # * it totally wrecks vim's syntax highlighting
    #
    module  Usage
#--{{{
      def cget const
#--{{{
        begin
          klass::const_get const
        rescue NameError
          nil
        end
#--}}}
      end
      def usage opts = {}
#--{{{
        port = getopt 'port', opts
        long = getopt 'long', opts

        port = STDERR if port.nil?

        if(long and (txt = cget 'USAGE'))
          port << txt << "\n"
        elsif((txt = cget 'USAGE_BANNER'))
          port << txt << "\n"
        else
          port << "#{ $0 } [options]* [args]*" << "\n"
        end

        if((optspec = cget 'OPTSPEC'))
          port << 'OPTIONS' << "\n"
          optspec.each do |os| 
            a, b, c = os
            long, short, desc = nil
            [a,b,c].each do |word|
              next unless word
              word.strip!
              case word
                when %r/^--[^-]/o
                  long = word
                when %r/^-[^-]/o
                  short = word
                else
                  desc = word
              end
            end
            spec = ((long and short) ? [long, short] : [long])
            if spec
              port << columnize(spec.join(', '), 80, 2)
              port << "\n"
            end
            if desc
              port << columnize(desc, 80, 8)
              port << "\n"
            end
          end
          port << "\n"
        end

        if((txt = cget 'EXAMPLES'))
          port << txt << "\n"
        end

        port
#--}}}
      end
      module_function :usage
      public :usage

      PROGNAM = 'rq' 

      # :nodoc
      USAGE_BANNER = 
#--{{{
<<-usage_banner
NAME
  rq v#{ VERSION }

SYNOPSIS
  rq (queue | export RQ_Q=q) mode [mode_args]* [options]*
usage_banner
#--}}}

      # :nodoc
      USAGE = 
#--{{{
<<-usage
#{ USAGE_BANNER }
URIS

  http://rubyforge.org/projects/codeforpeople/
  http://codeforpeople.com/lib/ruby/rq/
  http://www.linuxjournal.com/article/7922

DESCRIPTION

  ruby queue (rq) is a zero-admin zero-configuration tool used to create instant
  unix clusters.  rq requires only a central nfs filesystem in order to manage a
  simple sqlite database as a distributed priority work queue.  this simple
  design allows researchers with minimal unix experience to install and
  configure, in only a few minutes and without root privileges, a robust unix
  cluster capable of distributing processes to many nodes - bringing dozens of
  powerful cpus to their knees with a single blow.  clearly this software should
  be kept out of the hands of free radicals, seti enthusiasts, and one mr. j
  safran.

  the central concept of rq is that n nodes work in isolation to pull jobs
  from an centrally mounted nfs priority work queue in a synchronized fashion.
  the nodes have absolutely no knowledge of each other and all communication
  is done via the queue meaning that, so long as the queue is available via
  nfs and a single node is running jobs from it, the system will continue to
  process jobs.  there is no centralized process whatsoever - all nodes work
  to take jobs from the queue and run them as fast as possible.  this creates
  a system which load balances automatically and is robust in face of node
  failures.

  although the rq system is simple in it's design it features powerful
  functionality such as priority management, predicate and sql query , compact
  streaming command-line processing, programmable api, hot-backup, and
  input/capture of the stdin/stdout/stderr io streams of remote jobs.  to date
  rq has had no reported runtime failures and is in operation at dozens of
  research centers around the world.

INVOCATION

  the first argument to any rq command is the always the name of the queue
  while the second is the mode of operation.  the queue name may be omitted
  if, and only if, the environment variable RQ_Q has been set to contain the
  absolute path of target queue.

  for instance, the command

    ~ > rq queue list 

  is equivalent to

    ~ > export RQ_Q=queue
    ~ > rq list

  this facility can be used to create aliases for several queues, for example,
  a .bashrc containing

    alias MYQ="RQ_Q=/path/to/myq rq"

    alias MYQ2="RQ_Q=/path/to/myq2 rq"

  would allow syntax like

    MYQ2 submit < joblist

MODES

  rq operates in modes create, submit, resubmit, list, status, delete, update,
  query, execute, configure, snapshot, lock, backup, rotate, feed, recover,
  ioview, cron, help, and a few others.  the meaning of 'mode_args' will
  naturally change depending on the mode of operation.

  the following mode abbreviations exist, note that not all modes have
  abbreviations

    c  => create
    s  => submit
    r  => resubmit
    l  => list
    ls => list
    t  => status
    d  => delete
    rm => delete
    u  => update
    q  => query
    e  => execute
    C  => configure
    S  => snapshot
    L  => lock
    b  => backup
    R  => rotate 
    f  => feed
    io => ioview
    0  => stdin
    1  => stdout
    2  => stderr
    h  => help


  create, c :

    creates a queue.  the queue must be located on an nfs mounted file system
    visible from all nodes intended to run jobs from it.  nfs locking must be
    functional on this file system.

    examples :

      0) to create a queue
          ~ > rq /path/to/nfs/mounted/q create

        or, using the abbreviation

          ~ > rq /path/to/nfs/mounted/q c


  submit, s :

    submit jobs to a queue to be proccesed by some feeding node.  any
    'mode_args' are taken as the command to run.  note that 'mode_args' are
    subject to shell expansion - if you don't understand what this means do
    not use this feature and pass jobs on stdin.

    when running in submit mode a file may by specified as a list of commands
    to run using the '--infile, -i' option.  this file is taken to be a
    newline separated list of commands to submit, blank lines and comments (#)
    are allowed.  if submitting a large number of jobs the input file method
    is MUCH, more efficient.  if no commands are specified on the command line
    rq automatically reads them from stdin.  yaml formatted files are also
    allowed as input (http://www.yaml.org/) - note that the output of nearly
    all rq commands is valid yaml and may, therefore, be piped as input into
    the submit command.  the leading '---' of yaml file may not be omitted.

    when submitting the '--priority, -p' option can be used here to determine
    the priority of jobs.  priorities may be any whole number including
    negative ones - zero is the default.  note that submission of a high
    priority job will NOT supplant a currently running low priority job, but
    higher priority jobs WILL always migrate above lower priority jobs in the
    queue in order that they be run as soon as possible.  constant submission
    of high priority jobs may create a starvation situation whereby low
    priority jobs are never allowed to run.  avoiding this situation is the
    responsibility of the user.  the only guaruntee rq makes regarding job
    execution is that jobs are executed in an 'oldest-highest-priority' order
    and that running jobs are never supplanted.  jobs submitted with the
    '--stage' option will not be eligible to be run by any node and will
    remain in a 'holding' state until updated (see update mode) into the
    'pending' mode, this option allows jobs to entered, or 'staged', in the
    queue and then made candidates for running at a later date.

    rq allows the stdin of commands to be provided and also captures the
    stdout and stderr of any job run (of course standard shell redirects may
    be used as well) and all three will be stored in a directory relative the
    the queue itself.  the stdin/stdout/stderr files are stored by job id and
    there location (though relative to the queue) is shown in the output of
    'list' (see docs for list).
      

    examples :

      0) submit the job ls to run on some feeding host

        ~ > rq q s ls 

      1) submit the job ls to run on some feeding host, at priority 9

        ~ > rq -p9 q s ls 

      2) submit a list of jobs from file.  note the '-' used to specify
      reading jobs from stdin

        ~ > cat joblist
        job1.sh
        job2.sh
        job2.sh

        ~ > rq q submit --infile=joblist

      3) submit a joblist on stdin

        ~ > cat joblist | rq q submit -

        or

        ~ > rq q submit - <joblist

      4) submit cat as a job, providing the stdin for cat from the file cat.in

        ~ > rq q submit cat --stdin=cat.in

      5) submit cat as a job, providing the stdin for the cat job on stdin 

        ~ > cat cat.in | rq q submit cat --stdin=-

        or

        ~ > rq q submit cat --stdin=- <cat.in

      6) submit 42 priority 9 jobs from a command file, marking them as
         'important' using the '--tag, -t' option.

        ~ > wc -l cmdfile 
        42

        ~ > rq -p9 -timportant q s < cmdfile

      6) re-submit all the 'important' jobs (see 'query' section below)

        ~ > rq q query tag=important | rq q s -

      8) re-submit all jobs which are already finished (see 'list' section
         below) 

        ~ > rq q l f | rq q s 


      9) stage the job wont_run_yet to the queue in a 'holding' state.  no
         feeder will run this job until it's state is upgraded to 'pending'

        ~ > rq q s --stage wont_run_yet


  resubmit, r :

    resubmit jobs back to a queue to be proccesed by a feeding node.  resubmit
    is essentially equivalent to submitting a job that is already in the queue
    as a new job and then deleting the original job except that using resubmit
    is atomic and, therefore, safer and more efficient.  resubmission respects
    any previous stdin provided for job input.  read docs for delete and
    submit for more info.

    examples :

      0) resubmit job 42 to the queue

        ~> rq q resubmit 42

      1) resubmit all failed jobs

        ~> rq q query exit_status!=0 | rq q resubmit -

      2) resubmit job 4242 with different stdin

        ~ rq q resubmit 4242 --stdin=new_stdin.in


  list, l, ls :

    list mode lists jobs of a certain state or job id.  state may be one of
    pending, holding, running, finished, dead, or all.  any 'mode_args' that
    are numbers are taken to be job id's to list.

    states may be abbreviated to uniqueness, therefore the following shortcuts
    apply :        

      p => pending
      h => holding
      r => running
      f => finished
      d => dead
      a => all

    examples :

      0) show everything in q
          ~ > rq q list all

        or

          ~ > rq q l all

        or

          ~ > export RQ_Q=q 
          ~ > rq l

      1) show q's pending jobs
          ~ > rq q list pending

      2) show q's running jobs
          ~ > rq q list running 

      3) show q's finished jobs
          ~ > rq q list finished 

      4) show job id 42 
          ~ > rq q l 42 

      5) show q's holding jobs
          ~ > rq q list holding 


  status, t :

    status mode shows the global state the queue and statistics on it's the
    cluster's performance.  there are no 'mode_args'.  the meaning of each
    state is as follows:

      pending  => no feeder has yet taken this job
      holding  => a hold has been placed on this job, thus no feeder will start
                  it
      running  => a feeder has taken this job
      finished => a feeder has finished this job
      dead     => rq died while running a job, has restarted, and moved
                  this job to the dead state

    note that rq cannot move jobs into the dead state unless it has been
    restarted.  this is because no node has any knowledge of other nodes and
    cannot possibly know if a job was started on a node that subsequently
    died, or that it is simply taking a very long time to complete.  only the
    node that dies, upon restart, can determine that it owns jobs that 'were
    started before it started running jobs', an impossibility, and move these
    jobs into the dead state.  
    
    normally only a machine crash would cause a job to be placed into the dead
    state.  dead jobs are automatically restarted if, and only if, the job was
    submitted with the '--restartable' flag.

    status breaks down a variety of canned statistics about a nodes'
    performance based solely on the jobs currently in the queue.  only one
    option affects the ouput: '--exit'.  this option is used to specify
    additionaly exit code mappings on which to report.  normally rq will
    report any job with an exit code of 0 as being 'successes' and any job
    with an exit code that is not 0, or a status of 'dead', as being
    'failures'.  if the '--exit' switch is used then additional mappings can
    be specified, note that the the semantics for 'successes' and 'failures'
    does not change - this keyword specifies extra mappings.

    examples :

      0) show q's status

        ~ > rq q t 

      2) show q's status, consider any exit code of 42 will be listed as 'ok'

        ~ > rq q t --exit ok=42

      3) show q's status, consider any exit code of 42 or 43 will be listed as
      'ok' and 127 will be listed as 'command_not_found'.  notice the quoting
      required.

        ~ > rq q t --exit 'ok=42,43 command_not_found=127'


  delete, d :

    delete combinations of pending, holding, finished, dead, or jobs specified
    by jid.  the delete mode is capable of parsing the output of list and
    query modes, making it possible to create custom filters to delete jobs
    meeting very specific conditions.

    'mode_args' are the same as for list.  

    note that it is NOT possible to delete a running job.  rq has a
    decentralized architechture which means that compute nodes are completely
    independant of one another; an extension is that there is no way to
    communicate the deletion of a running job from the queue the the node
    actually running that job.  it is not an error to force a job to die
    prematurely using a facility such as an ssh command spawned on the remote
    host to kill it.  once a job has been noted to have finished, whatever the
    exit status, it can be deleted from the queue.

    examples :

      0) delete all pending, finished, and dead jobs from a queue

        ~ > rq q d all

      1) delete all pending jobs from a queue

        ~ > rq q d p 

      2) delete all finished jobs from a queue

        ~ > rq q d f 

      3) delete jobs via hand crafted filter program

        ~ > rq q list | yaml_filter_prog | rq q d -

        an example ruby filter program (you have to love this)

          ~ > cat yaml_filter_prog
          require 'yaml'
          joblist = YAML::load STDIN
          y joblist.select{|job| job['command'] =~ /bombing_program/}

        this program reads the list of jobs (yaml) from stdin and then dumps
        only those jobs whose command matches 'bombing_program', which is
        subsequently piped to the delete command.


  update, u :

    update assumes all leading arguments are jids to update with subsequent
    key=value pairs.  currently only the 'command', 'priority', and 'tag'
    fields of pending jobs can be generically updated and the 'state' field
    may be toggled between pending and holding.

    examples:

      0) update the priority of job 42 

        ~ > rq q update 42 priority=7 

      1) update the priority of all pending jobs 

        ~ > rq q update pending priority=7 

      2) query jobs with a command matching 'foobar' and update their command
      to be 'barfoo'

        ~ > rq q q "command like '%foobar%'" |\\
            rq q u command=barfoo 

      3) place a hold on jid 2

        ~ > rq q u 2 state=holding

      4) place a hold on all jobs with tag=disk_filler

        ~ > rq q q tag=disk_filler | rq q u state=holding -

      5) remove the hold on jid 2

        ~ > rq q u 2 state=pending


  query, q :

    query exposes the database more directly the user, evaluating the where
    clause specified on the command line (or read from stdin).  this feature
    can be used to make a fine grained slection of jobs for reporting or as
    input into the delete command.  you must have a basic understanding of SQL
    syntax to use this feature, but it is fairly intuitive in this limited
    capacity.

    examples:

      0) show all jobs submitted within a specific 10 minute range

        ~ > a='2004-06-29 22:51:00'

        ~ > b='2004-06-29 22:51:10'

        ~ > rq q query "started >= '$a' and started < '$b'"

      1) shell quoting can be tricky here so input on stdin is also allowed to
      avoid shell expansion

        ~ > cat constraints.txt 
        started >= '2004-06-29 22:51:00' and
        started < '2004-06-29 22:51:10'

        ~ > rq q query < contraints.txt
          or (same thing)

        ~ > cat contraints.txt| rq q query -

      2) this query output might then be used to delete those jobs

        ~ > cat contraints.txt | rq q q - | rq q d -

      3) show all jobs which are either finished or dead 

        ~ > rq q q "state='finished' or state='dead'"

      4) show all jobs which have non-zero exit status

        ~ > rq q query exit_status!=0 

      5) if you plan to query groups of jobs with some common feature consider
      using the '--tag, -t' feature of the submit mode which allows a user to
      tag a job with a user defined string which can then be used to easily
      query that job group 

        ~ > rq q submit --tag=my_jobs - < joblist 

        ~ > rq q query tag=my_jobs 


      6) in general all but numbers will need to be surrounded by single
      quotes unless the query is a 'simple' one.  a simple query is a query
      with no boolean operators, not quotes, and where every part of it looks
      like

            key op value

         with ** NO SPACES ** between key, op, and value.  if, and only if,
         the query is 'simple' rq will contruct the where clause
         appropriately.  the operators accepted, and their meanings, are

           =  : equivalence : sql =
           =~ : matches     : sql like
           !~ : not matches : sql not like

         match, in the context is ** NOT ** a regular expression but a sql
         style string match.  about all you need to know about sql matches is
         that the '%' char matches anything.  multiple simple queries will be
         joined with boolean 'and'
         
         this sounds confusing - it isn't.  here are some examples of simple
         queries

         6.a) 
           query :
             rq q query tag=important

           where_clause :
             "( tag = 'important' )"

         6.b) 
           query :
             rq q q priority=6 restartable=true 

           where_clause :
             "( priority = 6 ) and ( restartable = 'true' )"

         6.c) 
           query :
             rq q q command=~%bombing_job% runner=~%node_1% 

           where_clause :
             "( command like '%bombing_job%') and (runner like '%node_1%')"


  execute, e :

    execute mode is to be used by expert users with a knowledge of sql syntax
    only.  it follows the locking protocol used by rq and then allows the user
    to execute arbitrary sql on the queue.  unlike query mode a write lock on
    the queue is obtained allowing a user to definitively shoot themselves in
    the foot.  for details on a queue's schema the file 'db.schema' in the
    queue directory should be examined.

      examples :

        0) list all jobs

          ~ > rq q execute 'select * from jobs'


  configure, C :

    this mode is not supported yet.


  snapshot, p :

    snapshot provides a means of taking a snapshot of the q. use this feature
    when many queries are going to be run; for example when attempting to
    figure out a complex pipeline command your test queries will not compete
    with the feeders for the queue's lock.  you should use this option
    whenever possible to avoid lock competition.

    examples:

      0) take a snapshot using default snapshot naming, which is made via the
      basename of the q plus '.snapshot'

        ~ > rq /path/to/nfs/q snapshot 

      1) use this snapshot to chceck status

        ~ > rq ./q.snapshot status 

      2) use the snapshot to see what's running on which host

        ~ > rq ./q.snapshot list running | grep `hostname` 

    note that there is also a snapshot option - this option is not the same as
    the snapshot command.  the option can be applied to ANY command. if in
    effect then that command will be run on a snapshot of the database and the
    snapshot then immediately deleted.  this is really only useful if one were
    to need to run a command against a very heavily loaded queue and did not
    wish to wait to obtain the lock.  eg.

      0) get the status of a heavily loaded queue

        ~ > rq q t --snapshot

      1) same as above 

        ~ > rq q t -s

    ** IMPORTANT **
    
      a really great way to hang all processing in your queue is to do this

        rq q list | less

      and then leave for the night.  you hold a read lock you won't release
      until less dies.  this is what snapshot is made for!  use it like

        rq q list -s | less

      now you've taken a snapshot of the queue to list so your locks affect no
      one.


  lock, L :

    lock the queue and then execute an arbitrary shell command.  lock mode
    uses the queue's locking protocol to safely obtain a lock of the specified
    type and execute a command on the user's behalf.  lock type must be one of

      (r)ead | (sh)ared | (w)rite | (ex)clusive

    examples :

      0) get a read lock on the queue and make a backup

        ~ > rq q L read -- cp -r q q.bak

        (the '--' is needed to tell rq to stop parsing command line
         options which allows the '-r' to be passed to the 'cp' command)

    ** IMPORTANT **

      this is another fantastic way to freeze your queue - use with care!


  backup, b :

    backup mode is exactly the same as getting a read lock on the queue and
    making a copy of it.  this mode is provided as a convenience.

      0) make a backup of the queue using default naming ( qname + timestamp + .bak )

        ~ > rq q b

      1) make a backup of the queue as 'q.bak' 

        ~ > rq q b q.bak


  rotate, r :

    rotate mode is conceptually similar to log rolling.  normally the list of
    finished jobs will grow without bound in a queue unless they are manually
    deleted.  rotation is a method of trimming finished jobs from a queue
    without deleting them.  the method used is that the queue is copied to a
    'rotation'; all jobs that are dead or finished are deleted from the
    original queue and all pending and running jobs are deleted from the
    rotation.  in this way the rotation becomes a record of the queue's
    finished and dead jobs at the time the rotation was made.

      0) rotate a queue using default rotation name 

        ~ > rq q rotate 

      1) rotate a queue naming the rotation

        ~ > rq q rotate q.rotation

      2) a crontab entry like this could be used to rotate a queue daily 

        59 23 * * * rq q rotate `date +q.%Y%m%d`


  feed, f :

    take jobs from the queue and run them on behalf of the submitter as
    quickly as possible.  jobs are taken from the queue in an 'oldest highest
    priority' first order.  
    
    feeders can be run from any number of nodes allowing you to harness the
    CPU power of many nodes simoultaneously in order to more effectively
    clobber your network, anoy your sysads, and set output raids on fire.
    
    the most useful method of feeding from a queue is to do so in daemon mode
    so that if the process loses it's controling terminal it will not exit
    when you exit your terminal session.  use the '--daemon, -d' option to
    accomplish this.  by default only one feeding process per host per queue
    is allowed to run at any given moment.  because of this it is acceptable
    to start a feeder at some regular interval from a cron entry since, if a
    feeder is alreay running, the process will simply exit and otherwise a new
    feeder will be started.  in this way you may keep feeder processing
    running even acroess machine reboots without requiring sysad intervention
    to add an entry to the machine's startup tasks.


    examples :

      0) feed from a queue verbosely for debugging purposes, using a minimum
      and maximum polling time of 2 and 4 respectively.  you would NEVER
      specify polling times this brief except for debugging purposes!!!

        ~ > rq q feed -v4 --min_sleep=2 --max_sleep=4

      1) same as above, but viewing the executed sql as it is sent to the
      database

        ~ > RQ_SQL_DEBUG=1 rq q feed -v4 --min_sleep=2 --max_sleep=4

      2) feed from a queue in daemon mode - logging to /home/ahoward/rq.log

        ~ > rq q feed --daemon -l/home/$USER/rq.log

         log rolling in daemon mode is automatic so your logs should never
         need to be deleted to prevent disk overflow.


  start :

    the start mode is equivalent to running the feed mode except the --daemon
    is implied so the process instantly goes into the background.  also, if no
    log (--log) is specified in start mode a default one is used.  the default
    is /home/$USER/$BASENAME_OF_Q.log

    examples :

      0) start a daemon process feeding from q

        ~ > rq q start

      1) use something like this sample crontab entry to keep a feeder running
      forever - it attempts to (re)start every fifteen minutes but exits if
      another process is already feeding.  output is only created when the
      daemon is started so your mailbox will not fill up with this crontab
      entry:

        #
        # crontab.sample 
        #

        */15 * * * * /path/to/bin/rq /path/to/q start

      and entry like this on every node in your cluster is all that's needed
      to keep your cluster going - even after a reboot.


  shutdown :

    tell a running feeder to finish any pending jobs and then to exit.  this
    is equivalent to sending signal 'SIGTERM' to the process - this is what
    using 'kill pid' does by default.

    examples :

      0) stop a feeding process, if any, that is feeding from q.  allow all
      jobs to be finished first.

        ~ > rq q shutdown 

    ** VERY IMPORTANT **

      if you are keeping your feeder alive with a crontab entry you'll need to
        comment it out before doing this or else it will simply re-start!!!

  stop :

    tell any running feeder to stop NOW.  this sends signal 'SIGKILL' (-9) to
    the feeder process.  the same warning as for shutdown applies!!!

    examples :

      0) stop a feeding process, if any, that is feeding from q.  allow NO
      jobs to be finished first - exit instantly.

        ~ > rq q stop 

  cron :

    when given 'start' for 'mode_args' this option automatically adds a
    crontab entry to keep a feeder alive indefinitely and starts a feeder in
    the background.  this is a shortcut to start a feeder and ensure it stays
    running forever, even across re-boots.

    'stop' as an argument applys the inverse option: any crontab entry is
    removed and the daemon shutdown nicely.  a second argument of 'hard' will
    do a stop instead of a shutdown.

    the addition and subtraction of crontab entries is robust, however, if you
    already have crontab lines maintaining your feeders with a vastly
    different syntax it would be best to shut down, remove them, and then let
    rq manage them.  then again, some people are quite brave...

    examples :

      0) automatically add crontab entry and start daemon feeder

        ~ > rq q cron start

      1) automatically remove crontab entry and shutdown daemon feeder nicely 

        ~ > rq q cron shutdown

      2) the same, but using stop instead of shutdown

        ~ > rq q cron stop

  pid :

    show the pid, if any, of the feeder on this host

    ~ > rq q feeder
    ---
    pid : 3176


  ioview, io :

    as shown in the description for submit, a job maybe be provided stdin
    during job submission.  the stdout and stderr of the job are also captured
    as the job is run.  all three streams are captured in files located
    relative to the queue.  so, if one has submitted a job, and it's jid was
    shown to be 42, by using something like

      ~ > rq /path/to/q submit myjob --stdin=myjob.in
      ---
      -
        jid : 42
        priority : 0
        ...
        stdin : stdin/42
        stdout : stdout/42
        stderr : stderr/42
        ...
        command : myjob

    the stdin file will exists as soon as the job is submitted and the others
    will exist once the job has begun running.  note that these paths are
    shown relative to the queue.  in this case the actual paths would be

      /path/to/q/stdin/42
      /path/to/q/stdout/42
      /path/to/q/stderr/42

    but, since our queue is nfs mounted the /path/to/q may or may not be the
    same on every host.  thus the path is a relative one.  this can make it
    anoying to view these files, but rq assists here with the ioview command.
    the ioview command spawns an external editor to view all three files.
    it's use is quite simple

    examples :

      0) view the stdin/stdout/stderr of job id 42

         ~ > rq q ioview 42

    by default this will open up all three files in vim.  the editor command
    can be specified using the '--editor' option or the ENV var RQ_EDITOR.
    the default value is 'vim -R -o' which allows all three files to be opened
    in a single window.


  stdin, 0 :

    dump the stdinput (if any) provided to the job 

    examples :

      0)  dump the stdin for jid 42

        ~ > rq q stdin 42


  stdout, 1 :

    dump the stdoutput (if any) created by the job 

    examples :

      0)  dump the stdout for jid 42

        ~ > rq q stdout 42


  stderr, 2 :

    dump the stderrput (if any) created by the job 

    examples :

      0)  dump the stderr for jid 42

        ~ > rq q stderr 42


  stdin4 :

    show the path used for the stdin of a jid 

    examples :

      0) show which file has job 42's stdin

        ~ > rq q stdin4 42


  stdout4 :

    show the path used for the stdout of a jid 

    examples :

      0) show which file has job 42's stdout

        ~ > rq q stdout4 42


  stderr4 :

    show the path used for the stderr of a jid 

    examples :

      0) show which file has job 42's stderr

        ~ > rq q stderr4 42


  recover :

    it is possible that a hardware failure might corrupt an rq database.  this
    isn't the kind of thing people like hearing, but it's true - hardware has
    errors.  in these situations a database can sometimes be readable, but not
    writable, or some other combination.  this has been reported only a
    handful of times, nevertheless, this command wraps sqlite recovery to get
    you rolling again, it's acceptable to perform recovery on a live rq
    database with active feeders

    examples :

      0) recover!

        ~ > rq q recover


  help, h :

    this message

    examples :

      0) get this message

        ~> rq q help

        or

        ~> rq help

NOTES
  - realize that your job is going to be running on a remote host and this has
    implications.  paths, for example, should be absolute, not relative.
    specifically the submitted job script must be visible from all hosts
    currently feeding from a queue as must be the input and output
    files/directories.

  - jobs are currently run under the bash shell using the --login option.
    therefore any settings in your .bashrc will apply - specifically your PATH
    setting.  you should not, however, rely on jobs running with any given
    environment.

  - you need to consider __CAREFULLY__ what the ramifications of having
    multiple instances of your program all potentially running at the same
    time will be.  for instance, it is beyond the scope of rq to ensure
    multiple instances of a given program will not overwrite each others
    output files.  coordination of programs is left entirely to the user.

  - the list of finished jobs will grow without bound unless you sometimes
    delete some (all) of them.  the reason for this is that rq cannot know
    when the user has collected the exit_status of a given job, and so keeps
    this information in the queue forever until instructed to delete it.  if
    you have collected the exit_status of you job(s) it is not an error to
    then delete that job from the finished list - the information is kept for
    your informational purposes only.  in a production system it would be
    normal to periodically save, and then delete, all finished jobs.

  - know that it is a VERY bad idea to spawn several dozen process all
    reading/writing huge output files to a single NFS server.  use this
    paradigm instead

      * copy/move data from global input space to local disk
      * process data
      * move data on local disk to global output space

    this, of course, applies to any nfs processing, not just those jobs
    submitted to rq

    the vsftp daemon is an excellent utility to have running on hosts in your
    cluster so anonymous ftp can be used to get/put data between any two
    hosts.

  - know that nfs locking is very, very easy to break with firewalls put in
    place by overzealous system administrators.  be postive not only that nfs
    locking works, but that lock recovery server/client crash or reboot works
    as well.  http://nfs.sourceforge.net/ is the place to learn about NFS.  my
    experience thus far is that there are ZERO properly configured NFS
    installations in the world.  please test yours.  contact me for a simple
    script which can assist you.  beer donations required as payment.

ENVIRONMENT
  RQ_Q: set to the full path of nfs mounted queue

    the queue argument to all commands may be omitted if, and only if, the
    environment variable 'RQ_Q' contains the full path to the q.  eg.

      ~ > export RQ_Q=/full/path/to/my/q

    this feature can save a considerable amount of typing for those weak of
    wrist.  
    
    a shell script like this can also be used to avoid needing to type the
    queue name each and every time

      ~ > cat my_q
        #!/bin/sh
        rq /full/path/to/my/q "$@"

    and then all operations become, for example

      ~> my_q submit my_mob
      ~> my_q status 
      ~> my_q delete 42

  RQ_OPTS | RQ_OPTIONS: specify extra options 

    this ENV var can be used to specify options which should always apply, for
    example

      ~ > export RQ_OPTS=--restartable

    and shell script like this might be used to mark jobs submitted by a
    certain user and to always submit them at a negative priority

      ~ > cat username_q
        #!/bin/sh
        export RQ_OPTS="--tag=username --priority=-42"
        rq /full/path/to/my/q "$@"

    actual command line options wil always override options given this way

DIAGNOSTICS
 success : $? == 0
 failure : $? != 0

CREDITS
  - kim baugh       : patient tester and design input
  - jeff safran     : the guy can break anything
  - chris elvidge   : boss who made it possible 
  - trond myklebust : tons of help with nfs
  - jamis buck      : for writing the sqlite bindings for ruby
  - _why            : for writing yaml for ruby
  - matz            : for writing ruby

INSTALL
  manual (cluster wide):

    - download latest release from URI(S) above
    - tar xvfz rq-X.X.X.tgz
    - cd rq-X-X-X.tgz
    - cd all
    - ./install.sh /full/path/to/nfs/mounted/directory/

  rubygems (per node):

    gem install rq

AUTHOR
  #{ AUTHOR }

BUGS
 0 < bugno && bugno <= 42

 reports to #{ AUTHOR }
usage
#--}}}
#--}}}
    end # module Usage
#--}}}
  end # module RQ
$__rq_usage__ = __FILE__ 
end
