# The Tao of GenQuery

These principles guide every design decision in GenQuery — what commands to build, what output to return, what complexity to hide, and what to leave to the user. When facing a hard design question, return here first.

---

## A data-centric approach to Genealogy

Usability, ergonomics, and fun to use.

---

## Simple composable comands.

Stealing liberally from the Unix philosophy, 

- Write programs that do one thing and do it well.
- Write programs to work together.
- Write programs to handle data streams, because that is a new universal interface.

When two facts about a person live in different database tables, the join between those tables is an implementation detail — not something the user should orchestrate. GenQuery absorbs that complexity through enriched person records and `--with` flags, so the user composes with data, not schema.

The test: if completing a common analysis requires the user to write `join ... RIN` or `group-by` on a reconstructed key, GenQuery has not done its job. The pipeline should read like English, not like SQL.

---

## Lean by Default, Enriched on Demand

The default output of any command is the **minimum useful set of columns**. A person record contains RIN, name, birth year, death year, and sex — because those are always relevant and always cheap.

Additional attributes are opt-in via `--with` flags. The user pays the cost of richer data only when they ask for it.

```nushell
genq list people                    # lean: always fast
genq list people --with occupation  # richer: costs a join
genq list people --with tree        # richer: costs a graph computation
```

This principle determines what becomes a `--with` flag. An attribute earns that status when:

1. It describes the person directly, not an event they participated in
2. A single value (or natural summary) per person makes sense
3. It is commonly used to **filter or group** people, not just display them
4. Accessing it requires a join or computation the user should not have to know about

If an attribute fails any of these, it belongs in `genq list events`, `genq list citations`, or a dedicated command — not on the person record.

---

## Filter Early, Compute Late

Commands that produce output should also accept input.

A command that always computes against the full database is an obstacle to composability. When a user pipes a filtered list of people into `genq tabulate trees`, the tree computation should scope to only those people — not recompute everything and join afterward.

The natural shape of a GenQuery pipeline is:

```
source → filter → enrich → aggregate → display
```

Each stage is optional. Any stage can be the entry point. The pipeline reads left to right, and each command knows how to accept what came before it.

---

## Read-Only by Principle

GenQuery never modifies the genealogy database. This is non-negotiable.

The database represents potentially decades of research. GenQuery is a reporting tool. Those are different responsibilities, and mixing them would put irreplaceable data at risk in exchange for convenience that is not GenQuery's to offer.

Any computation that requires intermediate state — temporary tables, graph labels, working data — is performed against a private temp file that is created and destroyed within the command. It never touches the user's `.rmtree` file.

When a new command requires writing intermediate state, the question is not "how do we write safely?" It is "why are we writing at all, and can we avoid it?"

---

## Domain Language, Not Schema Language

GenQuery speaks genealogy. Column names, flags, and command names use the words genealogists use, not the words database engineers use.

| Schema language | Domain language |
|---|---|
| `OwnerID` | `RIN` |
| `EventType = 'Occupation'` | `--with occupation` |
| `IsPrimary = 1` | (invisible — always the right name) |
| `FamilyTable JOIN ChildTable` | `genq list families` |
| `root` (label propagation label) | `TreeRoot` |

This is not cosmetic. When a user reads `genq list people --with occupation | where Occupation =~ "President"`, they understand it immediately. When they read `SELECT n.Given FROM NameTable n WHERE n.IsPrimary = 1 AND EXISTS (SELECT 1 FROM EventTable e WHERE e.OwnerID = n.OwnerID AND e.EventType = 8 AND e.Desc LIKE '%President%')`, they need to know the schema.

GenQuery exists precisely so the second form never has to appear in a user's session.

---

## Composability Over Completeness

A small set of well-designed commands that compose is better than a large set of specialized commands that each answer one question.

The right response to "can genq answer question X?" is usually a **pipeline**, not a new command. New commands are warranted when a question requires domain knowledge (like tree membership) that users cannot reasonably reconstruct from primitives, or when the same pipeline appears repeatedly enough to deserve a name.

Before adding a command, ask: can this be expressed clearly as a two- or three-stage pipeline from existing commands? If yes, the answer is documentation, not code.

---

## The Question Test

Before shipping any command, read its usage aloud as a question a genealogist would ask.

- `genq list people --with occupation` → "Who are the people, and what did they do for work?" ✓
- `genq tabulate trees` → "How many family trees are there, and how big is each one?" ✓
- `genq list events --rin 394` → "What events are recorded for this person?" ✓

If reading the command requires explaining what a table is, what a join does, or what a numeric type code means — the command is exposing the wrong abstraction. Redesign before shipping.
