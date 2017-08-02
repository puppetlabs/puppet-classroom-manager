class Classroom
  HELP = <<-EOF

Usage : classroom <action> [subject] [options]

Manage Puppet classroom VMs and updating courseware. This includes
troubleshooting and maintenance tasks to be used as needed during
the delivery and facilities for resetting the VM for use across
multiple deliveries. This is pre-installed on the classroom VM and
is only of use to trainers delivering Puppet Inc. classes.

Available actions:

* classroom update:
  This updates your VM to the latest released version. This includes all
  cached packages, gems, modules, etc. and pre-installed courseware.

  You should run this command before each delivery. It may take several
  minutes to complete. When finished, it will run the validate task.

* classroom validate
  This runs built in serverspec tests to check the VM for consistency.
  It is run automatically by the update task so you likely don't need
  to run it yourself.

* classroom submit
  This task replaces the old `rake submit` tasks and uploads classroom
  statistics to the EDU department for analysis.

* classroom sanitize
  Running this task will remove all traces of students in preparation
  for using the same VM for the next delivery.

* classroom performance log <message>
  The VM periodically records performance metrics. These are included
  in the information uploaded with the `submit` task. This task allows
  you to annotate those logs with arbitrary information.

* classroom reset password | certificates | filesync
  This task resets the specified information. Using this to reset the
  root password ensures that it is still displayed on the login console.
  This can also regenerate all monolithic PE certificates or use the
  so-called "nuclear" option to blow away and redeploy filesync.

* classroom restart <PE services>
  Gracefully restart PE services in the proper order. Run without a
  service to see usage information.

* classroom troubleshoot
  Run through various troubleshooting checks and fixes.

* classroom page
   ** Unimplemented **
  This will page on call classroom support in case of emergency.

* classroom help
  You're looking at it!

EOF
end
