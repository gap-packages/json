#
# json: Reading and Writing JSON
#
# Reading the declaration part of the package.
#

# The kernel extension is optional: without it we fall back to the pure GAP
# implementation. Probe with IsKernelExtensionAvailable first, as
# LoadKernelExtension raises an error (rather than returning false) when a
# stale .so from an older GAP is present.
BindGlobal( "JSON_KERNEL_AVAILABLE",
    IsKernelExtensionAvailable("json", "json") and
    LoadKernelExtension("json", "json") );

if not JSON_KERNEL_AVAILABLE then
    LogPackageLoadingMessage( PACKAGE_INFO,
        [ "kernel extension not available, using the pure GAP implementation" ] );
fi;

ReadPackage( "json", "gap/json.gd");
