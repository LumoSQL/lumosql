
# Table of Contents

1.  [Research questions](#orgc3e34f0)
2.  [Data](#orge3f663a)
3.  [Design of experiment](#org1fa9c9c)
    1.  [Concepts](#org4c9f39a)
    2.  [LumoSQL versus SQLite](#orga4c3602)
    3.  [Benchmark data](#org4ce47ab)
4.  [Methods](#org5e20a6a)
    1.  [General considerations](#org9602d2a)
    2.  [Model matrix](#org3d7cf37)
5.  [References](#org47694e5)


<a id="orgc3e34f0"></a>

# Research questions

Amassing data is not enough. We need to define the comparisons that
we want to make to design the type of runs suitable for the analysis.

We have *many* run time measurements produced under varying conditions:

-   Data size
-   Backend (unmodified vs. lmdb)
-   SQLite version
-   lmdb version

We have *some* run time measurements produced under varying
conditions of storage, cpu, and OS version. If we want to address
the impact of these on run times, we'd need to produce new runs.

We have *no* data to study the effects of these:

1.  `byte-order`
2.  `option-debug`
3.  `option-lmdb_debug`
4.  `option-lmdb_fixed_rowid`
5.  `option-lmdb_transaction`
6.  `option-rowsum`
7.  `option-rowsum_algorithm`
8.  `option-sqlite3_journal`
9.  `os-type`

These are questions pulled from [1] and or #lumosql at libera.chat

-   [Q1] What happens to performance when LMDB is swapped in as a storage
    backend for SQLite?
-   [Q2] Does SQLite get faster with each version?
-   [Q3] Does LMDB get faster with each version?
-   [Q4] Which compile options make a given version of SQLite faster?
-   [Q5] How do different versions combine to change performance as data size gets large, separately for read and write?
-   [Q6] Do compile options affect performance differently as data size changes?
-   [Q7] Does SQLITE_DEBUG really make SQLite run approximately three
    times slower, as claimed on sqlite.org?
-   [Q8] What happens when a given set of compile options, versions and
    data size are tested on faster and slower disks?
-   [Q9] What is the effect of testing reads and writes on different disks,
    given that the relative speeds for read and write may differ greatly?
-   [Q10] meta-benchmarking question: does the "discard output" option to
    benchmarking make no significant timing difference, as expected?
    (it may prevent benchmarking crashing on giant sizes).

Please, list below your questions in the right category. Leave your
name after each question so we can follow up. Consider framing your
questions in terms of *how much* rather than binary terms (*how
much does A differ from B?* versus *is A higher than B?*)

-   Main questions: that should be up front the focus of the immediate
    runs and analysis
    -   Dan - Q1, Q2, Q3, Q5, Q9
    -   Add question and name here
-   Peripheric questions: that you would like answer as a side effect
    with little to no additional effort involved
    -   Dan - Q4, Q6, Q8
    -   Add question and name here
-   Dream questions: that you would like to answer in the future but
    it's out of reach right now
    -   What is the performance impact of row checksums?  This will
        need to wait until we've reworked the way we store it.
	(Uilebheist 20220325)
    -   What is the impact of using a different strategy to implement
        sqlite transactions using LMDB transactions?  This is the
	`option-lmdb_transaction` but its effect is only visible
	when lots of processes try to run concurrent transaction, and
	would require a different experiment from what we've been running
	(Uilebheist 20220325)
    -   What difference does it make to use the pre-computed checksum
        columns for operations such as selecting the rows which have changed
        compared with a traditional method such as a column called "last updated",
        and also a straight SELECT.
        (Dan 20220405)


<a id="orge3f663a"></a>

# Data

-   Download from [/dist/benchmarks-to-date](https://lumosql.org/dist/benchmarks-to-date/)
-   Start with the `all-lumosql-benchmark-data-combined.sqlite` file
-   For records with empty `sqliteVersion` and `backendName = dbd`, set
    `sqliteVersion` to the version number in the `sqliteTitle` string
-   For records with empty `backendVersion`, set `backendName` and
    `backendVersion` to `unmodified`
-   Subset records with `backendVersion` matching `unmodified|lmdb`
-   Subset records with `sqliteVersion`  matching `3\.3[4-8]`


<a id="org1fa9c9c"></a>

# Design of experiment


<a id="org4c9f39a"></a>

## Concepts

-   **Control variables:** Experimenter-selected treatment variables where knowledge of
    their effect is the primary objective
-   **Environmental variables:** Describe the operating conditions of an experimental
    subject/unit/process
    -   A *blocking factor* is a qualitative environmental variables
        identifying identical groups of experimental material
    -   A *confounding variable* is unrecognized by the experimental
        but actively affect the mean output of the physical
        system. These can mask or exaggerate the effect of a treatment
        variable. E.g., active confounding variable that is correlated
        with the treatment variable.
-   **Model variables:** Not present in this experiment
-   **Reproducibility variables:** data recorded for reproducibility that is expected to have no
    effect, or whose effect is not of interest, on the response


<a id="orga4c3602"></a>

## LumoSQL versus SQLite

LumoSQL runs SQLite with LMDB for key-value storing ([flavor 3](https://lumosql.org/src/lumosql/file?name=new-doc/web/lumosql.org/releases-downloads.html&ci=tip)). We
want to compare runtimes for LumoSQL versus unmodified SQLite,
where the latter acts as a baseline. This analysis focuses on two
configuration sets:


<a id="org4ce47ab"></a>

## Benchmark data

The following table contains all the key-values recorded for each
run. We classify them into the following groups:

1.  Variables selected by the experimenters whose knowledge of their
    effect on running times is the primary objective
2.  Variables not directly selected by the experimenters that can
    plausibly have some impact on running times
3.  Variables that are of no interest, and were recorded only for
    the purpose of reproducibility or debugging the LumoSQL Build
    and Benchmark system, are not expected to impact on running
    times

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">
<caption class="t-above"><span class="table-number">Table 1:</span> ZV = zero-variance variable (Y = yes), B = Bayes, D = Dan, L = Labhraich. Comments from L: 3* if we change the list of tests, <code>notforking-date</code> and <code>-id</code> will help knowing which list we ran, which could affect timings 3** they may affect timings if <code>tests-fail</code>, <code>-intr</code> are non-zero, <code>tests-ok</code> is not 17</caption>

<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />

<col  class="org-right" />

<col  class="org-right" />

<col  class="org-right" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">key</th>
<th scope="col" class="org-left">Example value</th>
<th scope="col" class="org-left">ZV</th>
<th scope="col" class="org-right">B</th>
<th scope="col" class="org-right">D</th>
<th scope="col" class="org-right">L</th>
</tr>
</thead>

<tbody>
<tr>
<td class="org-left">backend</td>
<td class="org-left">bdb-18.1.32</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">backend-date</td>
<td class="org-left">2014-09-20 06:24:32 UTC</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
</tr>


<tr>
<td class="org-left">backend-id</td>
<td class="org-left">&#xa0;</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">?</td>
<td class="org-right">3</td>
</tr>


<tr>
<td class="org-left">backend-name</td>
<td class="org-left">bdb</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">backend-version</td>
<td class="org-left">18.1.32</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">byte-order</td>
<td class="org-left">littleEndian</td>
<td class="org-left">Y</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
</tr>


<tr>
<td class="org-left">cpu-comment</td>
<td class="org-left">Skylake IBRS</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">2</td>
<td class="org-right">2</td>
</tr>


<tr>
<td class="org-left">cpu-type</td>
<td class="org-left">x86<sub>64</sub></td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">2</td>
<td class="org-right">2</td>
</tr>


<tr>
<td class="org-left">disk-comment</td>
<td class="org-left">SATA 7200RPM</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">2</td>
<td class="org-right">2</td>
<td class="org-right">2</td>
</tr>


<tr>
<td class="org-left">disk-read-time</td>
<td class="org-left">0.398953</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">2</td>
<td class="org-right">2</td>
<td class="org-right">2</td>
</tr>


<tr>
<td class="org-left">disk-write-time</td>
<td class="org-left">1.393422</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">2</td>
<td class="org-right">2</td>
<td class="org-right">2</td>
</tr>


<tr>
<td class="org-left">end-run</td>
<td class="org-left">1644063382</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
</tr>


<tr>
<td class="org-left">notforking-date</td>
<td class="org-left">2022-02-16 09:51:24</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3*</td>
</tr>


<tr>
<td class="org-left">notforking-id</td>
<td class="org-left">e2b80d918b83f129ac47cfc5bd9941a&#x2026;</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3*</td>
</tr>


<tr>
<td class="org-left">option-datasize</td>
<td class="org-left">1</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">option-debug</td>
<td class="org-left">off</td>
<td class="org-left">Y</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">option-lmdb<sub>debug</sub></td>
<td class="org-left">off</td>
<td class="org-left">Y</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">option-lmdb<sub>fixed</sub><sub>rowid</sub></td>
<td class="org-left">off</td>
<td class="org-left">Y</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">option-lmdb<sub>transaction</sub></td>
<td class="org-left">optimistic</td>
<td class="org-left">Y</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">option-rowsum</td>
<td class="org-left">off</td>
<td class="org-left">Y</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">option-rowsum<sub>algorithm</sub></td>
<td class="org-left">sha3<sub>256</sub></td>
<td class="org-left">Y</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">option-sqlite3<sub>journal</sub></td>
<td class="org-left">default</td>
<td class="org-left">Y</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">os-type</td>
<td class="org-left">Linux</td>
<td class="org-left">Y</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">2</td>
</tr>


<tr>
<td class="org-left">os-version</td>
<td class="org-left">5.10.0-9-amd64</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">2</td>
<td class="org-right">1</td>
<td class="org-right">2</td>
</tr>


<tr>
<td class="org-left">sqlite-date</td>
<td class="org-left">2020-12-01 16:14:00 UTC</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
</tr>


<tr>
<td class="org-left">sqlite-id</td>
<td class="org-left">1b256d97b553a9611efca188a3d995a&#x2026;</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">1</td>
<td class="org-right">3</td>
</tr>


<tr>
<td class="org-left">sqlite-name</td>
<td class="org-left">3.35.5 2021-04-19 18:32:05 1b25&#x2026;</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">1</td>
<td class="org-right">3</td>
</tr>


<tr>
<td class="org-left">sqlite-version</td>
<td class="org-left">3.35.5</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">target</td>
<td class="org-left">3.35.5</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">tests-fail</td>
<td class="org-left">0</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3**</td>
</tr>


<tr>
<td class="org-left">tests-intr</td>
<td class="org-left">0</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3**</td>
</tr>


<tr>
<td class="org-left">tests-ok</td>
<td class="org-left">17</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3**</td>
</tr>


<tr>
<td class="org-left">title</td>
<td class="org-left">sqlite 3.35.5</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">1</td>
<td class="org-right">1</td>
</tr>


<tr>
<td class="org-left">when-run</td>
<td class="org-left">1644063269</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
<td class="org-right">3</td>
</tr>


<tr>
<td class="org-left">word-size</td>
<td class="org-left">8</td>
<td class="org-left">&#xa0;</td>
<td class="org-right">3</td>
<td class="org-right">1</td>
<td class="org-right">3</td>
</tr>
</tbody>
</table>


<a id="org5e20a6a"></a>

# Methods


<a id="org9602d2a"></a>

## General considerations

-   Some systems are faster than others, need to account for that
    (Labhraich 20220316)
-   Consider normalizing test timings by the total run time (Labhraich
    1.


<a id="org3d7cf37"></a>

## Model matrix

`log(realTime) ~ backendName * backendVersion + diskComment +
   optionDatasize + sqliteVersion + (1|cpuComment) + (1|osVersion)`

Notes on zero-variance variables: these are excluded because they
have no variability in the collected data

1.  `byte-order`
2.  `option-debug`
3.  `option-lmdb_debug`
4.  `option-lmdb_fixed_rowid`
5.  `option-lmdb_transaction`
6.  `option-rowsum`
7.  `option-rowsum_algorithm`
8.  `option-sqlite3_journal`
9.  `os-type`

Notes on control variables:

1.  Include the interaction between `backend-name` and
    `backend-version` if there is interest in the latter main
    effect. Drop `backend`, which is 1-1 to the interaction.
2.  Include `diskComment`. `diskReadTime` and `DiskWriteTime` are
    correlated with `diskComment`, no need to have the times in the
    model.
3.  Include `option-datasize` as categorical because the effect
    might be non-lineal
4.  Include `sqlite-version`

Notes on environmental variables:

1.  Include `cpuComment` for blocking, drop `cpuType`. There is only
    one `cpuComment` with `cpuType=armv7l`
2.  Include `osVersion` for blocking, drop `osType`

Notes on reproducibility variables: these are excluded from model
as they were <span class="underline">not</span> recorded for their relevance with respect to the
question but for reproducibility or debugging purposes.

Notes on pending variables: their role in the model matrix is still
TBD

1.  All control variables not commented on.


## Other considerations

- Comments from gabby_bch (2022-04-05)
  - error bar runs: 5.4.0.91-generic, 5.15.29
  - big error bars: 5.13.0-22-generic
  - sqlite old normal : 5.4.0-100-generic
  - anomaly: 5.4.0.104-generic
  - unmodified superior to lmdb: 5.10.92, 5.10.100
  - lmdb superior to unmodified: 5.15.24
  - compare cpu influence: 5.10.91, 5.10.92
  - raspberry pi: 5.10.63

<a id="org47694e5"></a>

# References

1.  [LumoSQL Build and Benchmark System](https://lumosql.org/src/lumosql/doc/trunk/doc/lumo-build-benchmark.md)

