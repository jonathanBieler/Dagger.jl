# Distributed Arrays

The `DArray`, or "distributed array", is an abstraction layer on top of Dagger
that allows loading array-like structures into a distributed environment. The
`DArray` partitions a larger array into smaller "blocks" or "chunks", and those
blocks may be located on any worker in the cluster. The `DArray` uses a
Parallel Global Address Space (aka "PGAS") model for storing partitions, which
means that a `DArray` instance contains a reference to every partition in the
greater array; this provides great flexibility in allowing Dagger to choose the
most efficient way to distribute the array's blocks and operate on them in a
heterogeneous manner.

Aside: an alternative model, here termed the "MPI" model, is not yet supported,
but would allow storing only a single partition of the array on each MPI rank
in an MPI cluster. `DArray` support for this model is planned in the near
future.

This should not be confused with the [DistributedArrays.jl](https://github.com/JuliaParallel/DistributedArrays.jl) package.

## Creating `DArrays`

A `DArray` can be created in two ways: through an API similar to the usual
`rand`, `ones`, etc. calls, or by distributing an existing array with
`DArray`, `DVector`, `DMatrix`, or `distribute`.

### Allocating new arrays

As an example, one can allocate a random `DArray` by calling `rand` with a
`Blocks` object as the first argument - `Blocks` specifies the size of
partitions to be constructed, and must be the same number of dimensions as the
array being allocated.

```julia
# Add some Julia workers
julia> using Distributed; addprocs(6)
6-element Vector{Int64}:
 2
 3
 4
 5
 6
 7

julia> @everywhere using Dagger

julia> DX = rand(Blocks(50, 50), 100, 100)
DMatrix{Float64}(100, 100) with 2x2 partitions of size 50x50:
 0.610404   0.0475367  0.809016   0.311305   0.0306211   0.689645   …  0.220267   0.678548   0.892062    0.0559988
 0.680815   0.788349   0.758755   0.0594709  0.640167    0.652266      0.331429   0.798848   0.732432    0.579534
 0.306898   0.0805607  0.498372   0.887971   0.244104    0.148825      0.340429   0.029274   0.140624    0.292354
 0.0537622  0.844509   0.509145   0.561629   0.566584    0.498554      0.427503   0.835242   0.699405    0.0705192
 0.587364   0.59933    0.0624318  0.3795     0.430398    0.0853735     0.379947   0.677105   0.0305861   0.748001
 0.14129    0.635562   0.218739   0.0629501  0.373841    0.439933   …  0.308294   0.0966736  0.783333    0.00763648
 0.14539    0.331767   0.912498   0.0649541  0.527064    0.249595      0.826705   0.826868   0.41398     0.80321
 0.13926    0.353158   0.330615   0.438247   0.284794    0.238837      0.791249   0.415801   0.729545    0.88308
 0.769242   0.136001   0.950214   0.171962   0.183646    0.78294       0.570442   0.321894   0.293101    0.911913
 0.786168   0.513057   0.781712   0.0191752  0.512821    0.621239      0.50503    0.0472064  0.0368674   0.75981
 0.493378   0.129937   0.758052   0.169508   0.0564534   0.846092   …  0.873186   0.396222   0.284       0.0242124
 0.12689    0.194842   0.263186   0.213071   0.535613    0.246888      0.579931   0.699231   0.441449    0.882772
 0.916144   0.21305    0.629293   0.329303   0.299889    0.127453      0.644012   0.311241   0.713782    0.0554386
 ⋮                                                       ⋮          ⋱
 0.430369   0.597251   0.552528   0.795223   0.46431     0.777119      0.189266   0.499178   0.715808    0.797629
 0.235668   0.902973   0.786537   0.951402   0.768312    0.633666      0.724196   0.866373   0.0679498   0.255039
 0.605097   0.301349   0.758283   0.681568   0.677913    0.51507    …  0.654614   0.37841    0.86399     0.583924
 0.824216   0.62188    0.369671   0.725758   0.735141    0.183666      0.0401394  0.522191   0.849429    0.839651
 0.578047   0.775035   0.704695   0.203515   0.00267523  0.869083      0.0975535  0.824887   0.00787017  0.920944
 0.805897   0.0275489  0.175715   0.135956   0.389958    0.856349      0.974141   0.586308   0.59695     0.906727
 0.212875   0.509612   0.85531    0.266659   0.0695836   0.0551129     0.788085   0.401581   0.948216    0.00242077
 0.512997   0.134833   0.895968   0.996953   0.422192    0.991526   …  0.838781   0.141053   0.747722    0.84489
 0.283221   0.995152   0.61636    0.75955    0.072718    0.691665      0.151339   0.295759   0.795476    0.203072
 0.0946639  0.496832   0.551496   0.848571   0.151074    0.625696      0.673817   0.273958   0.177998    0.563221
 0.0900806  0.127274   0.394169   0.140403   0.232985    0.460306      0.536441   0.200297   0.970311    0.0292218
 0.0698985  0.463532   0.934776   0.448393   0.606287    0.552196      0.883694   0.212222   0.888415    0.941097
```

The `rand(Blocks(50, 50), 100, 100)` call specifies that a `DMatrix` (a `DArray` matrix)
should be allocated which is in total 100 x 100, split into 4 blocks of size 50
x 50, and initialized with random `Float64`s. Many other functions, like
`randn`, `sprand`, `ones`, and `zeros` can be called in this same way.

Alternatively, instead of manually specifying the block size, one can call
`rand` with an `AutoBlocks` object to have Dagger automatically choose a block
size:

```julia
julia> DX = rand(AutoBlocks(), 100, 100)
DMatrix{Float64}(100, 100) with 1x7 partitions of size 100x15:
 0.610404   0.0475367  0.809016   0.311305   0.0306211   0.689645   …  0.220267   0.678548   0.892062    0.0559988
 0.680815   0.788349   0.758755   0.0594709  0.640167    0.652266      0.331429   0.798848   0.732432    0.579534
 0.306898   0.0805607  0.498372   0.887971   0.244104    0.148825      0.340429   0.029274   0.140624    0.292354
 0.0537622  0.844509   0.509145   0.561629   0.566584    0.498554      0.427503   0.835242   0.699405    0.0705192
 0.587364   0.59933    0.0624318  0.3795     0.430398    0.0853735     0.379947   0.677105   0.0305861   0.748001
 0.14129    0.635562   0.218739   0.0629501  0.373841    0.439933   …  0.308294   0.0966736  0.783333    0.00763648
 0.14539    0.331767   0.912498   0.0649541  0.527064    0.249595      0.826705   0.826868   0.41398     0.80321
 0.13926    0.353158   0.330615   0.438247   0.284794    0.238837      0.791249   0.415801   0.729545    0.88308
 0.769242   0.136001   0.950214   0.171962   0.183646    0.78294       0.570442   0.321894   0.293101    0.911913
 0.786168   0.513057   0.781712   0.0191752  0.512821    0.621239      0.50503    0.0472064  0.0368674   0.75981
 0.493378   0.129937   0.758052   0.169508   0.0564534   0.846092   …  0.873186   0.396222   0.284       0.0242124
 0.12689    0.194842   0.263186   0.213071   0.535613    0.246888      0.579931   0.699231   0.441449    0.882772
 0.916144   0.21305    0.629293   0.329303   0.299889    0.127453      0.644012   0.311241   0.713782    0.0554386
 ⋮                                                       ⋮          ⋱
 0.430369   0.597251   0.552528   0.795223   0.46431     0.777119      0.189266   0.499178   0.715808    0.797629
 0.235668   0.902973   0.786537   0.951402   0.768312    0.633666      0.724196   0.866373   0.0679498   0.255039
 0.605097   0.301349   0.758283   0.681568   0.677913    0.51507    …  0.654614   0.37841    0.86399     0.583924
 0.824216   0.62188    0.369671   0.725758   0.735141    0.183666      0.0401394  0.522191   0.849429    0.839651
 0.578047   0.775035   0.704695   0.203515   0.00267523  0.869083      0.0975535  0.824887   0.00787017  0.920944
 0.805897   0.0275489  0.175715   0.135956   0.389958    0.856349      0.974141   0.586308   0.59695     0.906727
 0.212875   0.509612   0.85531    0.266659   0.0695836   0.0551129     0.788085   0.401581   0.948216    0.00242077
 0.512997   0.134833   0.895968   0.996953   0.422192    0.991526   …  0.838781   0.141053   0.747722    0.84489
 0.283221   0.995152   0.61636    0.75955    0.072718    0.691665      0.151339   0.295759   0.795476    0.203072
 0.0946639  0.496832   0.551496   0.848571   0.151074    0.625696      0.673817   0.273958   0.177998    0.563221
 0.0900806  0.127274   0.394169   0.140403   0.232985    0.460306      0.536441   0.200297   0.970311    0.0292218
 0.0698985  0.463532   0.934776   0.448393   0.606287    0.552196      0.883694   0.212222   0.888415    0.941097
```

We can see above that the `DMatrix` was partitioned into 7 partitions, each of
a maximum size of 100 x 15. Dagger will automatically partition `DArray`
objects into as many partitions as there are Dagger processors, to optimize for
parallelism.

Note that the `DArray` is an asynchronous object (i.e. operations on it may
execute in the background), so to force it to be materialized, `fetch` may need
to be called:

```julia
julia> fetch(DX)
DMatrix{Float64}(100, 100) with 1x7 partitions of size 100x15:
 0.610404   0.0475367  0.809016   0.311305   0.0306211   0.689645   …  0.220267   0.678548   0.892062    0.0559988
 0.680815   0.788349   0.758755   0.0594709  0.640167    0.652266      0.331429   0.798848   0.732432    0.579534
 0.306898   0.0805607  0.498372   0.887971   0.244104    0.148825      0.340429   0.029274   0.140624    0.292354
 0.0537622  0.844509   0.509145   0.561629   0.566584    0.498554      0.427503   0.835242   0.699405    0.0705192
 0.587364   0.59933    0.0624318  0.3795     0.430398    0.0853735     0.379947   0.677105   0.0305861   0.748001
 0.14129    0.635562   0.218739   0.0629501  0.373841    0.439933   …  0.308294   0.0966736  0.783333    0.00763648
 0.14539    0.331767   0.912498   0.0649541  0.527064    0.249595      0.826705   0.826868   0.41398     0.80321
 0.13926    0.353158   0.330615   0.438247   0.284794    0.238837      0.791249   0.415801   0.729545    0.88308
 0.769242   0.136001   0.950214   0.171962   0.183646    0.78294       0.570442   0.321894   0.293101    0.911913
 0.786168   0.513057   0.781712   0.0191752  0.512821    0.621239      0.50503    0.0472064  0.0368674   0.75981
 0.493378   0.129937   0.758052   0.169508   0.0564534   0.846092   …  0.873186   0.396222   0.284       0.0242124
 0.12689    0.194842   0.263186   0.213071   0.535613    0.246888      0.579931   0.699231   0.441449    0.882772
 0.916144   0.21305    0.629293   0.329303   0.299889    0.127453      0.644012   0.311241   0.713782    0.0554386
 ⋮                                                       ⋮          ⋱
 0.430369   0.597251   0.552528   0.795223   0.46431     0.777119      0.189266   0.499178   0.715808    0.797629
 0.235668   0.902973   0.786537   0.951402   0.768312    0.633666      0.724196   0.866373   0.0679498   0.255039
 0.605097   0.301349   0.758283   0.681568   0.677913    0.51507    …  0.654614   0.37841    0.86399     0.583924
 0.824216   0.62188    0.369671   0.725758   0.735141    0.183666      0.0401394  0.522191   0.849429    0.839651
 0.578047   0.775035   0.704695   0.203515   0.00267523  0.869083      0.0975535  0.824887   0.00787017  0.920944
 0.805897   0.0275489  0.175715   0.135956   0.389958    0.856349      0.974141   0.586308   0.59695     0.906727
 0.212875   0.509612   0.85531    0.266659   0.0695836   0.0551129     0.788085   0.401581   0.948216    0.00242077
 0.512997   0.134833   0.895968   0.996953   0.422192    0.991526   …  0.838781   0.141053   0.747722    0.84489
 0.283221   0.995152   0.61636    0.75955    0.072718    0.691665      0.151339   0.295759   0.795476    0.203072
 0.0946639  0.496832   0.551496   0.848571   0.151074    0.625696      0.673817   0.273958   0.177998    0.563221
 0.0900806  0.127274   0.394169   0.140403   0.232985    0.460306      0.536441   0.200297   0.970311    0.0292218
 0.0698985  0.463532   0.934776   0.448393   0.606287    0.552196      0.883694   0.212222   0.888415    0.941097
```

This doesn't change the type or values of the `DArray`, but it does make sure
that any pending operations have completed. When shown in the REPL, Dagger will
show all of the values of the `DArray` that have finished being computed, and
otherwise shows a `...` for values which are still be computed.

To convert a `DArray` back into an `Array`, `collect` can be used to gather the
data from all the Julia workers that they're on and combine them into a single
`Array` on the worker calling `collect`:

```julia
julia> collect(DX)
100×100 Matrix{Float64}:
 0.610404   0.0475367  0.809016   0.311305   0.0306211   0.689645   …  0.220267   0.678548   0.892062    0.0559988
 0.680815   0.788349   0.758755   0.0594709  0.640167    0.652266      0.331429   0.798848   0.732432    0.579534
 0.306898   0.0805607  0.498372   0.887971   0.244104    0.148825      0.340429   0.029274   0.140624    0.292354
 0.0537622  0.844509   0.509145   0.561629   0.566584    0.498554      0.427503   0.835242   0.699405    0.0705192
 0.587364   0.59933    0.0624318  0.3795     0.430398    0.0853735     0.379947   0.677105   0.0305861   0.748001
 0.14129    0.635562   0.218739   0.0629501  0.373841    0.439933   …  0.308294   0.0966736  0.783333    0.00763648
 0.14539    0.331767   0.912498   0.0649541  0.527064    0.249595      0.826705   0.826868   0.41398     0.80321
 0.13926    0.353158   0.330615   0.438247   0.284794    0.238837      0.791249   0.415801   0.729545    0.88308
 0.769242   0.136001   0.950214   0.171962   0.183646    0.78294       0.570442   0.321894   0.293101    0.911913
 0.786168   0.513057   0.781712   0.0191752  0.512821    0.621239      0.50503    0.0472064  0.0368674   0.75981
 0.493378   0.129937   0.758052   0.169508   0.0564534   0.846092   …  0.873186   0.396222   0.284       0.0242124
 0.12689    0.194842   0.263186   0.213071   0.535613    0.246888      0.579931   0.699231   0.441449    0.882772
 0.916144   0.21305    0.629293   0.329303   0.299889    0.127453      0.644012   0.311241   0.713782    0.0554386
 ⋮                                                       ⋮          ⋱
 0.430369   0.597251   0.552528   0.795223   0.46431     0.777119      0.189266   0.499178   0.715808    0.797629
 0.235668   0.902973   0.786537   0.951402   0.768312    0.633666      0.724196   0.866373   0.0679498   0.255039
 0.605097   0.301349   0.758283   0.681568   0.677913    0.51507    …  0.654614   0.37841    0.86399     0.583924
 0.824216   0.62188    0.369671   0.725758   0.735141    0.183666      0.0401394  0.522191   0.849429    0.839651
 0.578047   0.775035   0.704695   0.203515   0.00267523  0.869083      0.0975535  0.824887   0.00787017  0.920944
 0.805897   0.0275489  0.175715   0.135956   0.389958    0.856349      0.974141   0.586308   0.59695     0.906727
 0.212875   0.509612   0.85531    0.266659   0.0695836   0.0551129     0.788085   0.401581   0.948216    0.00242077
 0.512997   0.134833   0.895968   0.996953   0.422192    0.991526   …  0.838781   0.141053   0.747722    0.84489
 0.283221   0.995152   0.61636    0.75955    0.072718    0.691665      0.151339   0.295759   0.795476    0.203072
 0.0946639  0.496832   0.551496   0.848571   0.151074    0.625696      0.673817   0.273958   0.177998    0.563221
 0.0900806  0.127274   0.394169   0.140403   0.232985    0.460306      0.536441   0.200297   0.970311    0.0292218
 0.0698985  0.463532   0.934776   0.448393   0.606287    0.552196      0.883694   0.212222   0.888415    0.941097
```

### Distributing existing arrays

Now let's look at constructing a `DArray` from an existing array object; we can
do this by calling the `DArray` constructor or `distribute`:

```julia
julia> Z = zeros(100, 500);

julia> Dzeros = DArray(Z, Blocks(10, 50))
DMatrix{Float64}(100, 500) with 10x10 partitions of size 10x50:
...
```

This will distribute the array partitions (in chunks of 10 x 50 matrices)
across the workers in the Julia cluster in a relatively even distribution;
future operations on a `DArray` may produce a different distribution from the
one chosen by previous calls.

### Explicit Processor Mapping of DArray Blocks

This feature allows you to control how `DArray` blocks (chunks) are assigned to specific processors within the cluster. Controlling data locality is crucial for optimizing the performance of distributed algorithms.

You can specify the mapping using the optional `assignment` argument in the `DArray` constructor functions (`DArray`, `DVector`, and `DMatrix`), the `distribute` function, and also directly within constructor-like functions such as `rand`, `randn`, `sprand`, `ones`, and `zeros` using the `assignment` optional keyword argument.

The `assignment` argument accepts the following values:

* `:arbitrary` **(Default)**:

    * If `assignment` is not provided or is set to symbol `:arbitrary`, Dagger's scheduler assigns blocks to processors automatically. This is the default behavior.

* `:blockrow`:

    * Divides the matrix blocks row-wise (vertically in the terminal). Each processor gets a contiguous chunk of row blocks.

* `:blockcol`:

    * Divides the matrix blocks column-wise (horizontally in the terminal). Each processor gets a contiguous chunk of column blocks.

* `:cyclicrow`:

  * Assigns row-blocks to processors in a round-robin fashion. Blocks are distributed one row-block at a time. Useful for parallel row-wise tasks.

* `:cycliccol`:

  * Assigns column-blocks to processors in a round-robin fashion. Blocks are distributed one column-block at a time. Useful for parallel column-wise tasks.

* Any other symbol used for `assignment` results in an error.

* `AbstractArray{<:Int, N}`:

    * Provide an integer **N**-dimensional array of worker IDs. The dimension **N** must match the number of dimensions of the `DArray`.
    * Dagger maps blocks to worker IDs in a block-cyclic manner according to this processor-array. The block at index `(i,j,...)` is assigned to the first CPU thread of the worker with ID `assignment[mod1(i, size(assignment,1)), mod1(j, size(assignment,2)), ...]`. This pattern repeats block-cyclically across all dimensions.

* `AbstractArray{<:Processor, N}`:

    * Provide an **N**-dimensional array of `Processor` objects. The dimension **N** must match the number of dimensions of the `DArray` blocks.
    * Blocks are mapped in a block-cyclic manner according to the `Processor` objects in the assignment array. The block at index `(i,j,...)` is assigned to the processor at `assignment[mod1(i, size(assignment,1)), mod1(j, size(assignment,2)), ...]`. This pattern repeats block-cyclically across all dimensions.

#### Examples and Usage

The `assignment` argument works similarly for `DArray`, `DVector`, and `DMatrix`, as well as the `distribute` function. The key difference lies in the dimensionality of the resulting distributed array. For functions like `rand`, `randn`, `sprand`, `ones`, and `zeros`, `assignment` is an keyword argument.

* `DArray`: For N-dimensional distributed arrays.

* `DVector`: Specifically for 1-dimensional distributed arrays.

* `DMatrix`: Specifically for 2-dimensional distributed arrays.

* `distribute`: General function to distribute arrays of any dimensionality.

* `rand`, `randn`, `sprand`, `ones`, `zeros`: Functions to create DArrays with initial values, also supporting `assignment`.

Here are some examples using a setup with one master process and three worker processes.

First, let's create some sample arrays for `distribute` (and constructor functions):

```julia
A = rand(7, 11)   # 2D array
v = ones(15)      # 1D array
M = zeros(5, 5, 5) # 3D array
```

1.  **Arbitrary Assignment:**

    ```julia
    Ad = distribute(A, Blocks(2, 2), :arbitrary)
    # DMatrix(A, Blocks(2, 2), :arbitrary)

    vd = distribute(v, Blocks(3), :arbitrary)
    # DVector(v, Blocks(3), :arbitrary)

    Md = distribute(M, Blocks(2, 2, 2), :arbitrary)
    # DArray(M, Blocks(2,2,2), :arbitrary)

    Rd = rand(Blocks(2, 2), 7, 11; assignment=:arbitrary)
    # distribute(rand(7, 11), Blocks(2, 2), :arbitrary)
    ```

   This creates distributed arrays with the specified block sizes, and assigns the blocks to processors arbitrarily. For example, the assignment for `Ad` might look like this:

    ```julia
    4×6 Matrix{Dagger.ThreadProc}:
    ThreadProc(4, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(2, 1) ThreadProc(4, 1)  ThreadProc(3, 1)
    ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)
    ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(4, 1)
    ThreadProc(2, 1)  ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(3, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)
    ```

2.  **Structured Assignments:**

  * **`:blockrow` Assignment:**

    ```julia
    Ad = distribute(A, Blocks(1, 2), :blockrow)
    # DMatrix(A, Blocks(1, 2), :blockrow)
    vd = distribute(v, Blocks(3), :blockrow)
    # DVector(v, Blocks(3), :blockrow)
    Md = distribute(M, Blocks(2, 2, 2), :blockrow)
    # DArray(M, Blocks(2,2,2), :blockrow)
    Od = ones(Blocks(1, 2), 7, 11; assignment=:blockrow)
    # distribute(ones(7, 11), Blocks(1, 2), :blockrow)
    ```

    This creates distributed arrays with the specified block sizes, and assigns contiguous row-blocks to processors evenly. For example, the assignment for `Ad` (and `Od`) will look like this:

    ```julia
    7×6 Matrix{Dagger.ThreadProc}:
    ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1) ThreadProc(1, 1)
    ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1) ThreadProc(1, 1)
    ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1) ThreadProc(2, 1)
    ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1) ThreadProc(2, 1)
    ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1) ThreadProc(3, 1)
    ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1) ThreadProc(3, 1)
    ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(4, 1) ThreadProc(4, 1)
    ```

  * **`:blockcol` Assignment:**

    ```julia
    Ad = distribute(A, Blocks(2, 2), :blockcol)
    # DMatrix(A, Blocks(2, 2), :blockcol)
    vd = distribute(v, Blocks(3), :blockcol)
    # DVector(v, Blocks(3), :blockcol)
    Md = distribute(M, Blocks(2, 2, 2), :blockcol)
    # DArray(M, Blocks(2,2,2), :blockcol)
    Rd = randn(Blocks(2, 2), 7, 11; assignment=:blockcol)
    # distribute(randn(7, 11), Blocks(2, 2), :blockcol)
    ```

    This creates distributed arrays with the specified block sizes, and assigns contiguous column-blocks to processors evenly. For example, the assignment for `Ad` (and `Rd`) will look like this:

    ```julia
    4×6 Matrix{Dagger.ThreadProc}:
    ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)
    ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)
    ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)
    ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)
    ```

* **`:cyclicrow` Assignment:**

    ```julia
    Ad = distribute(A, Blocks(1, 2), :cyclicrow)
    # DMatrix(A, Blocks(1, 2), :cyclicrow)
    vd = distribute(v, Blocks(3), :cyclicrow)
    # DVector(v, Blocks(3), :cyclicrow)
    Md = distribute(M, Blocks(2, 2, 2), :cyclicrow)
    # DArray(M, Blocks(2,2,2), :cyclicrow)
    Zd = zeros(Blocks(1, 2), 7, 11; assignment=:cyclicrow)
    # distribute(zeros(7, 11), Blocks(1, 2), :cyclicrow)
    ```

    This creates distributed arrays with the specified block sizes, and assigns row-blocks to processors in round-robin fashion. For example, the assignment for `Ad` (and `Zd`) will look like this:

    ```julia
    7×6 Matrix{Dagger.ThreadProc}:
    ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1) ThreadProc(1, 1)
    ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1) ThreadProc(2, 1)
    ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1) ThreadProc(3, 1)
    ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(4, 1)  ThreadProc(4, 1) ThreadProc(4, 1)
    ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1)  ThreadProc(1, 1) ThreadProc(1, 1)
    ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1)  ThreadProc(2, 1) ThreadProc(2, 1)
    ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1)  ThreadProc(3, 1) ThreadProc(3, 1)
    ```

* **`:cycliccol` Assignment:**

    ```julia
    Ad = distribute(A, Blocks(2, 2), :cycliccol)
    # DMatrix(A, Blocks(2, 2), :cycliccol)
    vd = distribute(v, Blocks(3), :cycliccol)
    # DVector(v, Blocks(3), :cycliccol)
    Md = distribute(M, Blocks(2, 2, 2), :cycliccol)
    # DArray(M, Blocks(2,2,2), :cycliccol)
    Od = ones(Blocks(2, 2), 7, 11; assignment=:cycliccol)
    # distribute(ones(7, 11), Blocks(2, 2), :cycliccol)
    ```

    This creates distributed arrays with the specified block sizes, and assigns column-blocks to processors in round-robin fashion. For example, the assignment for `Ad` (and `Od`) will look like this:

    ```julia
    4×6 Matrix{Dagger.ThreadProc}:
    ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)
    ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)
    ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)
    ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)
    ```

3.  **Block-Cyclic Assignment with Integer Array:**

    ```julia
    assignment_2d = [2 1; 4 3]
    Ad = distribute(A, Blocks(2, 2), assignment_2d)
    # DMatrix(A, Blocks(2, 2), [2 1; 4 3])

    assignment_1d = [2,3,1,4]
    vd = distribute(v, Blocks(3), assignment_1d)
    # DVector(v, Blocks(3), [2,3,1,4])

    assignment_3d = cat([1 2; 3 4], [4 3; 2 1], dims=3)
    Md = distribute(M, Blocks(2, 2, 2), assignment_3d) 
    # DArray(M, Blocks(2, 2, 2), cat([1 2; 3 4], [4 3; 2 1], dims=3))
    Rd = sprand(Blocks(2, 2), 7, 11, 0.2; assignment=assignment_2d)
    # distribute(sprand(7,11, 0.2), Blocks(2, 2), assignment_2d)
    ```

    The assignment is an integer matrix of worker IDs, the blocks are assigned in block-cyclic manner to the first CPU thread of each worker. The assignment for `Ad` (and `Rd`) would be:

    ```julia
    4×6 Matrix{Dagger.ThreadProc}:
      ThreadProc(2, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(1, 1)
      ThreadProc(4, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(3, 1)
      ThreadProc(2, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(1, 1)  ThreadProc(2, 1)  ThreadProc(1, 1)
      ThreadProc(4, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(3, 1)  ThreadProc(4, 1)  ThreadProc(3, 1)
    ```

4.  **Block-Cyclic Assignment with Processor Array:**

    ```julia
    assignment_2d = [Dagger.ThreadProc(3, 2) Dagger.ThreadProc(1, 1);
                     Dagger.ThreadProc(4, 3) Dagger.ThreadProc(2, 2)]
    Ad = distribute(A, Blocks(2, 2), assignment_2d)
    # DMatrix(A, Blocks(2, 2), assignment_2d)

    assignment_1d = [Dagger.ThreadProc(2,1), Dagger.ThreadProc(3,1), Dagger.ThreadProc(1,1), Dagger.ThreadProc(4,1)]
    vd = distribute(v, Blocks(3), assignment_1d)
    # DVector(v, Blocks(3), assignment_1d)

    assignment_3d = cat([Dagger.ThreadProc(1,1) Dagger.ThreadProc(2,1); Dagger.ThreadProc(3,1) Dagger.ThreadProc(4,1)],
                        [Dagger.ThreadProc(4,1) Dagger.ThreadProc(3,1); Dagger.ThreadProc(2,1) Dagger.ThreadProc(1,1)], dims=3)
    Md = distribute(M, Blocks(2, 2, 2), assignment_3d)
    # DArray(M, Blocks(2, 2, 2), assignment_3d)
    Rd = rand(Blocks(2, 2), 7, 11; assignment=assignment_2d))
    # distribute(rand(7,11), Blocks(2, 2), assignment_2d)
    ```

    The assignment is a matrix of `Processor` objects, the blocks are assigned in block-cyclic manner to each processor. The assignment for `Ad` (and `Rd`) would be:

    ```julia
    4×6 Matrix{Dagger.ThreadProc}:
      ThreadProc(3, 2)  ThreadProc(1, 1)  ThreadProc(3, 2)  ThreadProc(1, 1)  ThreadProc(3, 2)  ThreadProc(1, 1)
      ThreadProc(4, 3)  ThreadProc(2, 2)  ThreadProc(4, 3)  ThreadProc(2, 2)  ThreadProc(4, 3)  ThreadProc(2, 2)
      ThreadProc(3, 2)  ThreadProc(1, 1)  ThreadProc(3, 2)  ThreadProc(1, 1)  ThreadProc(3, 2)  ThreadProc(1, 1)
      ThreadProc(4, 3)  ThreadProc(2, 2)  ThreadProc(4, 3)  ThreadProc(2, 2)  ThreadProc(4, 3)  ThreadProc(2, 2)
    ```

## Broadcasting

As the `DArray` is a subtype of `AbstractArray` and generally satisfies Julia's
array interface, a variety of common operations (such as broadcast) work as
expected:

```julia
julia> DX = rand(Blocks(50,50), 100, 100)
DMatrix{Float64}(100, 100) with 2x2 partitions of size 50x50:
 0.498392   0.286688    0.526038   …  0.0679859  0.246031   0.662384   0.415873
 0.470772   0.118921    0.338746      0.368685   0.601165   0.43923    0.838116
 0.114096   0.214045    0.973305      0.739328   0.476762   0.880491   0.923226
 0.950628   0.937549    0.255425      0.800531   0.686832   0.554949   0.95652
 0.887815   0.149639    0.381778      0.511954   0.567506   0.599481   0.31642
 0.492811   0.517651    0.452395   …  0.048365   0.282697   0.117261   0.0695919
 0.96531    0.694923    0.319353      0.0269875  0.725317   0.38704    0.889079
 0.642189   0.139344    0.811443      0.713439   0.82764    0.0817175  0.649828
 0.470414   0.310536    0.614132      0.91453    0.38133    0.109497   0.678592
 0.681798   0.540348    0.898996      0.666149   0.818365   0.608407   0.959402
 0.192863   0.319655    0.340089   …  0.339894   0.879239   0.0198826  0.576009
 0.70397    0.789439    0.640622      0.863039   0.380762   0.830201   0.273082
 0.859905   0.660245    0.170967      0.827866   0.456064   0.158056   0.39331
 0.917375   0.564129    0.409167      0.0608749  0.967919   0.358908   0.313862
 0.37067    0.619176    0.913832      0.574299   0.366162   0.209266   0.755402
 0.272124   0.609023    0.367749   …  0.702147   0.393283   0.947087   0.642886
 0.731806   0.246858    0.952142      0.617165   0.667969   0.955148   0.0721093
 0.360135   0.776176    0.835084      0.183326   0.714036   0.370287   0.133747
 0.767541   0.663163    0.244765      0.825391   0.870428   0.710432   0.936085
 0.364802   0.161725    0.416545      0.685533   0.0313213  0.550103   0.622557
 ⋮                                 ⋱
 0.219181   0.305549    0.137981      0.133313   0.537143   0.613063   0.583891
 0.176936   0.930333    0.737141      0.288332   0.525941   0.33041    0.653449
 0.49888    0.644244    0.774862      0.757912   0.411029   0.0304365  0.569458
 0.462656   0.186863    0.946858      0.784609   0.269699   0.968227   0.409438
 0.969422   0.167368    0.205654   …  0.033398   0.759695   0.222605   0.159356
 0.0875248  0.498971    0.620837      0.112562   0.597004   0.208103   0.00320475
 0.908971   0.208706    0.676567      0.5081     0.118424   0.0320135  0.897443
 0.991279   0.835444    0.14738       0.365196   0.426543   0.987013   0.0339898
 0.331385   0.46114     0.718353      0.210474   0.21223    0.245349   0.211097
 0.88416    0.790778    0.352482   …  0.364377   0.0734304  0.610556   0.986503
 0.0325297  0.649128    0.996022      0.842136   0.26821    0.598355   0.923314
 0.793668   0.0111804   0.972974      0.401435   0.10282    0.176944   0.312946
 0.175388   0.414811    0.930609      0.0303789  0.794293   0.664361   0.509174
 0.056124   0.962519    0.51812       0.914509   0.972889   0.909924   0.831407
 0.186426   0.17904     0.712901   …  0.661726   0.937605   0.70563    0.434793
 0.182262   0.890191    0.123335      0.0570102  0.188695   0.534232   0.864526
 0.949261   0.520407    0.0579928     0.473342   0.90016    0.525208   0.224062
 0.817864   0.92868     0.513427      0.619016   0.0461629  0.844613   0.734735
 0.792413   0.00791863  0.76343       0.890141   0.183165   0.530084   0.521841

julia> DY = DX .+ DX
DMatrix{Float64}(100, 100) with 2x2 partitions of size 50x50:
 0.996784   0.573376   1.05208   1.52853    …  0.135972   0.492062   1.32477    0.831746
 0.941543   0.237841   0.677493  0.819019      0.737371   1.20233    0.878459   1.67623
 0.228193   0.428089   1.94661   1.97741       1.47866    0.953524   1.76098    1.84645
 1.90126    1.8751     0.51085   1.20145       1.60106    1.37366    1.1099     1.91304
 1.77563    0.299277   0.763556  0.800454      1.02391    1.13501    1.19896    0.63284
 0.985622   1.0353     0.904789  0.132049   …  0.09673    0.565395   0.234523   0.139184
 1.93062    1.38985    0.638706  0.677675      0.0539751  1.45063    0.774081   1.77816
 1.28438    0.278689   1.62289   1.39015       1.42688    1.65528    0.163435   1.29966
 0.940828   0.621072   1.22826   0.262374      1.82906    0.76266    0.218993   1.35718
 1.3636     1.0807     1.79799   1.30764       1.3323     1.63673    1.21681    1.9188
 0.385725   0.639309   0.680178  1.15371    …  0.679787   1.75848    0.0397651  1.15202
 1.40794    1.57888    1.28124   0.740523      1.72608    0.761524   1.6604     0.546163
 1.71981    1.32049    0.341934  0.0577456     1.65573    0.912128   0.316112   0.78662
 1.83475    1.12826    0.818334  1.13474       0.12175    1.93584    0.717816   0.627725
 0.741341   1.23835    1.82766   0.868958      1.1486     0.732324   0.418533   1.5108
 0.544247   1.21805    0.735498  1.03821    …  1.40429    0.786565   1.89417    1.28577
 1.46361    0.493715   1.90428   1.80758       1.23433    1.33594    1.9103     0.144219
 0.720269   1.55235    1.67017   1.25524       0.366652   1.42807    0.740574   0.267495
 1.53508    1.32633    0.48953   1.90929       1.65078    1.74086    1.42086    1.87217
 0.729603   0.32345    0.833089  1.88305       1.37107    0.0626427  1.10021    1.24511
 ⋮                                          ⋱
 0.438362   0.611098   0.275962  1.59538       0.266626   1.07429    1.22613    1.16778
 0.353873   1.86067    1.47428   1.59328       0.576663   1.05188    0.66082    1.3069
 0.997761   1.28849    1.54972   0.625172      1.51582    0.822057   0.060873   1.13892
 0.925313   0.373726   1.89372   1.97415       1.56922    0.539397   1.93645    0.818876
 1.93884    0.334736   0.411308  0.0129113  …  0.0667961  1.51939    0.44521    0.318712
 0.17505    0.997942   1.24167   0.190925      0.225124   1.19401    0.416207   0.00640949
 1.81794    0.417412   1.35313   1.16716       1.0162     0.236847   0.0640269  1.79489
 1.98256    1.67089    0.29476   1.68775       0.730392   0.853086   1.97403    0.0679796
 0.662771   0.922279   1.43671   1.56052       0.420949   0.424459   0.490698   0.422194
 1.76832    1.58156    0.704965  1.34981    …  0.728755   0.146861   1.22111    1.97301
 0.0650594  1.29826    1.99204   1.82428       1.68427    0.53642    1.19671    1.84663
 1.58734    0.0223607  1.94595   1.45301       0.80287    0.205641   0.353888   0.625892
 0.350777   0.829621   1.86122   1.52899       0.0607578  1.58859    1.32872    1.01835
 0.112248   1.92504    1.03624   1.45978       1.82902    1.94578    1.81985    1.66281
 0.372851   0.358081   1.4258    1.49133    …  1.32345    1.87521    1.41126    0.869586
 0.364524   1.78038    0.24667   0.072136      0.11402    0.37739    1.06846    1.72905
 1.89852    1.04081    0.115986  0.227947      0.946684   1.80032    1.05042    0.448124
 1.63573    1.85736    1.02685   1.80253       1.23803    0.0923258  1.68923    1.46947
 1.58483    0.0158373  1.52686   0.0511455     1.78028    0.36633    1.06017    1.04368

julia> DZ = DY .* 3
DMatrix{Float64}(100, 100) with 2x2 partitions of size 50x50:
 2.99035   1.72013    3.15623   4.58558    …  0.407915  1.47619   3.9743    2.49524
 2.82463   0.713524   2.03248   2.45706       2.21211   3.60699   2.63538   5.0287
 0.684579  1.28427    5.83983   5.93224       4.43597   2.86057   5.28295   5.53936
 5.70377   5.62529    1.53255   3.60434       4.80319   4.12099   3.32969   5.73912
 5.32689   0.897831   2.29067   2.40136       3.07172   3.40504   3.59689   1.89852
 2.95686   3.10591    2.71437   0.396147   …  0.29019   1.69618   0.703568  0.417551
 5.79186   4.16954    1.91612   2.03302       0.161925  4.3519    2.32224   5.33448
 3.85314   0.836066   4.86866   4.17046       4.28063   4.96584   0.490305  3.89897
 2.82249   1.86322    3.68479   0.787122      5.48718   2.28798   0.65698   4.07155
 4.09079   3.24209    5.39397   3.92293       3.99689   4.91019   3.65044   5.75641
 1.15718   1.91793    2.04053   3.46113    …  2.03936   5.27544   0.119295  3.45606
 4.22382   4.73663    3.84373   2.22157       5.17824   2.28457   4.98121   1.63849
 5.15943   3.96147    1.0258    0.173237      4.9672    2.73639   0.948335  2.35986
 5.50425   3.38477    2.455     3.40421       0.365249  5.80751   2.15345   1.88317
 2.22402   3.71505    5.48299   2.60687       3.44579   2.19697   1.2556    4.53241
 1.63274   3.65414    2.20649   3.11464    …  4.21288   2.3597    5.68252   3.85731
 4.39084   1.48115    5.71285   5.42273       3.70299   4.00781   5.73089   0.432656
 2.16081   4.65706    5.0105    3.76573       1.09996   4.28422   2.22172   0.802485
 4.60525   3.97898    1.46859   5.72788       4.95234   5.22257   4.26259   5.61651
 2.18881   0.970351   2.49927   5.64915       4.1132    0.187928  3.30062   3.73534
 ⋮                                         ⋱
 1.31509   1.83329    0.827885  4.78613       0.799879  3.22286   3.67838   3.50334
 1.06162   5.582      4.42284   4.77983       1.72999   3.15565   1.98246   3.92069
 2.99328   3.86546    4.64917   1.87552       4.54747   2.46617   0.182619  3.41675
 2.77594   1.12118    5.68115   5.92246       4.70765   1.61819   5.80936   2.45663
 5.81653   1.00421    1.23392   0.0387339  …  0.200388  4.55817   1.33563   0.956135
 0.525149  2.99383    3.72502   0.572775      0.675371  3.58202   1.24862   0.0192285
 5.45382   1.25224    4.0594    3.50149       3.0486    0.710542  0.192081  5.38466
 5.94767   5.01267    0.88428   5.06324       2.19118   2.55926   5.92208   0.203939
 1.98831   2.76684    4.31012   4.68156       1.26285   1.27338   1.47209   1.26658
 5.30496   4.74467    2.11489   4.04942    …  2.18626   0.440583  3.66334   5.91902
 0.195178  3.89477    5.97613   5.47285       5.05282   1.60926   3.59013   5.53988
 4.76201   0.0670822  5.83784   4.35903       2.40861   0.616922  1.06166   1.87768
 1.05233   2.48886    5.58365   4.58697       0.182273  4.76576   3.98617   3.05505
 0.336744  5.77511    3.10872   4.37935       5.48705   5.83733   5.45954   4.98844
 1.11855   1.07424    4.27741   4.47399    …  3.97035   5.62563   4.23378   2.60876
 1.09357   5.34114    0.74001   0.216408      0.342061  1.13217   3.20539   5.18716
 5.69556   3.12244    0.347957  0.683841      2.84005   5.40096   3.15125   1.34437
 4.90718   5.57208    3.08056   5.40758       3.71409   0.276977  5.06768   4.40841
 4.75448   0.0475118  4.58058   0.153437      5.34085   1.09899   3.18051   3.13105
```

Now, `DZ` will contain the result of computing `(DX .+ DX) .* 3`.

```
julia> Dagger.chunks(DZ)
2×2 Matrix{Any}:
 DTask (finished)  DTask (finished)
 DTask (finished)  DTask (finished)

julia> Dagger.chunks(fetch(DZ))
2×2 Matrix{Union{DTask, Dagger.Chunk}}:
 Chunk{Matrix{Float64}, DRef, ThreadProc, AnyScope}(Matrix{Float64}, ArrayDomain{2}((1:50, 1:50)), DRef(4, 8, 0x0000000000004e20), ThreadProc(4, 1), AnyScope(), true)  …  Chunk{Matrix{Float64}, DRef, ThreadProc, AnyScope}(Matrix{Float64}, ArrayDomain{2}((1:50, 1:50)), DRef(2, 5, 0x0000000000004e20), ThreadProc(2, 1), AnyScope(), true)
 Chunk{Matrix{Float64}, DRef, ThreadProc, AnyScope}(Matrix{Float64}, ArrayDomain{2}((1:50, 1:50)), DRef(5, 5, 0x0000000000004e20), ThreadProc(5, 1), AnyScope(), true)     Chunk{Matrix{Float64}, DRef, ThreadProc, AnyScope}(Matrix{Float64}, ArrayDomain{2}((1:50, 1:50)), DRef(3, 3, 0x0000000000004e20), ThreadProc(3, 1), AnyScope(), true)
```

Here we can see the `DArray`'s internal representation of the partitions, which
are stored as either `DTask` objects (representing an ongoing or completed
computation) or `Chunk` objects (which reference data which exist locally or on
other Julia workers). Of course, one doesn't typically need to worry about
these internal details unless implementing low-level operations on `DArray`s.

Finally, it's easy to see the results of this combination of broadcast
operations; just use `collect` to get an `Array`:

```
julia> collect(DZ)
100×100 Matrix{Float64}:
 2.99035   1.72013    3.15623   4.58558    …  0.407915  1.47619   3.9743    2.49524
 2.82463   0.713524   2.03248   2.45706       2.21211   3.60699   2.63538   5.0287
 0.684579  1.28427    5.83983   5.93224       4.43597   2.86057   5.28295   5.53936
 5.70377   5.62529    1.53255   3.60434       4.80319   4.12099   3.32969   5.73912
 5.32689   0.897831   2.29067   2.40136       3.07172   3.40504   3.59689   1.89852
 2.95686   3.10591    2.71437   0.396147   …  0.29019   1.69618   0.703568  0.417551
 5.79186   4.16954    1.91612   2.03302       0.161925  4.3519    2.32224   5.33448
 3.85314   0.836066   4.86866   4.17046       4.28063   4.96584   0.490305  3.89897
 2.82249   1.86322    3.68479   0.787122      5.48718   2.28798   0.65698   4.07155
 4.09079   3.24209    5.39397   3.92293       3.99689   4.91019   3.65044   5.75641
 1.15718   1.91793    2.04053   3.46113    …  2.03936   5.27544   0.119295  3.45606
 4.22382   4.73663    3.84373   2.22157       5.17824   2.28457   4.98121   1.63849
 5.15943   3.96147    1.0258    0.173237      4.9672    2.73639   0.948335  2.35986
 5.50425   3.38477    2.455     3.40421       0.365249  5.80751   2.15345   1.88317
 2.22402   3.71505    5.48299   2.60687       3.44579   2.19697   1.2556    4.53241
 1.63274   3.65414    2.20649   3.11464    …  4.21288   2.3597    5.68252   3.85731
 4.39084   1.48115    5.71285   5.42273       3.70299   4.00781   5.73089   0.432656
 2.16081   4.65706    5.0105    3.76573       1.09996   4.28422   2.22172   0.802485
 4.60525   3.97898    1.46859   5.72788       4.95234   5.22257   4.26259   5.61651
 2.18881   0.970351   2.49927   5.64915       4.1132    0.187928  3.30062   3.73534
 ⋮                                         ⋱
 1.31509   1.83329    0.827885  4.78613       0.799879  3.22286   3.67838   3.50334
 1.06162   5.582      4.42284   4.77983       1.72999   3.15565   1.98246   3.92069
 2.99328   3.86546    4.64917   1.87552       4.54747   2.46617   0.182619  3.41675
 2.77594   1.12118    5.68115   5.92246       4.70765   1.61819   5.80936   2.45663
 5.81653   1.00421    1.23392   0.0387339  …  0.200388  4.55817   1.33563   0.956135
 0.525149  2.99383    3.72502   0.572775      0.675371  3.58202   1.24862   0.0192285
 5.45382   1.25224    4.0594    3.50149       3.0486    0.710542  0.192081  5.38466
 5.94767   5.01267    0.88428   5.06324       2.19118   2.55926   5.92208   0.203939
 1.98831   2.76684    4.31012   4.68156       1.26285   1.27338   1.47209   1.26658
 5.30496   4.74467    2.11489   4.04942    …  2.18626   0.440583  3.66334   5.91902
 0.195178  3.89477    5.97613   5.47285       5.05282   1.60926   3.59013   5.53988
 4.76201   0.0670822  5.83784   4.35903       2.40861   0.616922  1.06166   1.87768
 1.05233   2.48886    5.58365   4.58697       0.182273  4.76576   3.98617   3.05505
 0.336744  5.77511    3.10872   4.37935       5.48705   5.83733   5.45954   4.98844
 1.11855   1.07424    4.27741   4.47399    …  3.97035   5.62563   4.23378   2.60876
 1.09357   5.34114    0.74001   0.216408      0.342061  1.13217   3.20539   5.18716
 5.69556   3.12244    0.347957  0.683841      2.84005   5.40096   3.15125   1.34437
 4.90718   5.57208    3.08056   5.40758       3.71409   0.276977  5.06768   4.40841
 4.75448   0.0475118  4.58058   0.153437      5.34085   1.09899   3.18051   3.13105
```

A variety of other operations exist on the `DArray`, and it should generally
behave otherwise similar to any other `AbstractArray` type. If you find that
it's missing an operation that you need, please file an issue!

### Known Supported Operations

This list is not exhaustive, but documents operations which are known to work well with the `DArray`:

From `Base`:
- `getindex`/`setindex!`
- Broadcasting
- `similar`/`copy`/`copyto!`
- `map`/`reduce`/`mapreduce`
- `sum`/`prod`
- `minimum`/`maximum`/`extrema`
- `map!`

From `Random`:
- `rand!`/`randn!`

From `Statistics`:
- `mean`
- `var`
- `std`

From `LinearAlgebra`:
- `transpose`/`adjoint` (Out-of-place transpose)
- `*` (Out-of-place Matrix-(Matrix/Vector) multiply)
- `mul!` (In-place Matrix-Matrix multiply)
- `cholesky`/`cholesky!` (In-place/Out-of-place Cholesky factorization)
- `lu`/`lu!` (In-place/Out-of-place LU factorization (`NoPivot` only))

From `AbstractFFTs`:
- `fft`/`fft!`
- `ifft`/`ifft!`