#
# The runtime switch between the kernel and the pure GAP implementation.
#
gap> START_TEST("json package: test_impl.tst");
gap> LoadPackage("json", false);;

#
gap> saved := JsonImplementation();;
gap> saved in JsonAvailableImplementations();
true
gap> "gap" in JsonAvailableImplementations();
true
gap> JsonAvailableImplementations() = [ "kernel", "gap" ] or
>    JsonAvailableImplementations() = [ "gap" ];
true

# the kernel implementation is preferred whenever it was built
gap> JsonAvailableImplementations()[1] = "kernel" or not JSON_KERNEL_AVAILABLE;
true

#
gap> SetJsonImplementation("gap");;
gap> JsonImplementation();
"gap"
gap> JsonStringToGap(GapToJsonString(rec(a := [1, "b", 2.5, fail])));
rec( a := [ 1, "b", 2.5, fail ] )

#
gap> SetJsonImplementation("nosuchthing");
Error, <name> must be one of JsonAvailableImplementations()

# the pure GAP parser rejects pathologically nested input rather than
# overflowing the C stack the way the kernel one does
gap> deep := n -> Concatenation(ListWithIdenticalEntries(n, '['), "1",
>                               ListWithIdenticalEntries(n, ']'));;
gap> JsonStringToGap(deep(_JSON_MAX_DEPTH));;
gap> JsonStringToGap(deep(_JSON_MAX_DEPTH + 1));
Error, JSON input nested more than _JSON_MAX_DEPTH (1024) levels deep

# switching returns the previously selected implementation
gap> SetJsonImplementation(saved) = "gap";
true
gap> JsonImplementation() = saved;
true

#
gap> STOP_TEST("json package: test_impl.tst");
