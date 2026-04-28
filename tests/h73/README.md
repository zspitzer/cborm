# cborm × Hibernate 7.3 spike

End-to-end smoke test for the JPA criterion pipeline at [models/criterion/jpa/](../../models/criterion/jpa/).
Boots Lucee 7 + the locally-built `extension-hibernate` 7.3.x via [script-runner](https://github.com/lucee/script-runner), seeds a tiny entity graph (User → Role → Org), and exercises the descriptor → JPA assembly → SQL execution flow.

This is a development spike, not a TestBox suite — runs in headless mode against an in-memory HSQLDB, no ColdBox / WireBox dependency. The eventual production validation belongs in `test-harness/tests/specs/criterion/jpa/`.

## Layout

- `Application.cfc` — minimal app, `ormEnabled`, HSQLDB datasource
- `entities/{User,Role,Org}.cfc` — three-entity graph for testing joins, projections, subqueries
- `spike.cfm` — 42 scenarios, 78 assertions, currently all green
- `../../spike-h73.bat` — runner (top-level cborm dir)

## Running

From the cborm repo root:

```bat
./spike-h73.bat
```

Output is captured to `test-output/spike-h73.txt` and dumped to stdout. Exit code 0 = all green.

The .bat assumes:

- Lucee 7 snapshot jar at `D:\work\lucee7\loader\target\lucee-7.0.4.29-SNAPSHOT.jar`
- Extension lex at `D:\work\lucee-extensions\extension-hibernate\target\hibernate-extension-7.3.2.0-SNAPSHOT.lex`
- script-runner cloned at `D:\work\script-runner`
- JDK 21 at `C:\Program Files\Eclipse Adoptium\jdk-21.0.9.10-hotspot`

Tweak the .bat if any of those differ.

## What's covered

Each scenario is one `try { ... check() ... } catch { ... }` block; failures don't short-circuit later scenarios.

Predicates — eq/ne/gt/ge/lt/le, between, like/ilike, in, isNull/isNotNull, isTrue/isFalse, eqProperty + the 5 other property comparisons, idEq, isEmpty/isNotEmpty, sizeEq/sizeGt/sizeGe/sizeLt/sizeLe.

Composition — `Restrictions.$or`, `$and`, `isNot`, `conjunction`/`disjunction`.

Joins — auto-promotion via dotted paths (`role.name`, `role.org.name`), explicit `joinTo` with INNER/LEFT/RIGHT, alias-prefixed paths, multi-level chained joins, `withClause` (ON-clause filtering).

Query options — `order` (multi, dotted, ignoreCase), `firstResult`/`maxResults`, `cache`/`cacheRegion`, hints (`timeout`/`readOnly`/`fetchSize`/`comment`/generic `queryHint`).

Projections — `withProjections(property=, count=, countDistinct=, sum=, avg=, min=, max=, groupProperty=, rowCount=true, id=true)`, `groupBy` via dotted paths, `having` referencing aggregate aliases, `asStruct` (Tuple → struct), `asDistinct`.

Subqueries — `propertyIn`/`propertyNotIn`, `exists`/`notExists`, comparison subqueries (`propertyEq`/`propertyGt`/etc.).

Terminal ops — `list`, `uniqueResult`, `count`, `get(id)`, `getOrFail(id)`.

Flow helpers — `peek`, `when`, `unless`.

Stub guards — every legacy method that has no clean JPA equivalent (`Restrictions.sql`, `getSQL`, `asStream`, `createSubcriteria`, etc.) throws `cborm.JPA.NotImplemented` with a typed exception and an actionable detail message.

## When to extend

Add a scenario when:

- A new descriptor type is added to `models/criterion/jpa/Restrictions.cfc` or `Subqueries.cfc`
- An assembler case in `JPAAssembler.cfc` gains new behaviour
- A bug surfaces in production that the existing scenarios miss

Each scenario should produce a verifiable count or property check — `check( "label", boolean, "detail" )`. Avoid scenarios that only check "didn't throw" — assert observable behaviour.

## Eventual home

These scenarios should be ported to TestBox specs under `test-harness/tests/specs/criterion/jpa/` once the dispatcher in `BaseORMService.cfc` is exercised by cborm's existing CI matrix (Lucee 5/6/7, Adobe 2021/2023/2025, BoxLang). Until then, this spike is the proof.

## CommandBox server (long-running)

For interactive testing against the H7.3 extension, the repo also ships [`server-lucee-h73@7.json`](../../server-lucee-h73@7.json) — a CommandBox config that boots Lucee 7 + Java 21 on port 60300 with the test-harness as webroot.

```sh
box server start serverConfigFile=server-lucee-h73@7.json
```

The config pulls the Lucee 7 snapshot via ForgeBox and points at a local JDK 21 install (paths assume `D:\` layout — adjust for your machine).

**Deploying the H7.3 extension** — the `commandbox-lex` auto-install via `scripts.onServerStart` doesn't fire reliably in this setup, so deploy manually:

```sh
cp /path/to/hibernate-extension-7.3.2.0-SNAPSHOT.lex \
   .engine/lucee-h73/WEB-INF/lucee-server/deploy/
```

Lucee's deploy scanner picks the `.lex` up within a few seconds and registers the ORM engine.

**Database** — the cborm test-harness `Application.cfc` configures a `coolblog` MySQL datasource via env vars; copy [`.env.template`](../../.env.template) to `.env` and adjust to point at a local MySQL (default expects `127.0.0.1:3306`, user `root`, password `mysql`, MySQL connector driver `com.mysql.cj.jdbc.Driver`). With the env in place, the cborm test specs should run against the JPA criterion path via the dispatcher in `BaseORMService.cfc`.
