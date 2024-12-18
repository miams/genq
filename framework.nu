export def list_action_completer [] { ["find-a-grave", "people", "citations", "events", "obits", "help" ] }
export def mylist [action: string@list_action_completer, ...objects: string] {
   print "objects: " $objects 
   print "action: " $action 
   print "in: " $in
   if ($objects | is-empty) { 
    let msg = "
    Welcome to RMGC, a RootsMagic reporting engine.
    This tool is designed to help genealogists quickly explore and analyze data residing in the RootsMagic database.
    
    The goal of this tools it be:
      Quick -  
      Easy -
      Flexible - 
      "
    print $'(ansi red_bold) ($msg) (ansi reset) Hello World'   
    } else {
    print $objects }
}
    
module spam { 
    export def foo [] { "foo" } 
    }

use spam foo
foo
