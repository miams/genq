# List sources for newspapers.
@category "genq-ext-miams"
export def "main" [] {
    genq list sources | where Name =~ 'Newspapers:' | select Name | sort-by Name | startat1
}