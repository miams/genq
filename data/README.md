Recommended best practice is to copy your RootsMagic database to this directory and query it from here. Although the goal for GenQuery is to be read-only, complex SQL queries may write temporary tables and views to the database. Although this will not affect RootsMagic operation, it could introduce future issues.

Additionally, there is always the risk a contributer to this code base writes a query that does intentionally change the database.
