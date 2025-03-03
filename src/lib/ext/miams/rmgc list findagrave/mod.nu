# List person Webtags named of "Find a Grave."
export def "main" [] {
    print "List of Find a Grave entries."

    # List of Find-a-Grave entries.

    # print "List of Find-a-Grave entries."
    # Objective: List Webtags with Find a Grave entries.
    # Notes:  
    # It's possible to use Webtags in a variety of contexts, which is stored as OwnerType in the database. For the Person context, I personally only used it for Find a Grave.

    # Values available for OwnerType
    # 0 = Person,
    # 3 = Source,
    # 4 = Citation,
    # 5 = Place,
    # 6 = Task,
    # 14 = Place Details
    # More info:  https://docs.google.com/spreadsheets/d/1VenU0idUAmkbA9kffazvj5RX_dZn6Ncn/edit?usp=sharing&ouid=104459570713722063434&rtpof=true&sd=true 
    
    let sqlquery = "select OwnerID as RIN, Name, URL, Note AS Retrieved, STRFTIME(DATETIME(UTCModDate + 2415018.5)) AS LastUpdate from URLTable where OwnerType=0"
    print $sqlquery
    open $env.rmdb | query db $sqlquery | startat1
}
