# List sources for newspapers.
@category "rmgc-ext-miams"
export def "main" [] {
    rmgc list sources | where Name =~ 'Newspapers:' | select Name | sort-by Name | startat1
}