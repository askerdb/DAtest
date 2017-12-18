DAtest
======

This is a package for comparing different differential abundance methods
used in microbial marker-gene (e.g. 16S rRNA), RNA-seq and
protein/metabolite abundance analysis.

There are many methods for testing differential abundance and no gold
standard, but results can vary a lot between the different statistical
methods. The false positive rate and the power of the different methods
highly depends on the dataset. This package aims at aiding the analyst
in choosing a method for a specific dataset based on empirical testing.

#### The method goes as follows:

-   Shuffle predictor variable (E.g. case vs. control)
-   Spike in data for some randomly chosen features (OTU/gene/protein),
    such that they are associated with the shuffled predictor
-   Apply methods, and check:
    -   whether they can find the spike-ins
    -   whether the false positive rate is controlled

#### The intended workflow (details can be found below):

-   Compare methods with `testDA` function
    -   Check the results with `plot` or `summary`
    -   Choose method that has high AUC, and FPR not higher than ~0.05
    -   (Optional but recommended) Explore the sensitivity and false
        discovery rate of the chosen method with `powerDA`
-   Run data with the chosen test with `DA."test"` function, where
    "test" is the name of the test
    -   Check out your final results.

### Citation

Please cite the following publication if you use the DAtest package:

Russel *et al.* (2017) DAtest: A framework for choosing differential
abundance or expression method. *Submitted*

