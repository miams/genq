# List US Presidents"
@category "genq-ext-pres2020"
@example "Generate an ordered list of US Presidents" {'genq list presidents'
} 
export def "main" [] {
   if ($env.rmdb | str contains "pres2020.rmtree") { 
      genq list events | where Event == Occupation | where Description =~ "US President" | sort-by Description -n
   } else {
      print "This command is optimized for the pres2020 database.  Edit your env.nu file to use this command fully."
      print "\n"
      genq list events | where Event == Occupation | where Description =~ "US President" | sort-by Description -n
   }
}
