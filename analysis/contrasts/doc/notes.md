# Table of Contents

1.  [Questions](#org081d72b)
2.  [Data](#org1e0a816)
3.  [Design of experiment](#orgbdea20e)
	1.  [Concepts](#org2138e95)
	2.  [Benchmark data](#orga3dc82e)
4.  [Methods](#org2e34430)
	1.  [General considerations](#org4ff8485)
	2.  [Model matrix](#orgf2eb4fc)
5.  [References](#org678a630)


<a id="org081d72b"></a>

# Questions

Some are documented in [1], others were mentioned in #lumosql at
libera.chat

-   Main questions
	-   What happens to performance when LMDB is swapped in as a storage
		backend for SQLite?
-   Peripheric questions
	-   Does SQLite get faster with each version?
	-   Which compile options make a given version of SQLite faster?
	-   How do different versions and compile options combine to change
		performance as data size gets large?
	-   Does SQLITE<sub>DEBUG</sub> really make SQLite run approximately three
		times slower?
	-   What happens when a given set of compile options, versions and
		data size are tested on faster and slower disks?
	-   Submitted SQLite-only at datasize 100,1 and 1,100 all with and
		without discard to show if, as expected, discard makes no
		significant timing difference other than not crashing on giant
		sizes. (danshearer 20220316)


<a id="org1e0a816"></a>

# Data

-   Download from [/dist/benchmarks-to-date](https://lumosql.org/dist/benchmarks-to-date/)
-   Use the `all-lumosql-benchmark-data-combined.sqlite` file


<a id="orgbdea20e"></a>

# Design of experiment


<a id="org2138e95"></a>

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


<a id="orga3dc82e"></a>

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


<a id="org2e34430"></a>

# Methods


<a id="org4ff8485"></a>

## General considerations

-   Some systems are faster than others, need to account for that
	(Labhraich 20220316)
-   Consider normalizing test timings by the total run time (Labhraich
	1.


<a id="orgf2eb4fc"></a>

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


<a id="org678a630"></a>

# References

1.  [LumoSQL Build and Benchmark System](https://lumosql.org/src/lumosql/doc/trunk/doc/lumo-build-benchmark.md)