Remember also to cite the method you end up using for your final
analysis (See [implemented methods](#implemented-methods) for links). If
there is no associated publication (e.g. for a t-test) you can cite as
follows: ."we used t-test as implemented in DAtest version x.x.x (Russel
*et al.* 2017)"

Overview of this tutorial
-------------------------

-   [Installation of packages](#installation-of-packages)
-   [How to compare methods](#how-to-compare-methods)
    -   [The test](#run-the-test)
    -   [Multi-class
        predictors](#if-your-predictor-is-categorical-with-more-than-two-levels)
    -   [Paired or blocked experimental
        design](#if-you-have-a-paired-or-blocked-experimental-design)
    -   [External normalization or absolute
        abundances](#if-data-is-normalized-externally-or-represent-absolute-abundances)
    -   [Covariates](#if-you-have-covariates)
    -   [Phyloseq objects](#if-you-have-a-phyloseq-object)
    -   [Power analysis](#power-analysis)
-   [How to run real data](#how-to-run-real-data)
    -   [Compare results from many
        methods](#run-all-or-several-methods-and-check-which-features-are-found-by-several-methods)
-   [Implemented methods](#implemented-methods)
-   [Extra features](#extra-features)

Examples
--------

See full examples on a test dataset here:

-   [Two-class
    (or Quantitative)](http://htmlpreview.github.com/?https://github.com/Russel88/DAtest/blob/master/script/script_twoclass.html)
-   [Multi-class](http://htmlpreview.github.com/?https://github.com/Russel88/DAtest/blob/master/script/script_multiclass.html)
-   [Covariates](http://htmlpreview.github.com/?https://github.com/Russel88/DAtest/blob/master/script/script_covars.html)

The examples use the [phyloseq
package](https://joey711.github.io/phyloseq/), but the workflow would be
the similar if the input is a count table in the form of a data.frame or
matrix.

Installation of packages
========================

It is advised not to have any packages loaded when installing DAtest.
Installation of DAtest and all dependencies has been tested to work on a
clean R version 3.4.1 by installing in the following order:

The DAtest package:

    install.packages("devtools")
    library(devtools)
    install_github("Russel88/DAtest")

#### The following are needed for *full* functionality

But the package will work without them

    source("https://bioconductor.org/biocLite.R")
    biocLite("DESeq2")
    biocLite("limma")
    biocLite("edgeR")
    biocLite("metagenomeSeq")
    biocLite("baySeq")
    biocLite("ALDEx2")
    biocLite("qvalue")

    biocLite("impute") # For SamSeq
    install.packages("samr") # SamSeq

    install.packages("pscl") # Zero-inflated Poisson and zero-inflated Negative Binomial
    install.packages("statmod") # For limma with blocking

-   RAIDA and ANCOM have to be installed from external sources:

<!-- -->

    # Dependencies (after the bioconductor packages are installed)
    install.packages(c("shiny","exactRankTests","openxlsx","protoclust","DT","coin","stringr"))

    # RAIDA:
    install.packages("https://cals.arizona.edu/~anling/software/RAIDA_1.0.tar.gz",repos = NULL)

    # ANCOM (by default not included, as it is very slow):
    download.file("https://www.niehs.nih.gov/research/resources/software/biostatistics/ancom/ancom_software.zip",destfile = "ANCOM.zip")
    unzip("ANCOM.zip",exdir=getwd())
    install.packages("ancom.R_1.1-3.tar.gz", repos = NULL)

**Note:** If installation fails for any of the bioconductor or external
packages (RAIDA, ANCOM) do not despair. `DAtest` will work seamlessly,
but will simply exclude methods that depends on these packages.

The following are suggested, but not needed:

    # For drawing Venn diagrams
    install.packages("eulerr")

    # For post-hoc testing (generalized) linear models
    install.packages("lsmeans")

How to compare methods
======================

Methods are compared with "False Positve Rate" (FPR), "Area Under the
(Receiver Operator) Curve" (AUC), and potentially also "Spike Detection
Rate" (Spike.detect.rate).

By shuffling the predictor variable and spiking a subset of the
features, we know a priori which features should be siginificant (the
spiked features) and which features shouldn't (the non-spiked features).

FPR indicates the proportion of non-spiked features that were found to
be significant (raw p-value below 0.05). With randomly generated data
the p-value distribution should be uniform (flat) and 5% of the raw
p-values are expected to be below 0.05. We therefore want an FPR at 0.05
or lower.

AUC is estimated by ranking all features by their respective p-value,
and finding the area under the ROC curve. For a good method p-values
from the spiked features should be among the lowest. For a perfect
method, with AUC = 1, all the lowest p-values are spiked features. An
AUC of 0.5 means that p-values from the spiked features are randomly
spread across the spectrum. An AUC below 0.5 means that p-values from
spiked features in general are *higher* than for non-spiked features.
Therefore, we want an AUC as high as possible; spiked features should
have low p-values.

Spike.detect.rate is the proportion of spiked features that are
significant after multiple correction of the p-values. It is therefore
the proportion of features you would expect to detect in a regular
analysis. The higher Spike.detect.rate, the better.

-   The intended workflow for choosing a method is:
    -   Omit methods with FPR significantly higher than 0.05
    -   Of remaining methods, choose the one with highest AUC
    -   If several methods have very similar AUCs, the Spike.detect.rate
        can be used to differentiate among the methods

**Assumption of the test:** the test assumes that only few features are
truly differentially abundant. Therefore, if many features are different
between the samples, and this difference can truly be explained by the
`predictor`, AUCs of the methods will be less than they actually are,
but FPRs can still be trusted.

### Pre-process data:

An optional step is to pre-process the data to reduce the number of
features tested. With `preDA` low-abundance features can be grouped as
"Others". Note that the features are not simply pruned, they are grouped
to retain samples sums (library sizes). Filtering can be based on number
of samples the features are present in, the total number of reads for
the features, the mean relative abundance of the features, or a
combination of all three.

    data.new <- preDA(data, min.samples = 2, min.reads = 10, min.abundance = 0)

### Run the test

(if you have a phyloseq object, see details further down)

    mytest <- testDA(data, predictor, R = 10)

`data` is either a matrix or data.frame with taxa/genes/proteins as rows
and samples as columns (with rownames).

`predictor` is the predictor of interest, e.g. a factor denoting whether
samples are cases or controls (in the same order as columns in data).

`predictor` can be a factor with more than two levels, in which case
only the second level is spiked.

`predictor` can also be continuous/quantitative

**Important:** If `predictor` is numeric it will be treated as a
quantitative variable in the analyses. Therefore, if you, for example,
have two groups of samples and call the groups 0 and 1, it will be
treated as a quantitative variable and it will not run t-test,
wilcoxon-test, and others dedicated for two-class predictors. Write
`predictor` as `as.factor(predictor)` to treat it as a categorical
variable. The `testDA` function will produce a message telling you how
the `predictor` is read - Make sure this fits your expectations!

`R` denotes how many times the spike-in and FPR/AUC calculation should
be replicated. It is advised to use at least 10, but it can be set to 1
for a fast test of the function.

A subset of methods can be run by setting the `tests` argument.

#### **The function automatically uses multiple CPUs for fast execution**

The methods run in parallel, and by default the number of cores used is
one less than available. It has been tested to work on Windows, OS X and
Linux Debian. It can be changed with the `cores` argument. `cores = 1`
will turn off parallel computing. If the function is terminated before
ending you might get the following warning, which can safely be ignored:

    closing unused connection X (...)

But if you have terminated the function before it ended and your
computer runs slow, you might want to restart R to close all
connections.

If you run out of memory/RAM, try again with a clean R environment or
reduce the number of cores used for computing.

### If you have more than 10k features (or 5k for paired analysis)

Runtime of the different methods can vary quite a lot, and some methods
are simply unfeasible for datasets with several thousands of features.
The `runtimeDA` function can estimate the runtime of the different
methods on your dataset: It runs on small subsets of the data and then
extrapolates the runtime from these subsets. It will not be super
precise if you have tenths of thousands of features or more, but it
should give a decent estimate. The function prints how many minutes it
will take to run each method one time and `R` times. If you only use 1
core the actual runtime will be the sum of all the methods. With more
cores the runtime will decrease and approach the runtime of the slowest
method.

    runtimeDA(data, predictor)

### If your predictor is categorical with more than two levels

There are generally two ways to output results with a categorical
predictor with multiple levels; either there is one p-value indicating
whether the categories are similar or different (e.g. as in ANOVA), or
there is one p-value for each level, where the first level is set as
intercept and the remaining levels are tested against the intercept
(e.g. in linear regression). For some methods you can choose which
option fits you, with other methods not, but it is crucial that this
option is similar in the `testDA` function as in the final analysis.

By default, for all methods possible you get one p-value for multi-class
predictor variables. For ANOVA and linear models (+GLMs) you can
subsequently run post-hoc tests for all pairwise comparisons (see [extra
features](#extra-features)).

For linear models (lrm, llm, llm2), GLMs (poi, neb, qpo, zpo, znb),
limma models (vli, lim, lli, lli2), edgeR (erq, erq2) and DESeq (ds2,
ds2x), you can use the `out.all` argument to toggle how multi-class
predictors are treated. If `out.all = TRUE` (default for multi-class
predictors) you get one p-value for the predictor (no matter how many
levels/categories it has). If `out.all = FALSE` you get the p-value for
the level of the predictor specificed by `coeff` tested against the
intercept (default 2. level, as it is the one spiked in `testDA`). Use
this if you are interested in testing two or more levels against a
baseline, and remember to set the levels of the `predictor` such that
the baseline is the first level (e.g. factor(predictor, levels =
c("baseline","treatment1","treatment2"))).

*Important:* log2FC is by default the fold change between the 2. and 1.
level of the `predictor`, no matter what `out.all` is set to. Use the
`coeff` argument to change this.

#### *Below is a description of how the different methods treat multi-class predictors:*

Linear models (lrm, llm, llm2) and GLMs (poi, neb, qpo, zpo, znb) use
`anova`/`drop1` if `out.all=TRUE`

Limma models run moderate F-test if `out.all=TRUE` and moderated t-test
otherwise. You can set `allResults = TRUE` and use `topTable` on the
output to get the desired results.

MetagenomeSeq Zig is set to always output p.values from the 2. level of
the `predictor`. For your final analysis use the `by` argument to change
this, or set `allResults = TRUE` and then use `MRtable` on the output to
get the desired results.

DESeq2 is running Log Ratio Test (LRT) if `out.all=TRUE` and Wald test
otherwise. log2FoldChange is by default the fold change between the
second and first level of the predictor for LRT, and fold change between
second level and overall mean for Wald test, use the `coeff` argument to
change this. For your final analysis you can set `allResults = TRUE` and
use `results` on the output, e.g. for getting pairwise comparisons or
p-values/log2FC for covariates.

For SAMSeq, ANOVAs, Quade test, Friedman test, Kruskal-Wallis test you
always get one p-value for the `predictor`

### If you have a paired or blocked experimental design

E.g. repeated samples from same patients, or control/treatments inside
blocks.

The `paired` argument should be a factor with the ID of the
patient/subject/block (in the same order as columns in `data`):

    mytest <- testDA(data, predictor, paired = subjectID)

When a `paired` argument is provided, the `predictor` is shuffled within
the levels of the `paired` factor.

Paired analysis can be very slow. If you simply can't wait to see the
results remove "neb" from the `tests` argument.

See section on [implemented methods](#implemented-methods) for which
models accept a `paired` argument.

### If data is normalized externally or represent absolute abundances

E.g. normalized protein abundance, normalized metabolite abundance, or
absolute microbiome abundance

    mytest <- testDA(data, predictor, relative = FALSE)

Setting `relative=FALSE` will disable internal normalizations. It is
therefore for externally normalized abundances or absolute abundances.

If `relative=FALSE` the values in `data` will NOT be normalized by the
sum of the samples for "ttt", "ltt", "ltt2", "wil", "per", "lrm", "llm",
"llm2", "lim", "lli", "lli2", "pea", "spe", "aov", "lao", "lao2" and
"kru", and there will NOT be an offset of log(librarySize) for "neb",
"poi", "qpo", "zpo" and "znb". Furthermore, tests that are specifically
designed to handle sequence data are turned off: DESeq2, EdgeR,
MetagenomeSeq, ANCOM, RAIDA, ALDEx2 and baySeq. Therefore, the `data` is
analysed as provided, except for the tests that log-transform the data:
"ltt", "llm", "lli" and "lao".

### If you have covariates

The `covars` argument should be a named list with the covariables (in
the same order as columns in `data`):

    mytest <- testDA(data, predictor, covars = list(Age = subject.age, Date = exp.date))

### If you have a phyloseq object

`data` can also be a phyloseq object. In this case, the `predictor`,
`paired` and `covars` arguments are the names of the variables in
`sample_data(data)`:

    mytest <- testDA(data, predictor = "Time", paired = "Patient", covars = c("Age","ExpDate"))

**Check the output:**
---------------------

    plot(mytest)
    summary(mytest)

    # Details from the run:
    mytest$details

    # Average run times of each method:
    mytest$run.times

**Note:**

As SAMseq does not output p-values, FPR for this method is the final
false discovery rate (false positives / total positives). FPR might
therefore vary quite a lot. If SAMSeq is one of the methods with highest
AUC, you can run `testDA` again but with a higher `fdr.output` argument
for "sam" (e.g.
`testDA(...,args = list(sam = list(fdr.output = 0.25))))` to get a
better estimate. If `fdr.output=0.25` we should expect FPR for "sam"
from `testDA` to be 0.25 or lower.

P-values for baySeq are defined as 1 - posterior likelihoods.

### Power analysis

After a method has been chosen, you can run a power analysis. This can
also be run to distinguish between methods appearing to be equally good
in `testDA`. `powerDA` spikes the data with different effects sizes and
along with AUC and FPR it estimates with Empircal Power (aka
Spike.detect.rate aka sensitivity) and the False Discovery Rate (FDR).
The Empirical Power gives you an estimate of the proportion of true
effects at a given effect size you are likely to discover (after p-value
adjustment). The FDR tells you what proportion of the detected features
are likely false positives (after p-value adjustment).

Only one test can be run at a time, here MetagenomeSeq Feature model is
run (see details in `testDA` for test abbreviations):

    po.msf <- powerDA(data, predictor, test = "msf")
    plot(po.msf)
    summary(po.msf)

**Assumption of the test:** as with `testDA`, `powerDA` also assumes
that only few features are truly differentially abundant. Therefore, if
many features are different between the samples, and this difference can
truly be explained by the `predictor`, AUC and Power of the methods will
appear worse than they actually are. In contrast, FPR and FDR can still
be trusted.

How to run real data
====================

All tests can easily be run with the original data. E.g. edgeR exact
test:

    res.ere <- DA.ere(data, predictor)

All methods can be accessed in the same way; DA."test" where "test" is
the abbreviation given in the details of the `testDA` function.

The default output should be fine for most users, but you can set
`allResults = TRUE` to obtain the raw results. With the raw results you
can run post-hoc tests on linear models and ANOVA models (for
multi-class predictors), and you check for significance of covars. See
more under [Extra features](#extra-features).

**Plot association between specific feature and predictor**

`featurePlot` will plot abundance of a feature against the `predictor`
to visually explore your data:

    featurePlot(data, predictor, feature = "OTU1")

If a `paired` variable is supplied it will make coloured line plots
grouped by the `paired` variable If `covars` are supplied plots are
facetted according to these.

**Test if groups of features are overrepresented among significant
features**

`groupSig` will test if there is a significant overrepresentation of
certain groups of features among the significant ones. For microbiome
data you can, for example, test if OTUs from some specific phyla or
family are more likely to be significant than others. For proteomics you
can, for example, test if proteins from some specific KEGG pathways are
more likely to be significant than others. The groups can in principle
be anything.

    groupSig(results, group.df, group.cols)

`results` is the output from a `DA."test"` function. `group.df` is a
data.frame giving one or more grouping variables, with row.names
mathcing the `Feature` column in `results` (e.g. the `tax_table` from a
phyloseq object). `group.cols` denotes which columns in `group.df` are
used for testing (E.g. `group.cols = 1:3` will use the first three
columns).

Run all or several methods and check which features are found by several methods
--------------------------------------------------------------------------------

With `allDA` we can run several methods and easily compare their results

A subset of methods can be run by setting the `tests` argument. E.g.
only those performing well based on results from `testDA`.

    # Run many methods:
    res.all <- allDA(data, predictor)

    # Adjusted p-values from all methods (detection/no-detection from sam and anc)
    res.all$adj

    # Estimates/fold.changes from all methods that output anything relevant for this
    res.all$est

    # Venn (Euler) diagram of detected features from selected methods:
    # This requires the eulerr package
    vennDA(res.all, tests = c("wil","ttt","ltt"))

    # Split Venn (Euler) diagram in significant features with either positive or negative fold changes (if possible)
    vennDA(res.all, tests = c("wil","ttt","ltt"), split = TRUE)

    # See results from a method (e.g. t.test "ttt"):
    View(res.all$results$ttt)

Implemented methods
===================

### Is your favorite method missing?

Either add it yourself [(see under 'Extra features')](#extra-features),
or write to me, preferably with a code snippet of the implementation
(see email in Description, R/DA.zzz.R can be used as a template).

### Methods:

<table>
<thead>
<tr class="header">
<th></th>
<th align="left">Abbr. (link)</th>
<th align="left">Response</th>
<th align="left">Paired/Blocked</th>
<th align="left">Covars</th>
<th align="left">Normalization</th>
<th align="left">Transf.</th>
<th align="left">Model</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>ALDEx2</td>
<td align="left"><a href="http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0067019">adx</a></td>
<td align="left">Two-class</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">ILR</td>
<td align="left"></td>
<td align="left">Poisson/Dirichlet</td>
</tr>
<tr class="even">
<td>ANCOM</td>
<td align="left"><a href="https://www.ncbi.nlm.nih.gov/pubmed/26028277">anc</a></td>
<td align="left">Two-class</td>
<td align="left">Yes</td>
<td align="left">No</td>
<td align="left">Log ratio</td>
<td align="left"></td>
<td align="left">Nonparametric</td>
</tr>
<tr class="odd">
<td>ANOVA</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Analysis_of_variance">aov</a></td>
<td align="left">Multi-class</td>
<td align="left">No</td>
<td align="left">Yes</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Gaussian</td>
</tr>
<tr class="even">
<td>ANOVA log</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Analysis_of_variance">lao</a></td>
<td align="left">Multi-class</td>
<td align="left">No</td>
<td align="left">Yes</td>
<td align="left">TSS (2)</td>
<td align="left">Log (3)</td>
<td align="left">Gaussian</td>
</tr>
<tr class="odd">
<td>ANOVA log2</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Analysis_of_variance">lao2</a></td>
<td align="left">Multi-class</td>
<td align="left">No</td>
<td align="left">Yes</td>
<td align="left">TSS</td>
<td align="left">Log</td>
<td align="left">Gaussian</td>
</tr>
<tr class="even">
<td>baySeq</td>
<td align="left"><a href="https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-11-422">bay</a></td>
<td align="left">Two-class</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">Quantile (4)</td>
<td align="left"></td>
<td align="left">Negative Binomial</td>
</tr>
<tr class="odd">
<td>Correlation - Pearson</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Pearson_correlation_coefficient">pea</a></td>
<td align="left">Quantitative</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Bivariate Normal</td>
</tr>
<tr class="even">
<td>Correlation - Spearman</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Spearman%27s_rank_correlation_coefficient">spe</a></td>
<td align="left">Quantitative</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Nonparametric</td>
</tr>
<tr class="odd">
<td>DESeq2</td>
<td align="left"><a href="https://genomebiology.biomedcentral.com/articles/10.1186/s13059-014-0550-8">ds2x</a></td>
<td align="left">Categorical</td>
<td align="left">Yes, as covariate</td>
<td align="left">Yes</td>
<td align="left">RLE</td>
<td align="left"></td>
<td align="left">Negative Binomial</td>
</tr>
<tr class="even">
<td>DESeq2 man. geoMeans</td>
<td align="left"><a href="https://genomebiology.biomedcentral.com/articles/10.1186/s13059-014-0550-8">ds2</a></td>
<td align="left">Categorical</td>
<td align="left">Yes, as covariate</td>
<td align="left">Yes</td>
<td align="left">RLE (5)</td>
<td align="left"></td>
<td align="left">Negative Binomial</td>
</tr>
<tr class="odd">
<td>EdgeR - Exact test</td>
<td align="left"><a href="https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2796818/">ere</a></td>
<td align="left">Two-class</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">TMM</td>
<td align="left"></td>
<td align="left">Negative Binomial</td>
</tr>
<tr class="even">
<td>EdgeR - Exact test2</td>
<td align="left"><a href="https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2796818/">ere2</a></td>
<td align="left">Two-class</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">RLE</td>
<td align="left"></td>
<td align="left">Negative Binomial</td>
</tr>
<tr class="odd">
<td>EdgeR - Quasi likelihood</td>
<td align="left"><a href="https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2796818/">erq</a></td>
<td align="left">All</td>
<td align="left">Yes, as covariate</td>
<td align="left">Yes</td>
<td align="left">TMM</td>
<td align="left"></td>
<td align="left">Negative Binomial</td>
</tr>
<tr class="even">
<td>EdgeR - Quasi likelihood2</td>
<td align="left"><a href="https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2796818/">erq2</a></td>
<td align="left">All</td>
<td align="left">Yes, as covariate</td>
<td align="left">Yes</td>
<td align="left">RLE</td>
<td align="left"></td>
<td align="left">Negative Binomial</td>
</tr>
<tr class="odd">
<td>Friedman Rank Sum test</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Friedman_test">fri</a></td>
<td align="left">Multi-class</td>
<td align="left">Exclusively</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Nonparametric</td>
</tr>
<tr class="even">
<td>GLM - Negative binomial</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Negative_binomial_distribution">neb</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">None (1)</td>
<td align="left"></td>
<td align="left">Negative Binomial</td>
</tr>
<tr class="odd">
<td>GLM - Poisson</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Poisson_distribution">poi</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">None (1)</td>
<td align="left"></td>
<td align="left">Poisson</td>
</tr>
<tr class="even">
<td>GLM - Quasi-poisson</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Quasi-likelihood">qpo</a></td>
<td align="left">All</td>
<td align="left">No</td>
<td align="left">Yes</td>
<td align="left">None (1)</td>
<td align="left"></td>
<td align="left">Quasi-poisson</td>
</tr>
<tr class="odd">
<td>GLM - ZI Negative Binomial</td>
<td align="left"><a href="https://cran.r-project.org/web/packages/pscl/index.html">znb</a></td>
<td align="left">All</td>
<td align="left">No</td>
<td align="left">Yes</td>
<td align="left">None (1)</td>
<td align="left"></td>
<td align="left">Zero-inflated Negative binomial</td>
</tr>
<tr class="even">
<td>GLM - ZI Poisson</td>
<td align="left"><a href="https://cran.r-project.org/web/packages/pscl/index.html">zpo</a></td>
<td align="left">All</td>
<td align="left">No</td>
<td align="left">Yes</td>
<td align="left">None (1)</td>
<td align="left"></td>
<td align="left">Zero-inflated Poisson</td>
</tr>
<tr class="odd">
<td>Kruskal-Wallis test</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Kruskal%E2%80%93Wallis_one-way_analysis_of_variance">kru</a></td>
<td align="left">Multi-class</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Nonparametric</td>
</tr>
<tr class="even">
<td>LIMMA</td>
<td align="left"><a href="https://link.springer.com/chapter/10.1007%2F0-387-29362-0_23?LI=true">lim</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Gaussian</td>
</tr>
<tr class="odd">
<td>LIMMA log</td>
<td align="left"><a href="https://link.springer.com/chapter/10.1007%2F0-387-29362-0_23?LI=true">lli</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">TSS (2)</td>
<td align="left">Log (3)</td>
<td align="left">Gaussian</td>
</tr>
<tr class="even">
<td>LIMMA log2</td>
<td align="left"><a href="https://link.springer.com/chapter/10.1007%2F0-387-29362-0_23?LI=true">lli2</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">TSS</td>
<td align="left">Log</td>
<td align="left">Gaussian</td>
</tr>
<tr class="odd">
<td>LIMMA voom</td>
<td align="left"><a href="https://link.springer.com/chapter/10.1007%2F0-387-29362-0_23?LI=true">vli</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">TMM</td>
<td align="left">Voom</td>
<td align="left">Gaussian</td>
</tr>
<tr class="even">
<td>Linear regression</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Linear_regression">lrm</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Gaussian</td>
</tr>
<tr class="odd">
<td>Linear regression log</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Linear_regression">llm</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">TSS (2)</td>
<td align="left">Log (3)</td>
<td align="left">Gaussian</td>
</tr>
<tr class="even">
<td>Linear regression log2</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Linear_regression">llm2</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">TSS</td>
<td align="left">Log</td>
<td align="left">Gaussian</td>
</tr>
<tr class="odd">
<td>MetagenomeSeq featuremodel</td>
<td align="left"><a href="https://bioconductor.org/packages/release/bioc/html/metagenomeSeq.html">msf</a></td>
<td align="left">Two-class</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">CSS</td>
<td align="left"></td>
<td align="left">Zero-inflated Lognormal</td>
</tr>
<tr class="even">
<td>MetagenomeSeq ZIG</td>
<td align="left"><a href="https://www.nature.com/nmeth/journal/v10/n12/full/nmeth.2658.html">zig</a></td>
<td align="left">All</td>
<td align="left">Yes, as random effects</td>
<td align="left">Yes</td>
<td align="left">CSS</td>
<td align="left">Log</td>
<td align="left">Zero-inflated Gaussian</td>
</tr>
<tr class="odd">
<td>Permutation test</td>
<td align="left"><a href="https://microbiomejournal.biomedcentral.com/articles/10.1186/s40168-016-0208-8">per</a></td>
<td align="left">Two-class</td>
<td align="left">Yes</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Nonparametric</td>
</tr>
<tr class="even">
<td>Quade test</td>
<td align="left"><a href="http://rcompanion.org/handbook/F_11.html">qua</a></td>
<td align="left">Multi-class</td>
<td align="left">Exclusively</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Nonparametric</td>
</tr>
<tr class="odd">
<td>RAIDA</td>
<td align="left"><a href="https://academic.oup.com/bioinformatics/article/31/14/2269/256302/A-robust-approach-for-identifying-differentially">rai</a></td>
<td align="left">Two-class</td>
<td align="left">No</td>
<td align="left">No</td>
<td align="left">Ratio</td>
<td align="left"></td>
<td align="left">Zero-inflated Lognormal</td>
</tr>
<tr class="even">
<td>SAMseq</td>
<td align="left"><a href="http://statweb.stanford.edu/~tibs/SAM/">sam</a></td>
<td align="left">All</td>
<td align="left">Yes</td>
<td align="left">No</td>
<td align="left">Resampling</td>
<td align="left"></td>
<td align="left">Nonparametric</td>
</tr>
<tr class="odd">
<td>Welch t.test</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Welch%27s_t-test">ttt</a></td>
<td align="left">Two-class</td>
<td align="left">Yes</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Gaussian</td>
</tr>
<tr class="even">
<td>Welch t.test log</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Welch%27s_t-test">ltt</a></td>
<td align="left">Two-class</td>
<td align="left">Yes</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left">Log (3)</td>
<td align="left">Gaussian</td>
</tr>
<tr class="odd">
<td>Welch t.test log2</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Welch%27s_t-test">ltt2</a></td>
<td align="left">Two-class</td>
<td align="left">Yes</td>
<td align="left">No</td>
<td align="left">TSS</td>
<td align="left">Log</td>
<td align="left">Gaussian</td>
</tr>
<tr class="even">
<td>Wilcoxon</td>
<td align="left"><a href="https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test">wil</a></td>
<td align="left">Two-class</td>
<td align="left">Yes</td>
<td align="left">No</td>
<td align="left">TSS (2)</td>
<td align="left"></td>
<td align="left">Nonparametric</td>
</tr>
</tbody>
</table>

##### Table descriptions:

-   1: Log of library sizes used as offset when `relative = TRUE`
-   2: None when `relative = FALSE`
-   3: Log transformation is done before normalization
-   4: This can be be changed to TSS or TMM
-   5: This version of DESeq2 uses manual geometric means which handle
    zeroes differently than the default. See more
    [here](https://github.com/joey711/phyloseq/issues/387)
-   TSS: Total Sum Scaling
-   TMM: Trimmed Mean by M-value
-   RLE: Relative Log Expression
-   CSS: Cumulative Sum Scaling
-   ILR: Isometric Log-Ratio

#### Paired permutation test

A paired permutation test is implemented specifically for this package.
The test is similar to the original, but with a different test statistic
and permutation scheme. The permutations are constrained in the paired
version such that the predictor is only permuted within each level of
the paired argument (e.g. subjects). The test statistic first finds the
log-ratio between the two predictor levels (e.g. case and control) for
each level of the paired argument and the final statistic is the mean of
these log-ratios.

Extra features
==============

### Plot p-value histograms for all the non-spiked features

    plot(mytest, p = TRUE)

### Post-hoc tests for linear models and ANOVAs

For anova and linear models we can run post-hoc tests for all pairwise
comparisons of multi-class `predictor`/`covars`.

    ### Apply TukeyHSD for each feature for a selected variable and output the adjusted p-values:
    # Works on "aov", "lao", "lao2"
    results <- DA.aov(data, predictor, allResults = TRUE)
    res.tukey <- DA.TukeyHSD(results, variable = "predictor") # variable can also be the name of a covar

    ### Apply lsmeans for each feature for a selected variable and output the adjusted p-values:
    # This requires the lsmeans package.
    # Works on "poi", "neb", "lrm", "llm", "llm2", "qpo", "znb", "zpo"
    results <- DA.lrm(data, predictor, allResults = TRUE)
    res.lsm <- DA.lsmeans(results, variable = "predictor") # variable can also be the name of a covar

    # For paired "lrm", "llm", "llm2" the original predictor variable has to be supplied. For example:
    results <- DA.lrm(data, predictor = mypred, paired = SubjectID,  allResults = TRUE)
    res.lsm <- DA.lsmeans(results, variable = "predictor", predictor = mypred)

    # and if covars are used, they also need to be supplied for paired "lrm", "llm", "llm2". For example:
    results <- DA.lrm(data, predictor = mypred, paired = SubjectID, covars = list(covar1 = mycovar),  allResults = TRUE)
    res.lsm <- DA.lsmeans(results, variable = "predictor", predictor = mypred, covars = list(covar1 = mycovar))

### Test significance of covars (and predictor)

For linear models the `drop1`/`anova` functions can be used to test
significance of the `predictor` and `covars` variables:

    ### Apply drop1 for each feature and output the adjusted p-values:
    # Works on "zpo", "znb", "qpo", "neb", "poi". Non-paired "lrm", "llm", "llm2"
    results <- DA.lrm(data, predictor, allResults = TRUE)
    res.drop1 <- DA.drop1(results)

    ### Apply anova for each feature and output the adjusted p-values:
    # Works on "lrm", "llm", "llm2". Non-paired "neb"
    results <- DA.lrm(data, predictor, allResults = TRUE)
    res.anova <- DA.anova(results)

### Adding user-defined methods

"zzz" (`DA.zzz`) is a placeholder for user-defined methods. You have to
supply it with a function whose input is: A `count_table` (data.frame,
samples are columns, rownames indicate features), a `predictor`
(vector), a `paired` variable (factor), and a `covars` argument (named
list with vectors). It is OK if your function doesn't use
`paired`/`covars`, but they have to be there in the arguments. The
output from the user-defined function should be a data.frame that at
least includes: The names of the features ("Feature"), p-values
("pval"), and name of method ("Method").

See example below on how to include a simple t-test on relative
abundances:

    # Define our function
    myfun <- function(count_table, predictor, paired, covars){ # These fours arguments should not be altered
      
      # Relative abundance
      rel <- apply(count_table, 2, function(x) x/sum(x))
      
      # t-test function
      ## Wrapping this function in tryCatch(..., error = function(e){NA}) 
      ## ensures that our main function won't fail if t.test fails on some features
      tfun <- function(x){
        tryCatch(t.test(x ~ predictor)$p.value, error = function(e){NA}) 
      }
      
      # P-values for each feature
      pvals <- apply(rel, 1, tfun)
      
      # Adjust p-values
      pvals.adj <- p.adjust(pvals, method = "fdr")
      
      # Collect and return data
      df <- data.frame(Feature = rownames(count_table),
                       pval = pvals,
                       pval.adj = pvals.adj)
      df$Method <- "My own t-test"
      return(df)
      
    }

    # Test that it works on real data
    res <- DA.zzz(data, predictor, FUN = myfun)

    # Use it in the testDA function
    mytest <- testDA(data, predictor, tests = c("zzz","ttt","wil"), args = list(zzz = list(FUN = myfun)))

    # Several user-defined methods can be included by simply putting numbers after "zzz" in both the "tests" and "args" arguments:
    mytest <- testDA(data, predictor, tests = c("zzz","zzz2","ttt","wil"), args = list(zzz = list(FUN = myfun),
                                                                                       zzz2 = list(FUN = myfun2)))

**Caution:** If "zzz" is in the `tests` argument, there will be no
checks of whether any of the supplied methods are suitable for the data.
If e.g. your `predictor` is quantitative and "ttt" is in the `tests`
argument, it will try to run a t-test and fail miserably.

### Passing arguments to the different tests

Additional arguments can be passed to the internal functions with the
`args` argument. It should be structured as a list with elements named
by the tests:

E.g. passing to the DA.per function that it should only run 1000
iterations:

    mytest <- testDA(...,args = list(per=list(noOfIterations=1000)))

Include that the log t.test should use a pseudocount of 0.1:

    mytest <- testDA(...,args = list(per=list(noOfIterations=1000), ltt=list(delta=0.1)))

Additional arguments are simply seperated by commas.

Below is an overview of which functions get the arguments that are
passed to a specific test:

-   per - Passed to `DA.per`
-   bay - Passed to `getPriors`, `getLikelihoods` and `DA.bay`
-   adx - Passed to `aldex` and `DA.adx`
-   wil - Passed to `wilcox.test` and `DA.wil`
-   ttt - Passed to `t.test` and `DA.ttt`
-   ltt - Passed to `t.test` and `DA.ltt`
-   ltt2 - Passed to `t.test` and `DA.ltt2`
-   neb - Passed to `glm.nb`, `glmer.nb` and `DA.neb`
-   erq - Passed to `calcNormFactors`, `estimateDisp`, `glmQLFit`,
    `glmQLFTest` and `DA.erq`
-   ere - Passed to `calcNormFactors`, `estimateCommonDisp`,
    `estimateTagwiseDisp`, `exactTest` and `DA.ere`
-   msf - Passed to `fitFeatureModel` and `DA.msf`
-   zig - Passed to `fitZig` and `DA.zig`
-   ds2 - Passed to `DESeq` and `DA.ds2`
-   ds2x - Passed to `DESeq` and `DA.ds2x`
-   lim - Passed to `eBayes`, `lmFit` and `DA.lim`
-   lli - Passed to `eBayes`, `lmFit` and `DA.lli`
-   lli2 - Passed to `eBayes`, `lmFit` and `DA.lli2`
-   kru - Passed to `kruskal.test` and `DA.kru`
-   aov - Passed to `aov` and `DA.aov`
-   lao - Passed to `aov` and `DA.lao`
-   lao2 - Passed to `aov` and `DA.lao2`
-   lrm - Passed to `lm`, `lme` and `DA.lrm`
-   llm - Passed to `lm`, `lme` and `DA.llm`
-   llm2 - Passed to `lm`, `lme` and `DA.llm2`
-   rai - Passed to `raida` and `DA.rai`
-   spe - Passed to `cor.test` and `DA.spe`
-   pea - Passed to `cor.test` and `DA.pea`
-   poi - Passed to `glm`, `glmer` and `DA.poi`
-   qpo - Passed to `glm` and `DA.qpo`
-   vli - Passed to `voom`, `eBayes`, `lmFit` and `DA.vli`
-   zpo - Passed to `zeroinfl` and `DA.zpo`
-   znb - Passed to `zeroinfl` and `DA.znb`
-   fri - Passed to `friedman.test` and `DA.fri`
-   qua - Passed to `quade.test` and `DA.qua`
-   anc - Passed to `ANCOM` and `DA.anc`
-   sam - Passed to `SAMseq` and `DA.sam`
